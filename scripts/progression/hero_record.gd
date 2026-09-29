@tool
class_name HeroRecord
extends RefCounted
## A hero's lasting progress: level, XP and its 6 rune slots. Plain data, saved in the
## profile; turned into battle input by battle_unit_data() and modifiers().

const RUNE_SLOTS := 6

var hero: HeroData
var level := 1
var xp := 0
## RUNE_SLOTS entries; null is an empty slot.
var runes: Array[RuneData] = []


func _init(hero_data: HeroData) -> void:
	hero = hero_data
	runes.resize(RUNE_SLOTS)


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


## The base kit, then the spells unlocked by the levels reached.
func spells() -> Array[SpellData]:
	var result: Array[SpellData] = hero.unit.spells.duplicate()
	for reached in range(2, level + 1):
		var reward := hero.reward_for(reached)
		if reward != null:
			result.append_array(reward.spells)
	return result


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
