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


func get_validation_errors() -> PackedStringArray:
	if min_size > max_size:
		return PackedStringArray(["map settings: min_size > max_size"])
	return PackedStringArray()
