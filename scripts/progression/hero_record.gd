@tool
class_name HeroRecord
extends RefCounted
## A hero's lasting progress: level, XP, its 6 rune slots and its 5 active spells (the
## loadout). Plain data, saved in the profile; turned into battle input by
## battle_unit_data() and modifiers().

const RUNE_SLOTS := 6
## Active spells a hero brings to a fight (the spell bar's slots).
const LOADOUT_SLOTS := 5

var hero: HeroData
var level := 1
var xp := 0
## RUNE_SLOTS entries; null is an empty slot.
var runes: Array[RuneData] = []
## The active spells as chosen, slot by slot (null: empty). Read it through spells(), which
## settles it against the spells known at the current level.
var loadout: Array[SpellData] = []


func _init(hero_data: HeroData) -> void:
	hero = hero_data
	runes.resize(RUNE_SLOTS)
	loadout.resize(LOADOUT_SLOTS)


## Permanent battle modifiers: every level reward reached, then every rune worn.
func modifiers() -> Array[StatModifier]:
	var result: Array[StatModifier] = []
	for reached in range(2, level + 1):
		var reward := hero.reward_for(reached)
		if reward != null:
			result.append_array(reward.modifiers)
	for rune in runes:
		if rune != null:
			result.append_array(rune.modifiers)
	return result


## The base kit, then the spells unlocked by the levels reached, in learning order.
func known_spells() -> Array[SpellData]:
	var result: Array[SpellData] = []
	for spell in hero.unit.spells:
		if spell not in result:
			result.append(spell)
	for reached in range(2, level + 1):
		var reward := hero.reward_for(reached)
		if reward != null:
			for spell in reward.spells:
				if spell not in result:
					result.append(spell)
	return result


## The active spells, in slot order: the loadout's known spells (unknown or repeated ones
## dropped), then known spells not in it, in learning order, while slots are free. So a hero
## always has min(LOADOUT_SLOTS, known) spells and a newly learned one takes a free slot.
func spells() -> Array[SpellData]:
	var known := known_spells()
	var result: Array[SpellData] = []
	for spell in loadout:
		if spell != null and spell in known and spell not in result:
			result.append(spell)
	for spell in known:
		if result.size() >= LOADOUT_SLOTS:
			break
		if spell not in result:
			result.append(spell)
	return result


## Known spells that aren't in the loadout.
func inactive_spells() -> Array[SpellData]:
	var active := spells()
	return known_spells().filter(func(spell: SpellData) -> bool: return spell not in active)


## Writes spells() back into the loadout (empty slots at the end), e.g. before saving.
func settle_loadout() -> void:
	var active := spells()
	loadout.clear()
	loadout.resize(LOADOUT_SLOTS)
	for slot in active.size():
		loadout[slot] = active[slot]


## Puts a known spell in a filled slot: one already active swaps places with the slot's
## spell, an inactive one replaces it. Spells are never removed, so an empty slot only takes
## a spell by learning one. Returns an error, or "".
func assign_spell(slot: int, spell: SpellData) -> String:
	settle_loadout()
	if slot < 0 or slot >= LOADOUT_SLOTS or loadout[slot] == null:
		return "no spell in slot %d" % slot
	if spell == null or spell not in known_spells():
		return "%s doesn't know that spell" % hero.display_name()
	var other := loadout.find(spell)
	if other != -1:
		loadout[other] = loadout[slot]
	loadout[slot] = spell
	return ""


## The hero's unit for a battle: the base template with its unlocked spells. Stats from
## levels and runes are not baked in; they come with modifiers().
func battle_unit_data() -> UnitData:
	# duplicate() is shallow: arrays and sub-resources are still the template's. Only assign
	# new values here (as for `spells`); never mutate them in place.
	var data := hero.unit.duplicate() as UnitData
	data.spells = spells()
	return data


func free_slot() -> int:
	return runes.find(null)
