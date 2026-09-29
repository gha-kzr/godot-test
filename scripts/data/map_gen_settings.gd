@tool
class_name MapGenSettings
extends Resource
## How the tower's maps are generated.

@export_range(6, 30) var min_size := 8
@export_range(6, 30) var max_size := 11
## Boss floors get larger, more open maps.
@export_range(6, 30) var boss_size := 12
@export_range(0, 20) var plateaus := 4
@export_range(1, 5) var max_height := 2
@export_range(0.0, 0.3) var obstacle_density := 0.07
@export_range(0.0, 0.3) var hole_density := 0.04
@export_range(0.0, 0.3) var boss_obstacle_density := 0.04
@export_group("Start zone layouts")
## How often each layout comes up (relative weights).
@export_range(0, 100) var edge_weight := 6
@export_range(0, 100) var corner_weight := 3
@export_range(0, 100) var ambush_weight := 1
## No ambush before this floor.
@export_range(1, 9999) var ambush_from_floor := 6
## Ambush maps are at least this big, so enemies on the edges are far enough.
@export_range(9, 30) var ambush_size := 13
## Every start-zone cell is at least this many MP from every enemy spawn.
@export_range(0, 20) var min_enemy_distance := 5


func get_validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	if min_size > max_size:
		errors.append("map settings: min_size > max_size")
	if edge_weight + corner_weight + ambush_weight <= 0:
		errors.append("map settings: every layout weight is 0")
	return errors
