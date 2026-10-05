@tool
class_name FloorGenerator
extends RefCounted
## Builds a tower floor's (or a stage's) encounter from its number: the same map and
## enemies for everyone, since the RNG is seeded from the tower's salt and the floor.
## Floors ending in 5 have an elite, multiples of 10 a boss with escorts. An enemy with a
## `max_per_floor` is never drawn past it.


static func encounter(config: TowerConfig, floor_number: int) -> Encounter:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([config.seed_salt, "floor", floor_number])
	return _build(config, floor_number, rng, "Floor %d" % floor_number, TowerConfig.is_boss_floor(floor_number))


## A stage plays like a boss floor at its difficulty floor, from its own seed.
static func stage_encounter(config: TowerConfig, stage: StageData) -> Encounter:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([config.seed_salt, "stage", stage.seed])
	return _build(config, stage.difficulty_floor, rng, stage.display_name, true, stage.map_typology)


static func _build(config: TowerConfig, floor_number: int, rng: RandomNumberGenerator, title: String, boss: bool,
		typology: MapTypology = null) -> Encounter:
	var band := config.band_for(floor_number)
	if band == null or band.enemy_pool.is_empty() or (boss and band.boss_pool.is_empty()):
		push_error("FloorGenerator: no usable band for floor %d (check the tower config)" % floor_number)
		return null
	var level := band.level_on(floor_number)
	var result := Encounter.new()
	result.display_name = title
	result.ai_profile = config.ai_profile
	var compositions := band.boss_compositions if boss else band.compositions
	if compositions.is_empty():
		_fill_at_random(config, band, floor_number, level, boss, rng, result)
	else:
		result.composition = _pick_composition(compositions, rng)
		_fill_from(result.composition, config, band, floor_number, level, boss, rng, result)
	var count := result.spawns.size()
	var layout := MapGenerator.pick_layout(rng, config.map_settings, floor_number)
	if typology == null:
		typology = band.pick_typology(rng, boss)
	result.map = MapGenerator.generate(rng, config.map_settings, count, boss, layout, typology, band.map_size_range(boss))
	result.map_typology = typology
	result.layout_name = MapGenerator.Layout.keys()[layout]
	return result


## A composition, drawn by weight.
static func _pick_composition(compositions: Array[CompositionData], rng: RandomNumberGenerator) -> CompositionData:
	var total := 0
	for composition in compositions:
		total += composition.weight
	var roll := rng.randi_range(1, total)
	for composition in compositions:
		roll -= composition.weight
		if roll <= 0:
			return composition
	return compositions.back()


## The composition's slots in order: a fixed enemy, else one of the band's with the slot's role
## (the boss slot from the boss pool), within each enemy's cap per floor.
static func _fill_from(composition: CompositionData, config: TowerConfig, band: FloorBand, floor_number: int, level: int,
		boss: bool, rng: RandomNumberGenerator, result: Encounter) -> void:
	for index in composition.slots.size():
		var slot := composition.slots[index]
		var spawn := EncounterSpawn.new()
		spawn.level = maxi(1, level + slot.level_offset)
		var boss_slot := boss and index == 0
		spawn.enemy = slot.enemy if slot.enemy != null else _pick_enemy(band.boss_pool if boss_slot else band.enemy_pool, slot.role, rng, result)
		if boss_slot:
			spawn.preset = config.boss_preset
		else:
			spawn.preset = config.elite_preset if index == 0 and TowerConfig.is_elite_floor(floor_number) else config.normal_preset
		result.spawns.append(spawn)


## One of `pool` with `role`, below its cap per floor. Failing that (validation reports a role
## the pool lacks), the cap still comes first: any of the pool below it, and only then any.
static func _pick_enemy(pool: Array[EnemyData], role: EnemyData.Role, rng: RandomNumberGenerator, result: Encounter) -> EnemyData:
	var below_cap := pool.filter(func(enemy: EnemyData) -> bool: return _below_cap(enemy, result))
	var with_role := below_cap.filter(func(enemy: EnemyData) -> bool: return enemy.role == role)
	var candidates := with_role if not with_role.is_empty() else (below_cap if not below_cap.is_empty() else pool)
	return candidates[rng.randi_range(0, candidates.size() - 1)]


static func _below_cap(enemy: EnemyData, result: Encounter) -> bool:
	return enemy.max_per_floor <= 0 or result.spawns.filter(func(s: EncounterSpawn) -> bool: return s.enemy == enemy).size() < enemy.max_per_floor


## Without compositions: `min_enemies` to `max_enemies` drawn from the pool (the boss first).
static func _fill_at_random(config: TowerConfig, band: FloorBand, floor_number: int, level: int, boss: bool,
		rng: RandomNumberGenerator, result: Encounter) -> void:
	var count := maxi(2, band.max_enemies) if boss else rng.randi_range(band.min_enemies, band.max_enemies)
	for i in count:
		var spawn := EncounterSpawn.new()
		spawn.level = level
		if boss and i == 0:
			spawn.enemy = band.boss_pool[rng.randi_range(0, band.boss_pool.size() - 1)]
			spawn.preset = config.boss_preset
		else:
			var pool := band.enemy_pool.filter(func(enemy: EnemyData) -> bool: return _below_cap(enemy, result))
			if pool.is_empty():
				pool = band.enemy_pool  # Every enemy capped: the band is too small for its count.
			spawn.enemy = pool[rng.randi_range(0, pool.size() - 1)]
			spawn.preset = config.elite_preset if i == 0 and TowerConfig.is_elite_floor(floor_number) else config.normal_preset
		result.spawns.append(spawn)
