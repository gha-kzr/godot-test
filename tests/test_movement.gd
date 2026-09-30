extends TestCase
## Unit 0 is the first player spawn in each layout.


func _reach(layout: String, mp := 3) -> Movement.Reach:
	var state := BattleFixtures.state(layout, mp)
	return Movement.reach(state, 0)


func test_flat_map_reach_is_a_diamond() -> void:
	var reach := _reach("""
		0 0 0 0 0
		0 0 0 0 0
		0 0 0p 0 0
		0 0 0 0 0
		0 0 0 0 0e""", 2)
	assert_eq(reach.cells().size(), 12, "radius-2 diamond minus origin")
	assert_true(reach.can_reach(Vector2i(2, 0)), "straight 2")
	assert_true(reach.can_reach(Vector2i(1, 1)), "diagonal 1+1")
	assert_false(reach.can_reach(Vector2i(0, 0)), "corner is 4 away")
	assert_false(reach.can_reach(Vector2i(2, 2)), "origin is not a destination")


func test_zero_mp_reaches_nothing() -> void:
	assert_eq(_reach("0p 0 0e", 0).cells().size(), 0)


func test_climbing_costs_extra_mp() -> void:
	var reach := _reach("0p 1 1 0e", 3)
	assert_eq(reach.cost_to(Vector2i(1, 0)), 2, "climb 1 level = 1 + 1")
	assert_eq(reach.cost_to(Vector2i(2, 0)), 3, "then flat")


func test_climbing_two_levels_is_impossible() -> void:
	var reach := _reach("0p 2 0\n0 0 0\n0 0 0e", 6)
	assert_false(reach.can_reach(Vector2i(1, 0)), "too high")
	assert_eq(reach.path_to(Vector2i(2, 0)), [Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1), Vector2i(2, 0)] as Array[Vector2i], "goes around")


func test_dropping_is_free_up_to_two_levels() -> void:
	var reach := _reach("2p 0 0e", 3)
	assert_eq(reach.cost_to(Vector2i(1, 0)), 1, "drop 2")
	reach = _reach("3p 0 0e", 3)
	assert_false(reach.can_reach(Vector2i(1, 0)), "drop 3 is too far")


func test_obstacles_and_holes_block() -> void:
	# The only way to (2, 0) is the 6-step detour through row 2.
	var layout := "0p # 0\n0 . 0\n0 0 0\n0e 0 0"
	var reach := _reach(layout, 6)
	assert_false(reach.can_reach(Vector2i(1, 0)), "obstacle")
	assert_false(reach.can_reach(Vector2i(1, 1)), "hole")
	assert_eq(reach.cost_to(Vector2i(2, 0)), 6, "detour around both")
	assert_false(_reach(layout, 5).can_reach(Vector2i(2, 0)), "5 MP is not enough")


func test_allies_are_walked_through_but_not_stopped_on() -> void:
	# Corridor: P0 at the left, ally P1 in the middle, enemy E0 below.
	var reach := _reach("0p 0p 0\n#  0e #", 5)
	assert_false(reach.can_reach(Vector2i(1, 0)), "ally cell: not a destination")
	assert_eq(reach.cost_to(Vector2i(1, 0)), -1)
	assert_false(Vector2i(1, 0) in reach.cells())
	assert_true(reach.can_reach(Vector2i(2, 0)), "through the ally")
	assert_eq(reach.path_to(Vector2i(2, 0)), [Vector2i(1, 0), Vector2i(2, 0)] as Array[Vector2i])
	assert_eq(reach.cost_to(Vector2i(2, 0)), 2, "the ally's cell costs its normal step")


func test_enemies_block() -> void:
	var reach := _reach("0p 0e 0\n#  #  #", 5)
	assert_false(reach.can_reach(Vector2i(1, 0)), "enemy cell")
	assert_false(reach.can_reach(Vector2i(2, 0)), "can't pass through an enemy")


func test_enemies_walk_through_their_allies_too() -> void:
	var state := BattleFixtures.state("0p 0 0 0e 0e", 5)
	var reach := Movement.reach(state, 2)  # The enemy at the far end, behind its ally.
	assert_true(reach.can_reach(Vector2i(1, 0)))
	assert_false(reach.can_reach(Vector2i(0, 0)), "the hero still blocks")


func test_a_move_through_an_ally_reports_the_whole_path() -> void:
	var state := BattleFixtures.state("0p 0p 0\n#  0e #", 5)
	var battle := Battle.new(state)
	battle.start()  # P0 acts first.
	var result := battle.perform(BattleActions.Move.new(0, Vector2i(2, 0)))
	assert_true(result.ok(), result.error)
	var moved := result.events[0] as BattleEvents.UnitMoved
	assert_eq(moved.path, [Vector2i(1, 0), Vector2i(2, 0)] as Array[Vector2i])
	assert_false(battle.perform(BattleActions.Move.new(0, Vector2i(1, 0))).ok(), "can't end on the ally")


func test_dead_units_do_not_block() -> void:
	var state := BattleFixtures.state("0p 0p 0\n0e 0 0", 5)
	state.units[1].hp = 0
	assert_true(Movement.reach(state, 0).can_reach(Vector2i(2, 0)))


func test_prefers_the_cheapest_route_over_the_fewest_steps() -> void:
	# Straight along row 0: 6 steps over three bumps = 9 MP. Via flat row 1: 8 steps = 8 MP.
	var reach := _reach("0p 1 0 1 0 1 0\n0 0 0 0 0 0 0\n0e 0 0 0 0 0 0", 10)
	assert_eq(reach.cost_to(Vector2i(6, 0)), 8, "cost")
	var path := reach.path_to(Vector2i(6, 0))
	assert_eq(path.size(), 8, "steps")
	assert_eq(path[0], Vector2i(0, 1), "leaves row 0 first")


func test_path_matches_cost_and_is_deterministic() -> void:
	var layout := "0p 0 0\n0 0 0\n0 0 0e"
	var path := _reach(layout).path_to(Vector2i(1, 2))
	assert_eq(path.size(), 3)
	assert_eq(_reach(layout).cost_to(Vector2i(1, 2)), 3, "cost")
	assert_eq(path.back(), Vector2i(1, 2), "ends on destination")
	assert_eq(_reach(layout).path_to(Vector2i(1, 2)), path, "same path every time")
	assert_eq(_reach(layout).path_to(Vector2i(2, 2)), [] as Array[Vector2i], "occupied destination")


func test_works_on_clones_by_id() -> void:
	var state := BattleFixtures.state("0p 0 0 0\n0 0 0 0e", 1)
	var copy := state.clone()
	copy.units[0].cell = Vector2i(2, 0)
	assert_true(Movement.reach(copy, 0).can_reach(Vector2i(3, 0)), "uses the clone's position")
	assert_false(Movement.reach(state, 0).can_reach(Vector2i(3, 0)), "original unchanged")


func test_step_cost_terrain_only() -> void:
	var grid := BattleFixtures.state("0p 1 3 #\n0 0 0 0e").grid
	assert_eq(Movement.step_cost(grid, Vector2i(0, 0), Vector2i(1, 0)), 2, "climb 1")
	assert_eq(Movement.step_cost(grid, Vector2i(1, 0), Vector2i(0, 0)), 1, "drop 1")
	assert_eq(Movement.step_cost(grid, Vector2i(1, 0), Vector2i(2, 0)), -1, "climb 2")
	assert_eq(Movement.step_cost(grid, Vector2i(2, 0), Vector2i(3, 0)), -1, "obstacle")


# --- Distances over several turns ---

func test_distances_follow_walking_cost_around_walls_and_ignore_units() -> void:
	var state := BattleFixtures.state("""
		0p 0  0
		#  #  0
		0e 0p 0""")
	var distances := Movement.distances_to(state.grid, [Vector2i(0, 2)] as Array[Vector2i])
	assert_eq(distances[Vector2i(0, 2)], 0, "goal")
	assert_eq(distances[Vector2i(2, 2)], 2, "walks through the unit on (1, 2)")
	assert_eq(distances[Vector2i(0, 0)], 6, "around the wall, not through it")
	assert_false(distances.has(Vector2i(0, 1)), "obstacles have no distance")


func test_distances_charge_climbing_on_the_way_to_the_goal() -> void:
	# Walking from the low cell up to the goal climbs; walking from the high cell drops.
	var state := BattleFixtures.state("0p 1e 0")
	var distances := Movement.distances_to(state.grid, [Vector2i(1, 0)] as Array[Vector2i])
	assert_eq(distances[Vector2i(0, 0)], 2, "climb 1 level into the goal")
	var down := Movement.distances_to(state.grid, [Vector2i(0, 0)] as Array[Vector2i])
	assert_eq(down[Vector2i(1, 0)], 1, "drop into the goal is free")
	var cliff := BattleFixtures.state("0p 0 2e")
	var up := Movement.distances_to(cliff.grid, [Vector2i(2, 0)] as Array[Vector2i])
	assert_false(up.has(Vector2i(1, 0)), "a 2-level climb can't reach the goal")


func test_the_origin_costs_nothing() -> void:
	var reach := _reach("0p 0 0e", 3)
	assert_eq(reach.cost_to(Vector2i(0, 0)), 0, "not an ally's cell to walk through")


func test_climbing_steps_lists_each_climb_with_its_extra_cost() -> void:
	var state := BattleFixtures.state("0p 1 2 1 0e", 8)
	var reach := Movement.reach(state, 0)
	var path := reach.path_to(Vector2i(3, 0))
	assert_eq(Movement.climbing_steps(state.grid, reach.origin, path), {Vector2i(1, 0): 1, Vector2i(2, 0): 1} as Dictionary[Vector2i, int])
	assert_eq(reach.cost_to(Vector2i(3, 0)), 5, "3 steps + 2 climbs")
	assert_eq(Movement.climbing_steps(state.grid, reach.origin, [] as Array[Vector2i]).size(), 0)
