@tool
class_name Positioning
extends Resource
## Where an AI-controlled unit likes to stand (its role's tactics): a band of walking distance
## (MP) to the nearest opponent, and staying close to an ally. EnemyAI adds this score for the
## cell a plan ends on, and moves a unit with nothing worth casting to its best cell. Without
## one, a unit just walks toward the nearest opponent.
##
## Keep max_distance within a hero's reach (3 MP + 1): a ranged unit may step back after
## shooting, but never so far that a melee hero can't catch it (no unbeatable kiting).

## A hero's reach (3 MP + 1): the farthest a unit may like to stand.
const MAX_DISTANCE := 4

## Preferred walking distance (MP) to the nearest opponent (what it must walk to get here): 1 is contact.
@export_range(1, 12) var min_distance := 1
@export_range(1, 12) var max_distance := 1
## Score lost per MP outside the band (a cast scores roughly its damage).
@export_range(0.0, 10.0) var distance_weight := 1.0
## Bonus for ending within `ally_range` cells (Manhattan) of a living ally.
@export_range(0.0, 20.0) var ally_weight := 0.0
@export_range(1, 6) var ally_range := 1


## The score of standing on `cell` given each cell's walking distance to the nearest opponent.
func score(state: BattleState, unit_id: int, cell: Vector2i, distances: Dictionary[Vector2i, int]) -> float:
	var total := 0.0
	var distance: int = distances.get(cell, -1)
	if distance >= 0:
		if distance < min_distance:
			total -= (min_distance - distance) * distance_weight
		elif distance > max_distance:
			total -= (distance - max_distance) * distance_weight
	if ally_weight > 0.0:
		var unit := state.units[unit_id]
		for other in state.units:
			if other.id != unit_id and other.is_alive() and other.team == unit.team \
					and Targeting.distance(other.cell, cell) <= ally_range:
				total += ally_weight
				break
	return total


func get_validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	if min_distance > max_distance:
		errors.append("positioning: min_distance (%d) > max_distance (%d)" % [min_distance, max_distance])
	if max_distance > MAX_DISTANCE:
		errors.append("positioning: max_distance %d is past a hero's reach (%d): it could kite for ever" % [max_distance, MAX_DISTANCE])
	return errors
