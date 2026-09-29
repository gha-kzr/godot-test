extends TestCase
## Battle rules the run loop needs: starting HP and sudden death.


func _state(player_hp: Array = []) -> BattleState:
	var map := MapData.new()
	map.layout = "0p 0p 0e"
	return BattleState.create(map.parse(), [BattleFixtures.unit("P0", 200, 3, 6, 40), BattleFixtures.unit("P1", 190, 3, 6, 40)] as Array[UnitData],
			[BattleFixtures.unit("E0", 100, 3, 6, 40)] as Array[UnitData], 1, [], [], player_hp)


func test_heroes_start_with_their_carried_hp() -> void:
	var state := _state([12, -1])
	assert_eq(state.units[0].hp, 12)
	assert_eq(state.units[1].hp, 40, "-1: full")
	assert_eq(state.units[2].hp, 40, "enemies untouched")
	var clamped := _state([500, 0])
	assert_eq(clamped.units[0].hp, 40, "never above max")
	assert_eq(clamped.units[1].hp, 1, "never dead at the start")


func test_sudden_death_hits_only_the_party_from_its_round() -> void:
	var battle := Battle.new(_state())
	battle.sudden_death_round = 2
	battle.sudden_death_percent = 10
	battle.start()
	for id in 3:
		battle.perform(BattleActions.EndTurn.new(battle.state.current_unit().id))
	assert_eq(battle.state.units[0].hp, 36, "round 2: P0 lost 10% of 40")
	assert_eq(battle.state.units[2].hp, 40, "enemies never")
	assert_true(battle.is_sudden_death())


func test_sudden_death_can_end_the_battle() -> void:
	var battle := Battle.new(_state([1, 1]))
	battle.sudden_death_round = 1
	var events := battle.start()
	assert_true(events.any(func(e: BattleEvents.Event) -> bool: return e is BattleEvents.UnitDied), "P0 dies at its turn start")
	var result := battle.perform(BattleActions.EndTurn.new(battle.state.current_unit().id)) if not battle.state.is_over() else null
	assert_eq(battle.state.outcome(), BattleState.Outcome.ENEMY_WON)
	assert_true(result == null or result.ok())


func test_sudden_death_is_off_by_default() -> void:
	var battle := Battle.new(_state())
	battle.start()
	assert_false(battle.is_sudden_death())
