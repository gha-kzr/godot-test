@tool
class_name QaTools
extends RefCounted
## The QA screen's rules, without nodes: quick teams, playground encounters, floor
## descriptions and the profile tools. QA battles built from these never touch the save.

## Rune rarity for a quick team: none.
const NO_RUNES := -1
## The playground's enemy presets, by index: normal, elite, boss.
const PRESETS := ["res://data/presets/normal.tres", "res://data/presets/elite.tres", "res://data/presets/boss.tres"]


## What a QA battle's heroes are: units, permanent modifiers, levels (one per hero).
class Team:
	var units: Array[UnitData] = []
	var modifiers: Array = []
	var levels: Array[int] = []


## The roster's heroes whose level is above 0 (`levels`, by roster index), each at its level
## with the default loadout and up to six distinct runes of `rarity` (NO_RUNES: none).
static func quick_team(roster: Roster, levels: Array[int], rarity: int) -> Team:
	var team := Team.new()
	var runes := runes_of(rarity)
	for index in mini(roster.heroes.size(), levels.size()):
		if levels[index] <= 0:
			continue
		var record := HeroRecord.new(roster.heroes[index])
		record.level = clampi(levels[index], 1, roster.config.level_cap)
		for slot in mini(HeroRecord.RUNE_SLOTS, runes.size()):
			record.runes[slot] = runes[slot]
		team.units.append(record.battle_unit_data())
		team.modifiers.append(record.modifiers())
		team.levels.append(record.level)
	return team


## Every rune of `rarity`, by file name (none for NO_RUNES).
static func runes_of(rarity: int) -> Array[RuneData]:
	var result: Array[RuneData] = []
	if rarity == NO_RUNES:
		return result
	var files := Array(ResourceLoader.list_directory("res://data/runes"))
	files.sort()
	for file: String in files:
		if file.ends_with(".tres"):
			var rune := load("res://data/runes/" + file) as RuneData
			if rune != null and rune.rarity == rarity:
				result.append(rune)
	return result


## A playground encounter: `enemies` (EnemyData, level, preset index) on a board for them.
## With no `typology` and no `size`, floor `seed`'s own map (its first enemy spawns; a floor with
## fewer spawns than enemies gets a map of the same shape, layout and size drawn for them);
## otherwise `typology` (null: the floor's) at `size` (0: the floor's), from `seed`.
static func playground(tower: TowerConfig, seed: int, typology: MapTypology, size: int, enemies: Array) -> Encounter:
	var encounter := Encounter.new()
	encounter.display_name = "Playground"
	encounter.ai_profile = tower.ai_profile
	for entry: Array in enemies:
		var spawn := EncounterSpawn.new()
		spawn.enemy = entry[0]
		spawn.level = entry[1]
		spawn.preset = load(PRESETS[clampi(entry[2], 0, PRESETS.size() - 1)])
		encounter.spawns.append(spawn)
	var enemy_count := maxi(1, enemies.size())
	var floor_encounter := FloorGenerator.encounter(tower, maxi(seed, 1))
	var floor_map := floor_encounter.map.parse()
	encounter.layout_name = floor_encounter.layout_name
	if typology == null and size <= 0 and floor_map.enemy_spawns.size() >= enemy_count:
		encounter.map = keep_enemy_spawns(floor_encounter.map, enemy_count)
		encounter.map_typology = floor_encounter.map_typology
		return encounter
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([tower.seed_salt, "playground", seed])
	var shape := typology if typology != null else floor_encounter.map_typology
	var sizes := Vector2i(size, size) if size > 0 else floor_map.grid.size
	var layout := MapGenerator.Layout.keys().find(floor_encounter.layout_name)
	encounter.map = MapGenerator.generate(rng, tower.map_settings, enemy_count, false, maxi(layout, 0) as MapGenerator.Layout, shape, sizes)
	encounter.map_typology = shape
	return encounter


## A copy of `map` with only its first `count` enemy spawns (in reading order).
static func keep_enemy_spawns(map: MapData, count: int) -> MapData:
	var kept := 0
	var lines: Array[String] = []
	for line in map.layout.split("\n"):
		var tokens: Array[String] = []
		for token in line.split(" ", false):
			if token.ends_with(MapData.ENEMY_SPAWN):
				kept += 1
				if kept > count:
					token = token.trim_suffix(MapData.ENEMY_SPAWN)
			tokens.append(token)
		lines.append(" ".join(tokens))
	var copy := MapData.new()
	copy.layout = "\n".join(lines)
	return copy


## A floor's encounter in a few lines: its shape, size, layout and team.
static func describe(encounter: Encounter) -> String:
	var parsed := encounter.map.parse()
	var lines: Array[String] = []
	var shape := kind_text(encounter.map_typology.kind if encounter.map_typology != null else MapTypology.Kind.OPEN_FIELD)
	lines.append(TranslationServer.translate("%s, %d × %d, %s") % [shape, parsed.grid.size.x, parsed.grid.size.y, layout_text(encounter.layout_name)])
	if encounter.composition != null:
		lines.append(TranslationServer.translate("Team: %s") % encounter.composition.label)
	for build in encounter.builds():
		lines.append("• %s (%s)" % [build.label, EnemyData.role_name(build.role)])
	return "\n".join(lines)


## A map typology's kind, translated (its `label` is for designers).
static func kind_text(kind: MapTypology.Kind) -> String:
	match kind:
		MapTypology.Kind.MOUNTAIN: return TranslationServer.translate("Mountain")
		MapTypology.Kind.CRATER: return TranslationServer.translate("Crater")
		MapTypology.Kind.ISLANDS: return TranslationServer.translate("Islands and bridges")
		MapTypology.Kind.CANYON: return TranslationServer.translate("Canyon")
		MapTypology.Kind.RUINS: return TranslationServer.translate("Ruins")
	return TranslationServer.translate("Open field")


## A layout's name for the QA screen ("" for none).
static func layout_text(layout_name: String) -> String:
	match layout_name:
		"EDGE": return TranslationServer.translate("facing edges")
		"CORNER": return TranslationServer.translate("opposite corners")
		"AMBUSH": return TranslationServer.translate("ambush in the middle")
	return TranslationServer.translate("edge layout")


# --- Profile tools (they change the save; the QA screen asks first) ---

static func set_levels(profile: Profile, level: int) -> void:
	var config := profile.roster.config
	for record in profile.heroes:
		record.level = clampi(level, 1, config.level_cap)
		record.xp = config.xp_for_level(record.level)
		record.settle_loadout()


## One of every rune, at `level` (1 to RuneData.MAX_LEVEL), in the stash.
static func give_every_rune(profile: Profile, level := 1) -> void:
	for rarity in RuneData.Rarity.values():
		for rune in runes_of(rarity):
			profile.stash.append(RuneData.leveled(rune, level))


static func give_essence(profile: Profile, amount: int) -> void:
	profile.essence += maxi(0, amount)


static func set_best_floor(profile: Profile, floor_number: int) -> void:
	profile.best_depth = maxi(0, floor_number)


static func clear_every_stage(profile: Profile, tower: TowerConfig) -> void:
	for stage in tower.stages:
		if stage not in profile.cleared_stages:
			profile.cleared_stages.append(stage)


## A fresh tower run waiting at `floor_number` (the heroes at full HP), replacing any run.
## At most the tower's top floor (a run past it would end at its first win; clear stages to
## raise it). "" or an error.
static func start_run_at(profile: Profile, tower: TowerConfig, floor_number: int) -> String:
	profile.run = null
	var error := RunDirector.start_tower(profile, tower, 1)
	if not error.is_empty():
		return error
	profile.run.floor_number = clampi(floor_number, 1, profile.tower_cap(tower))
	return ""
