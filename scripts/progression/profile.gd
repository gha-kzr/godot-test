@tool
class_name Profile
extends RefCounted
## The player's lasting progress: every hero's record, which are unlocked, the party, and
## the shared rune stash. Plain data, independent from battles; the game root applies
## battle rewards to it and saves it.

class LevelUp:
	var hero_index: int
	var from_level: int
	var to_level: int

	func _init(hero: int, from: int, to: int) -> void:
		hero_index = hero
		from_level = from
		to_level = to


## Save format version; bump on incompatible changes (from_dict must read older ones).
## Version 5: the XP curve changed (milestone 6c); saves of older versions load, with levels recomputed
## from their XP.
const SAVE_VERSION := 5

var roster: Roster
var heroes: Array[HeroRecord] = []  ## One per roster hero, same order.
var unlocked: Array[int] = []  ## Hero indices.
var party: Array[int] = []  ## Hero indices, in spawn order.
var stash: Array[RuneData] = []
## The deepest tower floor cleared.
var best_depth := 0
## Ids of the unlocked achievements (Achievements, data/achievements).
var achievements: Array[String] = []
## The first victory's starter rune was handed out (ProgressionConfig.first_rune).
var starter_rune_given := false
var cleared_stages: Array[StageData] = []
## The run in progress, or null.
var run: RunState


## A fresh profile: every hero at level 1, the roster's starting unlocks and party.
static func create(from_roster: Roster) -> Profile:
	var profile := Profile.new()
	profile.roster = from_roster
	for hero in from_roster.heroes:
		profile.heroes.append(HeroRecord.new(hero))
	profile.unlocked = from_roster.starting_unlocked.duplicate()
	profile.party = from_roster.starting_party.duplicate()
	return profile


## A hero's XP towards its next level: Vector2i(gained this level, needed this level). A hero
## at the level cap reads (1, 1): a full bar.
func xp_progress(hero_index: int) -> Vector2i:
	var record := heroes[hero_index]
	var next := roster.config.xp_for_next(record.level)
	if next < 0:
		return Vector2i(1, 1)
	var from := roster.config.xp_for_level(record.level)
	return Vector2i(record.xp - from, maxi(1, next - from))


## "XP 30 / 50" (total XP over the next threshold), or "XP 540 (max level)".
func xp_text(hero_index: int) -> String:
	var record := heroes[hero_index]
	var next := roster.config.xp_for_next(record.level)
	return tr("XP %d / %d") % [record.xp, next] if next >= 0 else tr("XP %d (max level)") % record.xp


func party_records() -> Array[HeroRecord]:
	var records: Array[HeroRecord] = []
	for index in party:
		records.append(heroes[index])
	return records


func is_unlocked(hero_index: int) -> bool:
	return hero_index in unlocked


## The party as battle input: units in spawn order, with their permanent modifiers.
func battle_units() -> Array[UnitData]:
	var units: Array[UnitData] = []
	for record in party_records():
		units.append(record.battle_unit_data())
	return units


func battle_modifiers() -> Array:
	var modifiers: Array = []
	for record in party_records():
		modifiers.append(record.modifiers())
	return modifiers


## Moves a rune from the stash to a hero's slot (the first free one if `slot` is -1).
## Returns an error message, or "" on success.
func equip(hero_index: int, stash_index: int, slot := -1) -> String:
	if hero_index < 0 or hero_index >= heroes.size() or not is_unlocked(hero_index):
		return tr("That hero isn't available.")
	if stash_index < 0 or stash_index >= stash.size():
		return tr("No such rune in the stash.")
	var record := heroes[hero_index]
	var rune := stash[stash_index]
	if slot == -1:
		slot = record.free_slot()
		if slot == -1:
			return tr("%s has no free rune slot.") % tr(record.hero.display_name())
	elif slot < 0 or slot >= HeroRecord.RUNE_SLOTS or record.runes[slot] != null:
		return tr("That rune slot isn't free.")
	if rune.is_unique() and rune in record.runes:
		return tr("%s is %s: one per hero.") % [tr(rune.display_name), tr(rune.rarity_name()).to_lower()]
	record.runes[slot] = rune
	stash.remove_at(stash_index)
	return ""


## Puts a known spell in a hero's filled loadout slot (swapping with that spell's own slot,
## or replacing an inactive one: see HeroRecord.assign_spell). Returns an error, or "".
func assign_spell(hero_index: int, slot: int, spell: SpellData) -> String:
	if hero_index < 0 or hero_index >= heroes.size() or not is_unlocked(hero_index):
		return tr("That hero isn't available.")
	var error := heroes[hero_index].assign_spell(slot, spell)
	return tr("That spell can't go there.") if not error.is_empty() else ""


## Throws a rune of the stash away for good: no undo, no refund (there is no currency). Returns
## an error message, or "".
func drop_rune(stash_index: int) -> String:
	if stash_index < 0 or stash_index >= stash.size():
		return tr("No such rune in the stash.")
	stash.remove_at(stash_index)
	return ""


## Moves a hero's rune back to the stash. Returns an error message, or "".
func unequip(hero_index: int, slot: int) -> String:
	if hero_index < 0 or hero_index >= heroes.size():
		return tr("No such hero.")
	var record := heroes[hero_index]
	if slot < 0 or slot >= HeroRecord.RUNE_SLOTS or record.runes[slot] == null:
		return tr("That rune slot is empty.")
	stash.append(record.runes[slot])
	record.runes[slot] = null
	return ""


## A won battle's rewards: the full XP to every party hero (fallen ones too), levels
## gained up to the cap, runes into the stash. Returns the level-ups.
func apply_rewards(rewards: BattleRewards) -> Array[LevelUp]:
	var level_ups: Array[LevelUp] = []
	for index in party:
		var record := heroes[index]
		record.xp += rewards.xp
		var new_level := roster.config.level_for_xp(record.xp)
		if new_level > record.level:
			level_ups.append(LevelUp.new(index, record.level, new_level))
			record.level = new_level
			record.settle_loadout()  # A newly learned spell takes a free slot.
	stash.append_array(rewards.runes)
	return level_ups


## The tower's current cap: the initial one, raised by each cleared stage.
func tower_cap(config: TowerConfig) -> int:
	var cap := config.initial_cap
	for stage in cleared_stages:
		cap = maxi(cap, stage.unlocks_cap)
	return cap


## Floors a tower run may start from: 1, and each cleared stage's starting floor.
func start_floors(config: TowerConfig) -> Array[int]:
	var floors: Array[int] = [1]
	for stage in config.stages:
		if stage in cleared_stages and stage.unlocks_start_floor not in floors:
			floors.append(stage.unlocks_start_floor)
	floors.sort()
	return floors


## A stage can be played once the one before it (in the tower's list) is cleared.
func is_stage_available(config: TowerConfig, stage: StageData) -> bool:
	var index := config.stages.find(stage)
	return index == 0 or (index > 0 and config.stages[index - 1] in cleared_stages)


## Plain data for saving: resources (heroes, runes) are referenced as {"uid", "path"}, so
## renaming or moving a file (the UID follows it) or reordering the roster can't break a
## save; the path is the fallback when a UID is unknown.
func to_dict() -> Dictionary:
	var hero_entries: Array = []
	for record in heroes:
		var rune_refs: Array = []
		for rune in record.runes:
			rune_refs.append(_ref(rune) if rune != null else null)
		hero_entries.append({"hero": _ref(record.hero), "xp": record.xp, "runes": rune_refs,
				"loadout": record.spells().map(func(spell: SpellData) -> Dictionary: return _ref(spell))})
	var stash_refs: Array = []
	for rune in stash:
		stash_refs.append(_ref(rune))
	return {"version": SAVE_VERSION, "heroes": hero_entries, "unlocked": _hero_refs(unlocked),
			"party": _hero_refs(party), "stash": stash_refs, "best_depth": best_depth,
			"starter_rune_given": starter_rune_given, "achievements": achievements,
			"cleared_stages": cleared_stages.map(func(s: StageData) -> Dictionary: return _ref(s)),
			"run": run.to_dict() if run != null else null}


## Rebuilds a profile saved by to_dict(), on top of a fresh one from `from_roster`: heroes
## are matched by resource path, unknown heroes or runes and malformed fields are skipped
## (with a warning), levels are recomputed from XP, the roster's starting unlocks are kept,
## and an invalid party falls back to the roster's. Reads version 1 saves (party and
## unlocks as roster indices) and 2 (resources by path). Returns null for a save from a
## newer version of the game.
static func from_dict(data: Dictionary, from_roster: Roster) -> Profile:
	var version := int(data.get("version", 0)) if data.get("version") is int or data.get("version") is float else 0
	if version > SAVE_VERSION:
		push_warning("Profile: save version %s is newer than %d" % [data.get("version"), SAVE_VERSION])
		return null
	var profile := Profile.create(from_roster)
	for entry: Variant in _array(data, "heroes"):
		if entry is not Dictionary:
			continue
		var index := profile._hero_index(entry.get("hero"))
		if index == -1:
			push_warning("Profile: unknown hero %s skipped" % str(entry.get("hero")))
			continue
		var record := profile.heroes[index]
		var xp: Variant = entry.get("xp", 0)
		record.xp = maxi(0, int(xp)) if xp is int or xp is float else 0
		record.level = from_roster.config.level_for_xp(record.xp)
		var rune_paths := _array(entry, "runes")
		for slot in mini(rune_paths.size(), HeroRecord.RUNE_SLOTS):
			record.runes[slot] = _load_rune(rune_paths[slot])
		var spell_refs := _array(entry, "loadout")
		for slot in mini(spell_refs.size(), HeroRecord.LOADOUT_SLOTS):
			var path := _resolve_path(spell_refs[slot])
			record.loadout[slot] = load(path) as SpellData if not path.is_empty() and ResourceLoader.exists(path) else null
		record.settle_loadout()  # Spells it no longer knows are dropped, new ones fill in.
	for index in profile._saved_heroes(_array(data, "unlocked"), version):
		if index not in profile.unlocked:
			profile.unlocked.append(index)
	var saved_party := profile._saved_heroes(_array(data, "party"), version)
	# A saved run's HP is per party slot: it resumes only with the party exactly as saved.
	var party_as_saved := false
	if not saved_party.is_empty() and saved_party.all(func(i: int) -> bool: return profile.is_unlocked(i)):
		profile.party.assign(saved_party)
		party_as_saved = saved_party.size() == _array(data, "party").size()
		# Heroes the roster now starts with join older saves' parties (e.g. the Ranger).
		for index in from_roster.starting_party:
			if index not in profile.party and profile.is_unlocked(index):
				profile.party.append(index)
				party_as_saved = false
	for path: Variant in _array(data, "stash"):
		var rune := _load_rune(path)
		if rune != null:
			profile.stash.append(rune)
	var depth: Variant = data.get("best_depth", 0)
	profile.best_depth = maxi(0, int(depth)) if depth is int or depth is float else 0
	profile.starter_rune_given = data.get("starter_rune_given", false) == true
	for id: Variant in _array(data, "achievements"):
		if id is String and id not in profile.achievements:
			profile.achievements.append(id)
	for ref: Variant in _array(data, "cleared_stages"):
		var path := _resolve_path(ref)
		var stage := load(path) as StageData if not path.is_empty() and ResourceLoader.exists(path) else null
		if stage != null and stage not in profile.cleared_stages:
			profile.cleared_stages.append(stage)
	var saved_run: Variant = data.get("run")
	if saved_run is Dictionary:
		profile.run = RunState.from_dict(saved_run)
		if profile.run != null and (not party_as_saved or profile.run.hero_hp.size() != profile.party.size()):
			profile.run = null  # The party changed since: the run can't resume.
	return profile


func _hero_refs(indices: Array[int]) -> Array:
	return indices.map(func(i: int) -> Dictionary: return _ref(heroes[i].hero))


func _hero_index(ref: Variant) -> int:
	var path := _resolve_path(ref)
	if path.is_empty():
		return -1
	return heroes.find_custom(func(r: HeroRecord) -> bool: return r.hero.resource_path == path)


## A saved reference to a resource: its UID (if it has one) and its path.
static func _ref(resource: Resource) -> Dictionary:
	var id := ResourceLoader.get_resource_uid(resource.resource_path)
	return {"uid": ResourceUID.id_to_text(id) if id != ResourceUID.INVALID_ID else "", "path": resource.resource_path}


## The current path of a saved reference: from its UID when known (the file may have
## moved), else its path. Version 1 / 2 saves store plain path strings.
static func _resolve_path(ref: Variant) -> String:
	if ref is String:
		return ref
	if ref is not Dictionary:
		return ""
	var uid_text: Variant = ref.get("uid", "")
	if uid_text is String and not uid_text.is_empty():
		var id := ResourceUID.text_to_id(uid_text)
		if id != ResourceUID.INVALID_ID and ResourceUID.has_id(id):
			return ResourceUID.get_id_path(id)
	var path: Variant = ref.get("path", "")
	return path if path is String else ""


## Saved hero references (paths; roster indices in version 1) as roster indices, without
## unknown ones or duplicates.
func _saved_heroes(values: Array, version: int) -> Array[int]:
	var indices: Array[int] = []
	for value: Variant in values:
		var index := -1
		if version <= 1 and (value is int or value is float):
			index = int(value) if int(value) >= 0 and int(value) < heroes.size() else -1
		else:
			index = _hero_index(value)
		if index != -1 and index not in indices:
			indices.append(index)
	return indices


## `data[key]` if it's an array, else an empty one (a malformed save).
static func _array(data: Dictionary, key: String) -> Array:
	var value: Variant = data.get(key, [])
	return value if value is Array else []


static func _load_rune(ref: Variant) -> RuneData:
	var path := _resolve_path(ref)
	if path.is_empty():
		return null
	var rune := load(path) as RuneData if ResourceLoader.exists(path) else null
	if rune == null:
		push_warning("Profile: unknown rune %s skipped" % path)
	return rune
