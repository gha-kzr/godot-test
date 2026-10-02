@tool
class_name DamageType
extends Resource
## A kind of damage (Physical, Fire, Poison, …). Data only: a new element is a new .tres;
## resistances and (later) per-type power refer to it.

const DIRECTORY := "res://data/damage_types"

@export var display_name := ""
@export var color := Color.WHITE
## The effect shown on a unit hit by this damage (a scene with a script `Fx` root, e.g. a particle
## burst); a spell can override it (`SpellData.impact_effect`). Empty: the default one.
@export var impact_effect: PackedScene
## The sound event played when a spell of this damage type is cast (an AudioSet.SFX_EVENTS name);
## a spell can override it (`SpellData.cast_sound`). Empty: the generic `cast`.
@export var cast_sound: StringName = &""
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
	var errors := PackedStringArray()
	if display_name.is_empty():
		errors.append("damage type has no display_name")
	if not cast_sound.is_empty() and cast_sound not in AudioSet.SFX_EVENTS:
		errors.append("%s: unknown cast_sound %s" % [display_name, cast_sound])
	return errors
