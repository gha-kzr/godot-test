extends TestCase

const LAYOUT := "0p 0p 0 0e\n0  0  0 0e"


func _unit(unit_name: String, initiative: int) -> UnitData:
	return BattleFixtures.unit(unit_name, initiative)


func _map() -> MapData.ParseResult:
	var map := MapData.new()
	map.layout = LAYOUT
	return map.parse()


## Ids: 0 = Knight (50), 1 = Archer (80), 2 = Goblin (80), 3 = Orc (10).
func _state() -> BattleState:
	var players: Array[UnitData] = [_unit("Knight", 50), _unit("Archer", 80)]
	var enemies: Array[UnitData] = [_unit("Goblin", 80), _unit("Orc", 10)]
	return BattleState.create(_map(), players, enemies, 42)


func test_units_placed_on_spawns_by_team() -> void:
	var state := _state()
	assert_eq(state.units.size(), 4)
	assert_eq(state.units[0].cell, Vector2i(0, 0), "Knight on first player spawn")
	assert_eq(state.units[1].cell, Vector2i(1, 0), "Archer on second player spawn")
	assert_eq(state.units[2].team, UnitState.Team.ENEMY)
	assert_eq(state.units[3].cell, Vector2i(3, 1), "Orc on second enemy spawn")
	assert_eq(state.unit_at(Vector2i(3, 0)).data.display_name, "Goblin")
	assert_true(state.unit_at(Vector2i(2, 0)) == null, "empty cell")
	assert_eq(state.alive_units(UnitState.Team.ENEMY).size(), 2)


func test_rejects_too_few_spawns() -> void:
	var players: Array[UnitData] = [_unit("A", 1), _unit("B", 1), _unit("C", 1)]
	var enemies: Array[UnitData] = [_unit("D", 1)]
	expect_error("3/1 units for 2/2 spawns")
	assert_true(BattleState.create(_map(), players, enemies, 1) == null)


func test_turn_order_by_initiative_ties_by_id() -> void:
	var state := _state()
	assert_eq(state.turn_order.upcoming(), [1, 2, 0, 3] as Array[int])
	assert_eq(state.current_unit().data.display_name, "Archer")


func test_advance_wraps_into_next_round() -> void:
	var order := _state().turn_order
	assert_eq(order.round_number, 1)
	for i in 3:
		order.advance()
	assert_eq(order.current_unit_id(), 3, "last unit of round 1")
	assert_eq(order.advance(), 1, "first unit again")
	assert_eq(order.round_number, 2)


func test_removing_a_unit_that_already_acted_keeps_the_current_turn() -> void:
	var order := _state().turn_order  # 1, 2, 0, 3
	order.advance()  # current: 2
	order.remove(1)
	assert_eq(order.current_unit_id(), 2)
	assert_eq(order.advance(), 0)


func test_removing_a_later_unit_skips_it() -> void:
	var order := _state().turn_order  # 1, 2, 0, 3
	order.remove(0)
	assert_eq(order.advance(), 2)
	assert_eq(order.advance(), 3)


func test_removing_the_current_unit() -> void:
	var order := _state().turn_order  # 1, 2, 0, 3
	order.advance()  # current: 2
	order.remove(2)
	assert_eq(order.current_unit_id(), -1, "no current unit until advance")
	assert_eq(order.upcoming(), [0, 3, 1] as Array[int], "upcoming starts at the next unit")
	assert_eq(order.advance(), 0)
	assert_eq(order.round_number, 1)


func test_removing_the_current_unit_at_both_ends() -> void:
	var order := _state().turn_order  # 1, 2, 0, 3
	order.remove(1)  # current at index 0
	assert_eq(order.advance(), 2, "first unit removed")
	assert_eq(order.round_number, 1)

	order = _state().turn_order
	for i in 3:
		order.advance()  # current: 3 (last)
	order.remove(3)
	assert_eq(order.advance(), 1, "last unit removed wraps")
	assert_eq(order.round_number, 2)


func test_start_turn_refills_ap_and_mp() -> void:
	var unit := _state().units[0]
	unit.ap = 1
	unit.mp = 0
	unit.start_turn()
	assert_eq(unit.ap, 6)
	assert_eq(unit.mp, 3)


func test_dead_units_are_not_found_on_cells() -> void:
	var state := _state()
	state.units[2].hp = 0
	assert_false(state.is_occupied(Vector2i(3, 0)))
	assert_eq(state.alive_units(UnitState.Team.ENEMY).size(), 1)


func test_clone_is_independent() -> void:
	var state := _state()
	var copy := state.clone()
	copy.units[0].hp = 1
	copy.units[0].cell = Vector2i(2, 1)
	copy.turn_order.advance()
	assert_eq(state.units[0].hp, 20, "hp")
	assert_eq(state.units[0].cell, Vector2i(0, 0), "cell")
	assert_eq(state.turn_order.current_unit_id(), 1, "turn order")
	assert_true(copy.grid == state.grid, "grid is shared")
	assert_true(copy.units[0].data == state.units[0].data, "unit data is shared")


func test_rejects_empty_unit_slots() -> void:
	var players: Array[UnitData] = [_unit("A", 1), null]
	var enemies: Array[UnitData] = [_unit("B", 1)]
	expect_error("empty unit slot")
	assert_true(BattleState.create(_map(), players, enemies, 1) == null)


func test_grid_is_read_only() -> void:
	var grid := _state().grid
	expect_error("size is read-only")
	grid.size = Vector2i(1, 1)
	assert_eq(grid.size, Vector2i(4, 2))


func test_rng_is_seeded_and_cloned_deterministically() -> void:
	var a := _state()
	var b := _state()
	assert_eq(a.rng.randi(), b.rng.randi(), "same seed, same draws")
	var copy := a.clone()
	assert_eq(copy.rng.randi(), a.rng.randi(), "clone continues from the same point")


func test_average_rolls_replace_the_dice_and_are_cloned() -> void:
	var state := BattleFixtures.state("0p 0e")
	var rng_state := state.rng.state
	state.use_average_rolls = true
	assert_eq(state.roll(5, 8), 6, "average 6.5, rounded down")
	assert_eq(state.roll(4, 4), 4)
	assert_eq(state.rng.state, rng_state, "the dice are not used")
	assert_true(state.clone().use_average_rolls, "clones keep the setting")
	state.use_average_rolls = false
	var roll := state.roll(1, 100)
	assert_true(roll >= 1 and roll <= 100 and state.rng.state != rng_state, "dice again")
