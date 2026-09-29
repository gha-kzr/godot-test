class_name DamageType
extends Resource
## A kind of damage (Physical, Fire, Poison, …). Data only: a new element is a new .tres;
## resistances and (later) per-type power refer to it.

const DIRECTORY := "res://data/damage_types"

@export var display_name := ""
@export var color := Color.WHITE
## Display order (lower first), e.g. in the HUD's resistance list.
@export var sort_order := 0

static var _all: Array[DamageType] = []


## Every damage type of the game (the .tres files in DIRECTORY), in display order. Adding
## an element stays data-only: drop a file in the folder.
static func all() -> Array[DamageType]:
	if _all.is_empty():
		for file in ResourceLoader.list_directory(DIRECTORY):
			if file.ends_with(".tres"):
				var type := load(DIRECTORY.path_join(file)) as DamageType
				if type != null:
					_all.append(type)
		_all.sort_custom(func(a: DamageType, b: DamageType) -> bool:
			return a.sort_order < b.sort_order if a.sort_order != b.sort_order else a.display_name < b.display_name)
	return _all


func get_validation_errors() -> PackedStringArray:
	if display_name.is_empty():
		return PackedStringArray(["damage type has no display_name"])
	return PackedStringArray()
