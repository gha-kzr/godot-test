@tool
class_name RuneData
extends Resource
## An item a hero equips in one of its 6 rune slots. Hand-made, fixed stats, a rarity.
## Common and rare runes stack (a hero may wear copies); epic and legendary are unique
## per hero. Only stat modifiers for now; the resource can hold other effects later.

enum Rarity { COMMON, RARE, EPIC, LEGENDARY }

## Grey, green, blue, orange: distinct at a glance (playtest feedback).
const RARITY_COLORS: Array[Color] = [Color(0.6, 0.62, 0.66), Color(0.3, 0.72, 0.3), Color(0.25, 0.5, 0.95), Color(0.95, 0.55, 0.1)]
## Relative drop weights, by rarity.
const RARITY_WEIGHTS: Array[int] = [60, 25, 10, 5]

@export var display_name := ""
@export var rarity := Rarity.COMMON
@export var modifiers: Array[StatModifier] = []


func is_unique() -> bool:
	return rarity >= Rarity.EPIC


func color() -> Color:
	return RARITY_COLORS[rarity]


func rarity_name() -> String:
	match rarity:
		Rarity.COMMON: return tr("Common")
		Rarity.RARE: return tr("Rare")
		Rarity.EPIC: return tr("Epic")
		Rarity.LEGENDARY: return tr("Legendary")
	return Rarity.keys()[rarity].capitalize()


## e.g. "+10 Power, +5 HP".
func describe() -> String:
	var parts: Array[String] = []
	for modifier in modifiers:
		if modifier != null:
			parts.append(modifier.describe())
	return ", ".join(parts)


func get_validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	if display_name.is_empty():
		errors.append("rune has no display_name")
	if modifiers.is_empty():
		errors.append("%s: no modifiers" % display_name)
	for modifier in modifiers:
		if modifier == null:
			errors.append("%s: empty modifier slot" % display_name)
			continue
		for error in modifier.get_validation_errors():
			errors.append("%s: %s" % [display_name, error])
	return errors
