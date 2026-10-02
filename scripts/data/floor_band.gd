@tool
class_name FloorBand
extends Resource
## The tower's difficulty from `from_floor` up to the next band: enemy levels, how many
## enemies, which kinds. The curve is data, tuned in the balance lab.

@export_range(1, 9999) var from_floor := 1
## Enemy level on `from_floor`; grows by `levels_per_floor` for each floor into the band.
@export_range(1, 99) var enemy_level := 1
@export_range(0.0, 5.0) var levels_per_floor := 0.0
@export_range(1, 6) var min_enemies := 1
@export_range(1, 6) var max_enemies := 2
@export var enemy_pool: Array[EnemyData] = []
## Bosses for boss floors (multiples of 10) in this band.
@export var boss_pool: Array[EnemyData] = []


func level_on(floor_number: int) -> int:
	return enemy_level + floori((floor_number - from_floor) * levels_per_floor)


func get_validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	var where := "band from floor %d" % from_floor
	if min_enemies > max_enemies:
		errors.append("%s: min_enemies > max_enemies" % where)
	if enemy_pool.is_empty():
		errors.append("%s: no enemies" % where)
	if boss_pool.is_empty():
		errors.append("%s: no bosses" % where)
	for enemy in enemy_pool + boss_pool:
		if enemy == null:
			errors.append("%s: empty enemy slot" % where)
	return errors
