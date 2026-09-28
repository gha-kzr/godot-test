class_name AIProfile
extends Resource
## Scoring weights for EnemyAI. Different profiles give different behaviour
## (e.g. easier early battles, smarter late ones) without changing the AI code.

## Score of a kill on top of the HP it removed. Higher finishes off weak units.
@export_range(0.0, 100.0) var kill_bonus := 10.0
## Value of each HP healed on an ally.
@export_range(0.0, 10.0) var heal_weight := 1.0
## Cost of each HP of damage to an ally (or of killing one, times kill_bonus),
## relative to the same damage on an opponent.
@export_range(0.0, 10.0) var friendly_fire_weight := 1.5


func get_validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	# Export ranges only constrain the Inspector; hand-edited .tres files can go past them.
	for weight in ["kill_bonus", "heal_weight", "friendly_fire_weight"]:
		if get(weight) < 0.0:
			errors.append("AI profile: %s must be >= 0" % weight)
	return errors
