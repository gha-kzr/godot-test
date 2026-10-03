extends TestCase
## Free repositioning: until it casts, the acting unit may move anywhere its move segment's
## start could reach, the cost counting from there; a cast commits the position.


func _battle(layout: String, mp := 3) -> Battle:
	var state := BattleFixtures.state(layout, mp)
	var spell := BattleFixtures.damage_spell(2, 1, 6, 1)
	state.units[0].data.spells = [spell] as Array[SpellData]
	var battle := Battle.new(state)
	battle.start()  # P0 acts first.
	return battle


func test_moving_again_counts_from_the_segment_start() -> void:
	var battle := _battle("0p 0 0 0 0 0\n0 0 0 0 0 0e", 3)
	assert_true(battle.perform(BattleActions.Move.new(0, Vector2i(2, 0))).ok())
	var unit := battle.state.units[0]
	assert_eq(unit.mp, 1, "2 of 3 MP spent")
	var reach := Movement.reach(battle.state, 0)
	assert_eq(reach.origin, Vector2i(0, 0), "floods from where the turn started")
	assert_true(reach.can_reach(Vector2i(0, 1)), "a cell the start reaches")
	assert_false(reach.can_reach(Vector2i(4, 0)), "4 from the start: beyond 3 MP, though 2 from here")
	assert_true(reach.can_reach(Vector2i(0, 0)), "back to the start")
	assert_false(reach.can_reach(Vector2i(2, 0)), "not where it stands")
	var result := battle.perform(BattleActions.Move.new(0, Vector2i(3, 0)))
	assert_true(result.ok(), result.error)
	assert_eq(unit.mp, 0, "3 from the start")
	assert_eq((result.events[0] as BattleEvents.UnitMoved).path, [Vector2i(3, 0)] as Array[Vector2i], "walks from where it stood")
	assert_eq((result.events[0] as BattleEvents.UnitMoved).mp_spent, 1)


func test_moving_back_refunds_the_mp() -> void:
	var battle := _battle("0p 0 0 0\n0 0 0 0e", 3)
	battle.perform(BattleActions.Move.new(0, Vector2i(3, 0)))
	var result := battle.perform(BattleActions.Move.new(0, Vector2i(0, 0)))
	assert_true(result.ok(), result.error)
	assert_eq(battle.state.units[0].mp, 3, "all MP back")
	assert_eq((result.events[0] as BattleEvents.UnitMoved).mp_spent, -3)
	assert_eq((result.events[0] as BattleEvents.UnitMoved).path.size(), 3, "walks back")


func test_a_cast_commits_the_position() -> void:
	var battle := _battle("0p 0 0 0 0 0\n0 0 0 0 0 0e", 3)
	battle.perform(BattleActions.Move.new(0, Vector2i(2, 0)))
	assert_true(battle.perform(BattleActions.CastSpell.new(0, 0, Vector2i(5, 1))).ok())
	var reach := Movement.reach(battle.state, 0)
	assert_eq(reach.origin, Vector2i(2, 0), "the new segment starts here")
	assert_false(reach.can_reach(Vector2i(0, 0)), "2 away with 1 MP left")
	assert_true(reach.can_reach(Vector2i(3, 0)), "the MP left")


func test_a_walk_back_up_a_drop_slides() -> void:
	# Dropping two levels is allowed, climbing them isn't: no walk leads back up.
	var battle := _battle("2p 0 0\n2 0 0e", 2)
	battle.perform(BattleActions.Move.new(0, Vector2i(1, 0)))
	var result := battle.perform(BattleActions.Move.new(0, Vector2i(0, 0)))
	assert_true(result.ok(), result.error)
	assert_eq((result.events[0] as BattleEvents.UnitMoved).path, [Vector2i(0, 0)] as Array[Vector2i], "one straight slide")


func test_the_next_turn_starts_a_new_segment() -> void:
	var battle := _battle("0p 0 0 0\n0 0 0 0e", 3)
	battle.perform(BattleActions.Move.new(0, Vector2i(2, 0)))
	battle.perform(BattleActions.EndTurn.new(0))
	assert_false(battle.state.units[0].moved, "committed at turn end")


func test_the_ai_never_moves_twice_in_a_segment() -> void:
	var battle := _battle("0p 0 0 0 0 0 0 0 0 0e", 3)
	battle.state.units[0].data.spells = [] as Array[SpellData]
	var first := EnemyAI.choose_next(battle.state, 0)
	assert_true(first is BattleActions.Move, "approaches")
	battle.perform(first)
	assert_true(EnemyAI.choose_next(battle.state, 0) is BattleActions.EndTurn, "no second thoughts")


func test_clones_keep_the_segment() -> void:
	var battle := _battle("0p 0 0 0\n0 0 0 0e", 3)
	battle.perform(BattleActions.Move.new(0, Vector2i(2, 0)))
	var copy := battle.state.clone()
	assert_eq(Movement.reach(copy, 0).origin, Vector2i(0, 0))
	assert_eq(copy.units[0].move_budget(), 3)
