class_name DamageType
extends Resource
## A kind of damage (Physical, Fire, Poison, …). Data only: a new element is a new .tres;
## resistances and (later) per-type power refer to it.

@export var display_name := ""
@export var color := Color.WHITE


func get_validation_errors() -> PackedStringArray:
	if display_name.is_empty():
		return PackedStringArray(["damage type has no display_name"])
	return PackedStringArray()
