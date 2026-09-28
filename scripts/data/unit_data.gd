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

@export_group("Visuals")
## Placeholder color used when no model_scene is set.
@export var color := Color.WHITE
## Optional model from an asset pack; replaces the placeholder capsule.
@export var model_scene: PackedScene


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
	return errors
