class_name SpellData
extends Resource

@export var display_name := ""
@export_range(0, 12) var ap_cost := 3
## Manhattan distance from the caster. 0 allows targeting the caster's own cell.
@export_range(0, 20) var min_range := 1
@export_range(0, 20) var max_range := 1
@export var needs_line_of_sight := true
## Whether standing higher than the target extends max_range (formula in the targeting rules).
@export var height_extends_range := false
@export var area: AreaShape
@export var effects: Array[EffectData] = []


func get_validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	if display_name.is_empty():
		errors.append("spell has no display_name")
	if min_range > max_range:
		errors.append("%s: min_range (%d) > max_range (%d)" % [display_name, min_range, max_range])
	if area == null:
		errors.append("%s: no area" % display_name)
	else:
		for error in area.get_validation_errors():
			errors.append("%s: %s" % [display_name, error])
	if effects.is_empty():
		errors.append("%s: no effects" % display_name)
	for effect in effects:
		if effect == null:
			errors.append("%s: empty effect slot" % display_name)
			continue
		for error in effect.get_validation_errors():
			errors.append("%s: %s" % [display_name, error])
	return errors
