extends TestCase
## The shipped slice content: every resource loads and validates, the map is playable,
## and AI-vs-AI battles on it finish.

const CONTENT_DIRS := ["res://data/spells", "res://data/units", "res://data/maps", "res://data/ai"]
const MAP := "res://data/maps/slice.tres"
const PLAYERS := ["res://data/units/knight.tres", "res://data/units/mage.tres"]
const ENEMIES := ["res://data/units/brute.tres", "res://data/units/archer.tres"]


func _content_paths() -> Array[String]:
	var paths: Array[String] = []
	for dir in CONTENT_DIRS:
		for file in ResourceLoader.list_directory(dir):
			if file.ends_with(".tres"):
				paths.append(dir.path_join(file))
	return paths


func _team(paths: Array) -> Array[UnitData]:
	var team: Array[UnitData] = []
	for path: String in paths:
		team.append(load(path) as UnitData)
	return team


func _slice_state(rng_seed: int) -> BattleState:
	var map := load(MAP) as MapData
	return BattleState.create(map.parse(), _team(PLAYERS), _team(ENEMIES), rng_seed)


## Cells reachable on foot from `start` over any number of turns (units ignored).
func _walkable_from(grid: Grid, start: Vector2i) -> Dictionary[Vector2i, bool]:
	var seen: Dictionary[Vector2i, bool] = {start: true}
	var queue: Array[Vector2i] = [start]
	while not queue.is_empty():
		var cell: Vector2i = queue.pop_front()
		for next in grid.neighbors(cell):
			if not seen.has(next) and Movement.step_cost(grid, cell, next) >= 0:
				seen[next] = true
				queue.append(next)
	return seen


func test_every_content_file_loads_and_validates() -> void:
	var paths := _content_paths()
	assert_true(paths.size() >= 15, "found %d content files" % paths.size())
	for path in paths:
		var resource := load(path)
		assert_true(resource != null and resource.has_method("get_validation_errors"), "%s loads as content" % path)
		if resource != null and resource.has_method("get_validation_errors"):
			assert_eq(resource.get_validation_errors(), PackedStringArray(), path)


func test_slice_teams_and_spell_kinds() -> void:
	var units := _team(PLAYERS + ENEMIES)
	var kinds := {}
	for unit in units:
		assert_true(unit.spells.size() >= 2 and unit.spells.size() <= 3, "%s has 2-3 spells" % unit.display_name)
		for spell in unit.spells:
			if spell.area.kind != AreaShape.Kind.SINGLE:
				kinds["area"] = true
			elif spell.needs_line_of_sight:
				kinds["ranged"] = true
			elif spell.max_range == 1:
				kinds["melee"] = true
	assert_eq(kinds.keys().size(), 3, "melee, ranged with LoS and area spells, got %s" % [kinds.keys()])


func test_slice_map_is_playable() -> void:
	var parsed := (load(MAP) as MapData).parse()
	assert_eq(parsed.errors, PackedStringArray())
	assert_eq(parsed.grid.size, Vector2i(10, 10))
	assert_eq(parsed.player_spawns.size(), PLAYERS.size())
	assert_eq(parsed.enemy_spawns.size(), ENEMIES.size())
	# Climbing and dropping limits make walking one-way, so check both directions:
	# every floor cell can walk to a spawn, and a spawn can walk to every floor cell.
	var to_spawn := Movement.distances_to(parsed.grid, parsed.player_spawns)
	var from_spawn := _walkable_from(parsed.grid, parsed.player_spawns[0])
	for y in parsed.grid.size.y:
		for x in parsed.grid.size.x:
			var cell := Vector2i(x, y)
			if parsed.grid.is_walkable(cell):
				assert_true(to_spawn.has(cell), "%s can walk to the spawns" % cell)
				assert_true(from_spawn.has(cell), "%s can be reached from the spawns" % cell)
	var heights := {}
	for y in parsed.grid.size.y:
		for x in parsed.grid.size.x:
			heights[parsed.grid.height_at(Vector2i(x, y))] = true
	assert_true(heights.size() >= 3, "a few height levels")


func test_ai_vs_ai_battles_on_the_slice_finish() -> void:
	var outcomes := {}
	for rng_seed in range(1, 11):
		var battle := Battle.new(_slice_state(rng_seed))
		battle.start()
		var actions := 0
		while not battle.state.is_over() and actions < 1000:
			var actor := battle.state.turn_order.current_unit_id()
			var result := battle.perform(EnemyAI.choose_next(battle.state, actor))
			if not result.ok():
				assert_true(false, "seed %d: invalid action: %s" % [rng_seed, result.error])
				break
			actions += 1
		assert_true(battle.state.is_over(), "seed %d: battle ends within 1000 actions" % rng_seed)
		var outcome: String = BattleState.Outcome.keys()[battle.state.outcome()]
		outcomes[outcome] = outcomes.get(outcome, 0) + 1
	print("  slice AI-vs-AI outcomes over 10 seeds: %s" % outcomes)
