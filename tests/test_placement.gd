extends TestCase
## Start zones: the default placement by role, and rearranging heroes before the battle.

const OPEN := "0e 0  0  0  0\n0  0  0  0  0\n0  0  0  0  0\n0p 0p 0p 0p 0p"


func _heroes() -> Array[UnitData]:
	var list: Array[UnitData] = []
	for name in ["mage", "knight", "ranger"]:
		list.append(load("res://data/units/%s.tres" % name))
	return list


func _state(layout: String, heroes: Array[UnitData]) -> BattleState:
	var map := MapData.new()
	map.layout = layout
	return BattleState.create(map.parse(), heroes, [load("res://data/units/brute.tres")] as Array[UnitData], 1)


func test_melee_heroes_start_closest_to_the_enemies() -> void:
	var state := _state(OPEN, _heroes())
	assert_eq(state.zone.size(), 5)
	assert_eq(state.units[1].cell, Vector2i(0, 3), "the Knight: closest to the Brute")
	var cells := [state.units[0].cell, state.units[1].cell, state.units[2].cell]
	assert_true(cells.all(func(c: Vector2i) -> bool: return c in state.zone))
	assert_true(Placement.reach_score(_heroes()[1]) < Placement.reach_score(_heroes()[0]), "the Knight is melee")
	var ranged := [state.units[0], state.units[2]]
	ranged.sort_custom(func(a: UnitState, b: UnitState) -> bool: return a.cell.x < b.cell.x)
	assert_eq([ranged[0].cell.x, ranged[1].cell.x], [2, 4], "spread back by reach, the longest farthest")


func test_a_zone_with_one_cell_per_hero_keeps_the_authored_order() -> void:
	var state := _state("0e 0 0\n0p 0p 0p", _heroes())
	assert_eq([state.units[0].cell, state.units[1].cell, state.units[2].cell],
			[Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1)])


func test_heroes_move_and_swap_in_the_zone_before_the_start() -> void:
	var state := _state(OPEN, _heroes())
	var battle := Battle.new(state)
	var knight := state.units[1]
	var result := battle.perform(BattleActions.Place.new(1, Vector2i(4, 3)))
	assert_true(result.ok(), result.error)
	assert_eq(knight.cell, Vector2i(4, 3))
	assert_eq(result.events.size(), 2, "the Ranger stood there: swapped")
	var mage_cell := state.units[0].cell
	result = battle.perform(BattleActions.Place.new(1, mage_cell))
	assert_eq([knight.cell, state.units[0].cell], [mage_cell, Vector2i(4, 3)], "swapped")
	var placed := result.events.map(func(e: BattleEvents.Event) -> Array:
			return [e.subject_id(), (e as BattleEvents.UnitPlaced).cell])
	assert_eq(placed, [[1, mage_cell], [0, Vector2i(4, 3)]])
	assert_eq(battle.perform(BattleActions.Place.new(1, mage_cell)).events.size(), 0, "already there")


func test_placement_has_limits() -> void:
	var state := _state(OPEN, _heroes())
	var battle := Battle.new(state)
	assert_true(battle.perform(BattleActions.Place.new(0, Vector2i(2, 1))).error.contains("start zone"))
	assert_true(battle.perform(BattleActions.Place.new(3, Vector2i(4, 3))).error.contains("only heroes"))
	assert_true(state.clone().zone == state.zone, "clones keep the zone")
	battle.start()
	assert_true(state.started)
	assert_true(battle.perform(BattleActions.Place.new(0, Vector2i(4, 3))).error.contains("started"))


func test_nothing_but_placement_before_the_start() -> void:
	var state := _state(OPEN, _heroes())
	var battle := Battle.new(state)
	var first := state.turn_order.current_unit_id()
	assert_true(battle.perform(BattleActions.EndTurn.new(first)).error.contains("hasn't started"))
	assert_true(battle.perform(BattleActions.Move.new(first, Vector2i(2, 1))).error.contains("hasn't started"))


func test_self_spells_dont_count_as_reach() -> void:
	var knight := load("res://data/units/knight.tres") as UnitData
	var ranges := knight.spells.filter(func(s: SpellData) -> bool: return s.max_range > 0).map(func(s: SpellData) -> int: return s.max_range)
	var total := 0
	for r: int in ranges:
		total += r
	assert_eq(Placement.reach_score(knight), float(total) / ranges.size())
