extends TestCase
## Map and floor generation: deterministic per floor, always playable.

const TOWER := "res://data/tower/tower.tres"


func _tower() -> TowerConfig:
	return load(TOWER) as TowerConfig


func _labels(encounter: Encounter) -> Array:
	return encounter.builds().map(func(b: EnemyData.Build) -> String: return b.label)


func test_a_floor_is_the_same_every_time() -> void:
	var a := FloorGenerator.encounter(_tower(), 1)
	var b := FloorGenerator.encounter(_tower(), 1)
	assert_eq(a.map.layout, b.map.layout, "same map")
	assert_eq(_labels(a), _labels(b), "same enemies")
	assert_ne(FloorGenerator.encounter(_tower(), 2).map.layout, a.map.layout, "another floor differs")


func test_the_first_hundred_floors_are_valid_and_playable() -> void:
	var tower := _tower()
	for floor_number in range(1, 101):
		var encounter := FloorGenerator.encounter(tower, floor_number)
		var errors := encounter.get_validation_errors()
		if not errors.is_empty():
			assert_eq(errors, PackedStringArray(), "floor %d" % floor_number)
			return
		assert_true(MapGenerator.is_playable(encounter.map, encounter.spawns.size()), "floor %d is connected" % floor_number)
		assert_eq(encounter.map.parse().player_spawns.size(), 3, "floor %d has 3 player spawns" % floor_number)


func test_elite_and_boss_floors() -> void:
	var tower := _tower()
	assert_true(_labels(FloorGenerator.encounter(tower, 5))[0].ends_with("Elite"), "floor 5: an elite")
	assert_false(_labels(FloorGenerator.encounter(tower, 4)).any(func(l: String) -> bool: return l.ends_with("Elite") or l.ends_with("Boss")))
	var boss := FloorGenerator.encounter(tower, 10)
	assert_true(_labels(boss)[0].ends_with("Boss"), "floor 10: a boss")
	assert_true(boss.spawns.size() >= 2, "with escorts")
	assert_eq(boss.map.parse().grid.size, Vector2i(tower.map_settings.boss_size, tower.map_settings.boss_size), "a bigger map")


func test_enemies_get_stronger_with_depth() -> void:
	var tower := _tower()
	assert_eq(FloorGenerator.encounter(tower, 1).spawns[0].level, 1)
	assert_true(FloorGenerator.encounter(tower, 41).spawns[0].level > FloorGenerator.encounter(tower, 11).spawns[0].level)
	assert_true(FloorGenerator.encounter(tower, 1).spawns.size() <= 2, "floor 1: one or two enemies")


func test_stages_are_deterministic_boss_fights() -> void:
	var tower := _tower()
	var stage := tower.stages[0]
	var a := FloorGenerator.stage_encounter(tower, stage)
	assert_eq(a.map.layout, FloorGenerator.stage_encounter(tower, stage).map.layout)
	assert_eq(a.display_name, "Ruined Gate")
	assert_true(_labels(a)[0].ends_with("Boss"))
	assert_ne(a.map.layout, FloorGenerator.encounter(tower, 10).map.layout, "not the same as floor 10")


func test_generated_maps_obey_the_climbing_rule() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	for i in 20:
		var map := MapGenerator.generate(rng, _tower().map_settings, 3)
		var grid := map.parse().grid
		for y in grid.size.y:
			for x in grid.size.x:
				var cell := Vector2i(x, y)
				if not grid.is_walkable(cell):
					continue
				for next in grid.neighbors(cell):
					if grid.is_walkable(next):
						assert_true(absi(grid.height_at(cell) - grid.height_at(next)) <= 1, "neighbours differ by at most one level")
