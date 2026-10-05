extends TestCase
## Positioning: where an AI unit likes to stand (its role), and that kiting stays beatable.


func _positioning(lo: int, hi: int, weight := 1.5, ally := 0.0) -> Positioning:
	var p := Positioning.new()
	p.min_distance = lo
	p.max_distance = hi
	p.distance_weight = weight
	p.ally_weight = ally
	return p


## The enemy (unit 1) on `layout`, with `positioning`, at its turn.
func _state(layout: String, positioning: Positioning, enemy_spells: Array[SpellData] = []) -> BattleState:
	var state := BattleFixtures.state(layout, 4)
	for unit in state.units:
		if unit.team == UnitState.Team.ENEMY:
			unit.positioning = positioning
			unit.data.spells = enemy_spells
	var battle := Battle.new(state)
	battle.start()
	while state.turn_order.current_unit_id() != 1:
		battle.perform(BattleActions.EndTurn.new(state.turn_order.current_unit_id()))
	return state


func test_the_score_is_flat_inside_the_band_and_drops_outside() -> void:
	var state := _state("0p 0 0 0 0 0 0 0e", _positioning(3, 4))
	var distances := EnemyAI._opponent_reach(state, 1)
	var p := state.units[1].positioning
	assert_eq(p.score(state, 1, Vector2i(3, 0), distances), 0.0, "3 away")
	assert_eq(p.score(state, 1, Vector2i(4, 0), distances), 0.0, "4 away")
	assert_eq(p.score(state, 1, Vector2i(1, 0), distances), -3.0, "2 too close")
	assert_eq(p.score(state, 1, Vector2i(7, 0), distances), -4.5, "3 too far")


func test_with_nothing_to_cast_a_ranged_unit_takes_its_distance() -> void:
	var state := _state("0p 0 0 0 0 0 0 0 0e", _positioning(3, 4))
	var action := EnemyAI.choose_next(state, 1)
	assert_true(action is BattleActions.Move)
	var distance := Targeting.distance((action as BattleActions.Move).destination, Vector2i(0, 0))
	assert_true(distance >= 3 and distance <= 4, "into its band (%d)" % distance)
	state = _state("0p 0e 0 0 0 0 0 0", _positioning(3, 4))
	action = EnemyAI.choose_next(state, 1)
	assert_true(action is BattleActions.Move and Targeting.distance((action as BattleActions.Move).destination, Vector2i(0, 0)) >= 3, "it steps back")


func test_an_ally_minded_unit_stays_by_its_ally() -> void:
	var state := _state("0p 0 0 0 0 0\n0 0 0 0 0 0e\n0 0 0 0 0 0e", _positioning(1, 6, 0.0, 3.0))
	var action := EnemyAI.choose_next(state, 1)
	assert_true(action is BattleActions.EndTurn or Targeting.distance((action as BattleActions.Move).destination, state.units[2].cell) <= 1,
			"it doesn't leave its ally")


func test_a_cast_still_beats_a_good_spot() -> void:
	var bolt := BattleFixtures.damage_spell(3, 1, 6, 8)
	var state := _state("0p 0 0e 0 0 0 0 0", _positioning(3, 4), [bolt] as Array[SpellData])
	assert_true(EnemyAI.choose_next(state, 1) is BattleActions.CastSpell or EnemyAI.choose_next(state, 1) is BattleActions.Move)
	var battle := Battle.new(state)
	var hp := state.units[0].hp
	for i in 4:
		var action := EnemyAI.choose_next(state, 1)
		battle.perform(action)
		if action is BattleActions.EndTurn:
			break
	assert_true(state.units[0].hp < hp, "it shot")


func test_the_distance_is_the_heroes_walk_uphill() -> void:
	# Climbing costs 1 MP more per level: the hero needs 7 MP to reach the plateau's edge,
	# though walking down from it takes 4.
	var state := _state("0p 1 2 3 3 3e", _positioning(3, 4))
	assert_eq(EnemyAI._opponent_reach(state, 1)[Vector2i(4, 0)], 7)
	assert_eq(Movement.distances_to(state.grid, [Vector2i(0, 0)] as Array[Vector2i])[Vector2i(4, 0)], 4)


## Whether an AI-played melee hero (3 MP) lands a hit on the Skeleton Archer within `max_turns`
## of its turns, on a 40-cell corridor (room to run away for ever if the archer were allowed to)
## whose middle row is `heights` (the hero on cell 2, the archer on cell 14).
func _hero_catches_archer(heights: Callable, max_turns: int) -> bool:
	var archer := (load("res://data/enemies/skeleton_archer.tres") as EnemyData).build(1)
	var hero := BattleFixtures.unit("Knight", 200, 3, 6, 400)
	hero.spells = [BattleFixtures.damage_spell(3, 1, 1, 5)] as Array[SpellData]
	var map := MapData.new()
	var row := " ".join(PackedStringArray(Array(range(40)).map(func(i: int) -> String: return str(heights.call(i)))))
	var spawn := func(i: int) -> String: return str(heights.call(i)) + ("p" if i == 2 else ("e" if i == 14 else ""))
	var middle := " ".join(PackedStringArray(Array(range(40)).map(spawn)))
	map.layout = "\n".join([row, middle, row])
	var state := BattleState.create(map.parse(), [hero] as Array[UnitData], [archer.unit] as Array[UnitData], 3, [], [archer])
	state.units[1].hp = 999  # Only whether the hero lands a hit matters.
	var battle := Battle.new(state)
	battle.start()
	var hero_turns := 0
	for action_index in 400:
		var actor := state.turn_order.current_unit_id()
		var hp := state.units[1].hp
		var action := EnemyAI.choose_next(state, actor)  # The hero walks at it and strikes when it can.
		battle.perform(action)
		if actor == 0 and state.units[1].hp < hp:
			return true
		if actor == 0 and action is BattleActions.EndTurn:
			hero_turns += 1
			if hero_turns > max_turns:
				return false
	return false


func test_kiting_stays_beatable_a_melee_hero_catches_the_skeleton_archer() -> void:
	assert_true(_hero_catches_archer(func(_i: int) -> int: return 0, 4), "on flat ground")


func test_kiting_stays_beatable_from_high_ground() -> void:
	# The archer starts on a plateau three levels up: the hero's climb costs double.
	assert_true(_hero_catches_archer(func(i: int) -> int: return clampi(i - 2, 0, 3), 6), "up a ramp")


func test_the_party_still_beats_a_ranged_heavy_team() -> void:
	# The Fortress: a tank, a support and two ranged units that keep their distance. AI-played
	# heroes at the level the tower's pace gives them on floor 27 must keep winning.
	var tower := (load("res://data/tower/tower.tres") as TowerConfig).duplicate(true) as TowerConfig
	for band in tower.bands:
		band.compositions = [load("res://data/compositions/fortress.tres")] as Array[CompositionData]
	var roster := load("res://data/progression/roster.tres") as Roster
	var levels: Array[int] = [10, 10, 10]
	var input := BalanceLab.party([roster.heroes[0], roster.heroes[1], roster.heroes[2]] as Array[HeroData], levels)
	var result := BalanceLab.run(input[0], input[1], FloorGenerator.encounter(tower, 27), 3)
	assert_true(result.win_rate() >= 0.66, "the party wins (%.2f)" % result.win_rate())
