@tool
class_name UnitData
extends Resource
## Template for a unit. Shared and read-only at runtime; per-battle values live in UnitState.

@export var display_name := ""
@export_range(1, 9999) var max_hp := 30
@export_range(0, 20) var ap := 6
@export_range(0, 20) var mp := 3
## Higher acts first in the turn order.
@export_range(0, 999) var initiative := 100
@export var spells: Array[SpellData] = []
## Modifiers the unit always has, in every battle (e.g. an enemy's resistances). Summed
## with statuses, levels and runes like any other modifier.
@export var innate_modifiers: Array[StatModifier] = []

@export_group("Visuals")
## Placeholder color used when no model_scene is set.
@export var color := Color.WHITE
## Optional model from an asset pack; replaces the placeholder capsule. Its animations are
## found by name (see UnitModel), so models from any pack work; a new hero or enemy is a model
## file plus these fields.
@export var model_scene: PackedScene
## Scales the model to the board (a cell is one world unit wide).
@export_range(0.05, 5.0) var model_scale := 1.0
## How tall the scaled model stands, in world units: where the HP label, status icons and
## damage preview float, and how tall the click target is.
@export_range(0.3, 4.0) var model_height := 1.1
## Replaces the model's "Skin" material color; alpha 0 keeps the pack's own.
@export var skin_color := Color(0, 0, 0, 0)
## A prop the model holds instead of one of its own parts (a bow instead of the Skeleton's
## dagger): `held_item` takes the place, bone and orientation of the model's node named
## `held_item_replaces` (hidden), at `held_item_scale`, turned by `held_item_rotation` degrees.
@export var held_item: PackedScene
@export var held_item_replaces := ""
@export var held_item_scale := 1.0
@export var held_item_rotation := Vector3.ZERO


func get_validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	if display_name.is_empty():
		errors.append("unit has no display_name")
	if max_hp < 1:
		errors.append("%s: max_hp must be >= 1" % display_name)
	for spell in spells:
		if spell == null:
			errors.append("%s: empty spell slot" % display_name)
			continue
		for error in spell.get_validation_errors():
			errors.append("%s: %s" % [display_name, error])
		if spell.ap_cost > ap:
			errors.append("%s: %s costs %d AP but the unit has %d" % [display_name, spell.display_name, spell.ap_cost, ap])
	for modifier in innate_modifiers:
		if modifier == null:
			errors.append("%s: empty innate modifier slot" % display_name)
			continue
		for error in modifier.get_validation_errors():
			errors.append("%s: %s" % [display_name, error])
	return errors
