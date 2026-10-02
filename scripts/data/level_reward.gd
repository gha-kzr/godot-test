@tool
class_name LevelReward
extends Resource
## What a hero gains on reaching a level: stat modifiers and spells. A hero's rewards are
## a data table (HeroData.level_rewards); a skill / passive tree can replace it later.

@export var modifiers: Array[StatModifier] = []
@export var spells: Array[SpellData] = []


## e.g. "+3 HP, +3 Power, learns Whirlwind".
func describe() -> String:
	var parts: Array[String] = []
	for modifier in modifiers:
		if modifier != null:
			parts.append(modifier.describe())
	for spell in spells:
		if spell != null:
			parts.append(tr("learns %s") % tr(spell.display_name))
	return ", ".join(parts)


func get_validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	for modifier in modifiers:
		if modifier == null:
			errors.append("empty modifier slot")
			continue
		errors.append_array(modifier.get_validation_errors())
	for spell in spells:
		if spell == null:
			errors.append("empty spell slot")
			continue
		errors.append_array(spell.get_validation_errors())
	return errors
