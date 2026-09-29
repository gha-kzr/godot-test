@tool
class_name StageData
extends Resource
## A stage: one generated battle, beaten once. It plays like the tower floor
## `difficulty_floor` and, once cleared, raises the tower's cap and adds a starting floor.

@export var display_name := ""
## Generation seed: the stage is the same battle for everyone.
@export var seed := 1
@export_range(1, 9999) var difficulty_floor := 10
@export_range(1, 9999) var unlocks_cap := 20
@export_range(1, 9999) var unlocks_start_floor := 11


func get_validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	if display_name.is_empty():
		errors.append("stage has no display_name")
	if unlocks_start_floor > unlocks_cap:
		errors.append("%s: starting floor above the cap it unlocks" % display_name)
	return errors
