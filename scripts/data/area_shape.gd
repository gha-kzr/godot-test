class_name AreaShape
extends Resource
## Cells a spell affects around its target cell. Cell expansion lives in the targeting rules.

enum Kind { SINGLE, CROSS, CIRCLE, LINE }

@export var kind := Kind.SINGLE
## Radius for CROSS and CIRCLE, length for LINE. Ignored for SINGLE.
@export_range(0, 10) var size := 0


func get_validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	if kind != Kind.SINGLE and size < 1:
		errors.append("area size must be >= 1 for %s" % Kind.keys()[kind])
	return errors
