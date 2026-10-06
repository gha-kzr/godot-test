@tool
class_name PvpHero
extends Resource
## A class a player can pick in a PvP match: a unit with its five spells at fixed strength (no levels, no
## runes, no Power: spell numbers are what they show). PvP only; the single-player heroes are separate.

enum Gender { NEUTRAL, FEMALE, MALE }

@export var unit: UnitData
## A few words for the card: what the class does in a team ("Frontline bruiser").
@export var role_label := ""
## One or two sentences: how it plays, and what it is weak to.
@export_multiline var description := ""
@export var gender := Gender.NEUTRAL
## Where the AI likes this class to stand when it plays it (a player who left, or a simulation): null walks
## straight at the nearest enemy; ranged classes keep their distance, a healer stays near its allies.
@export var ai_positioning: Positioning


func display_name() -> String:
	return unit.display_name if unit != null else "?"


func get_validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	if unit == null:
		return PackedStringArray(["PvP hero has no unit"])
	for error in unit.get_validation_errors():
		errors.append(error)
	if unit.spells.size() < 3 or unit.spells.size() > 5:
		errors.append("%s: a PvP class has 3 to 5 spells (has %d)" % [display_name(), unit.spells.size()])
	if role_label.is_empty():
		errors.append("%s: no role_label" % display_name())
	if description.is_empty():
		errors.append("%s: no description" % display_name())
	if not unit.innate_modifiers.is_empty():
		for modifier in unit.innate_modifiers:
			if modifier != null and modifier.stat == StatModifier.Stat.POWER:
				errors.append("%s: PvP classes have no Power (put the numbers in the spells)" % display_name())
	return errors
