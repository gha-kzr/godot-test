@tool
class_name BoonData
extends Resource
## A run-only bonus picked after a tower boss: like a hidden rune worn by the whole team
## until the run ends. Its tier matches the boss floor (1: floor 10, 2: floor 20, 3: 30+).

@export var display_name := ""
@export_range(1, 9) var tier := 1
@export var modifiers: Array[StatModifier] = []


func describe() -> String:
	var parts: Array[String] = []
	for modifier in modifiers:
		if modifier != null:
			parts.append(modifier.describe())
	return ", ".join(parts)


func get_validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	if display_name.is_empty():
		errors.append("boon has no display_name")
	if modifiers.is_empty():
		errors.append("%s: no modifiers" % display_name)
	for modifier in modifiers:
		if modifier == null:
			errors.append("%s: empty modifier slot" % display_name)
			continue
		for error in modifier.get_validation_errors():
			errors.append("%s: %s" % [display_name, error])
	return errors
