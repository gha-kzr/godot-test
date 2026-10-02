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
	return _build(config, stage.difficulty_floor, rng, stage.display_name, true)


static func _build(config: TowerConfig, floor_number: int, rng: RandomNumberGenerator, title: String, boss: bool) -> Encounter:
	var band := config.band_for(floor_number)
	if band == null or band.enemy_pool.is_empty() or (boss and band.boss_pool.is_empty()):
		push_error("FloorGenerator: no usable band for floor %d (check the tower config)" % floor_number)
		return null
	var level := band.level_on(floor_number)
	var count := maxi(2, band.max_enemies) if boss else rng.randi_range(band.min_enemies, band.max_enemies)
	var result := Encounter.new()
	result.display_name = title
	result.ai_profile = config.ai_profile
	for i in count:
		var spawn := EncounterSpawn.new()
		spawn.level = level
		if boss and i == 0:
			spawn.enemy = band.boss_pool[rng.randi_range(0, band.boss_pool.size() - 1)]
			spawn.preset = config.boss_preset
		else:
			var pool := band.enemy_pool.filter(func(enemy: EnemyData) -> bool:
				return enemy.max_per_floor <= 0 or result.spawns.filter(func(s: EncounterSpawn) -> bool: return s.enemy == enemy).size() < enemy.max_per_floor)
			if pool.is_empty():
				pool = band.enemy_pool  # Every enemy capped: the band is too small for its count.
			spawn.enemy = pool[rng.randi_range(0, pool.size() - 1)]
			spawn.preset = config.elite_preset if i == 0 and TowerConfig.is_elite_floor(floor_number) else config.normal_preset
		result.spawns.append(spawn)
	result.map = MapGenerator.generate(rng, config.map_settings, count, boss,
			MapGenerator.pick_layout(rng, config.map_settings, floor_number))
	return result
