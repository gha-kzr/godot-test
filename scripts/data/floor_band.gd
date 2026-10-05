@tool
class_name FloorBand
extends Resource
## The tower's difficulty from `from_floor` up to the next band: enemy levels, which enemies,
## and the teams they form (compositions; without any, `min_enemies` to `max_enemies` drawn at
## random from the pool). The curve is data, tuned in the balance lab.

## Boss floors and stages get maps this much bigger than the band's, up to MAX_MAP_SIZE.
const BOSS_SIZE_BONUS := 2
const MAX_MAP_SIZE := 20
## The smallest map side that holds the start zone and the enemies' walk.
const MIN_MAP_SIZE := 9

@export_range(1, 9999) var from_floor := 1
## Enemy level on `from_floor`; grows by `levels_per_floor` for each floor into the band.
@export_range(1, 99) var enemy_level := 1
@export_range(0.0, 5.0) var levels_per_floor := 0.0
@export_range(1, 6) var min_enemies := 1
@export_range(1, 6) var max_enemies := 2
@export var enemy_pool: Array[EnemyData] = []
## Bosses for boss floors (multiples of 10) in this band.
@export var boss_pool: Array[EnemyData] = []
## Teams for normal and elite floors; their slots' roles are filled from `enemy_pool`.
@export var compositions: Array[CompositionData] = []
## Teams for boss floors and stages: the first slot is the boss, from `boss_pool`.
@export var boss_compositions: Array[CompositionData] = []
## The maps' width and height (0: the tower's map settings); boss floors and stages get
## BOSS_SIZE_BONUS more, up to MAX_MAP_SIZE.
@export_range(0, 30) var map_min_size := 0
@export_range(0, 30) var map_max_size := 0
## Map typologies and their weights (none: an open field from the map settings).
@export var map_typologies: Dictionary[MapTypology, int] = {}
## For boss floors (none: map_typologies).
@export var boss_map_typologies: Dictionary[MapTypology, int] = {}


func level_on(floor_number: int) -> int:
	return enemy_level + floori((floor_number - from_floor) * levels_per_floor)


## The size range of this band's maps (x to y), or zero for the map settings'.
func map_size_range(boss: bool) -> Vector2i:
	if map_min_size <= 0 or map_max_size <= 0:
		return Vector2i.ZERO
	if boss:
		var size := mini(map_max_size + BOSS_SIZE_BONUS, MAX_MAP_SIZE)
		return Vector2i(size, size)
	return Vector2i(map_min_size, map_max_size)


## A typology for a floor of this band, drawn by weight (null: none set).
func pick_typology(rng: RandomNumberGenerator, boss: bool) -> MapTypology:
	var weights := boss_map_typologies if boss and not boss_map_typologies.is_empty() else map_typologies
	var total := 0
	for typology in weights:
		total += weights[typology]
	if total <= 0:
		return null
	var roll := rng.randi_range(1, total)
	for typology in weights:
		roll -= weights[typology]
		if roll <= 0:
			return typology
	return null


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
	if map_min_size > map_max_size:
		errors.append("%s: map_min_size > map_max_size" % where)
	if (map_min_size > 0) != (map_max_size > 0):
		errors.append("%s: set both map_min_size and map_max_size, or neither" % where)
	elif map_min_size > 0 and (map_min_size < MIN_MAP_SIZE or map_max_size > MAX_MAP_SIZE):
		errors.append("%s: map sizes must be %d to %d" % [where, MIN_MAP_SIZE, MAX_MAP_SIZE])
	for weights: Dictionary[MapTypology, int] in [map_typologies, boss_map_typologies]:
		for typology in weights:
			if typology == null:
				errors.append("%s: empty map typology" % where)
			elif weights[typology] < 1:
				errors.append("%s: %s has a weight below 1" % [where, typology.label])
	if not compositions.is_empty() and boss_compositions.is_empty():
		errors.append("%s: compositions but no boss compositions" % where)
	for composition in compositions + boss_compositions:
		if composition == null:
			errors.append("%s: empty composition slot" % where)
			continue
		for error in composition.get_validation_errors():
			errors.append("%s: %s" % [where, error])
		for index in composition.slots.size():
			var slot := composition.slots[index]
			if slot == null or slot.enemy != null:
				continue
			var boss := composition in boss_compositions and index == 0
			var pool := boss_pool if boss else enemy_pool
			if not pool.any(func(enemy: EnemyData) -> bool: return enemy != null and enemy.role == slot.role):
				errors.append("%s: %s needs a %s the %s doesn't have" % [where, composition.label,
						EnemyData.Role.keys()[slot.role].to_lower(), "boss pool" if boss else "enemy pool"])
	return errors
