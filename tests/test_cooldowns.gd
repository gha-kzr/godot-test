extends TestCase
## Spell cooldowns: after a cast the spell waits `cooldown` of the caster's turns.


func _battle(cooldown: int) -> Battle:
	var state := BattleFixtures.state("0p 0e", 3)
	var spell := BattleFixtures.damage_spell(1, 1, 1, 1)
	spell.cooldown = cooldown
	state.units[0].data.spells = [spell] as Array[SpellData]
	state.units[1].data.max_hp = 99
	state.units[1].hp = 99
	var battle := Battle.new(state)
	battle.start()
	return battle


func _cast(battle: Battle) -> Battle.Result:
	return battle.perform(BattleActions.CastSpell.new(0, 0, Vector2i(1, 0)))


func _next_turn(battle: Battle) -> void:
	battle.perform(BattleActions.EndTurn.new(0))  # P0's turn ends; E0's starts.
	battle.perform(BattleActions.EndTurn.new(1))  # Back to P0.


func test_no_cooldown_casts_as_often_as_ap_allows() -> void:
	var battle := _battle(0)
	for i in 3:
		assert_true(_cast(battle).ok(), "cast %d" % i)


func test_cooldown_one_is_once_per_turn() -> void:
	var battle := _battle(1)
	assert_true(_cast(battle).ok())
	var again := _cast(battle)
	assert_false(again.ok(), "same turn")
	assert_true(again.error.contains("cooldown"), again.error)
	assert_false(BattleActions.CastSpell.can_afford(battle.state.units[0], 0), "the UI agrees")
	_next_turn(battle)
	assert_true(_cast(battle).ok(), "next turn")


func test_cooldown_two_skips_a_turn() -> void:
	var battle := _battle(2)
	assert_true(_cast(battle).ok())
	_next_turn(battle)
	assert_eq(battle.state.units[0].cooldown_left(battle.state.units[0].data.spells[0]), 1)
	assert_false(_cast(battle).ok(), "the turn after")
	_next_turn(battle)
	assert_true(_cast(battle).ok(), "two turns after")


func test_the_ai_skips_a_spell_on_cooldown() -> void:
	var battle := _battle(1)
	_cast(battle)
	assert_true(EnemyAI.choose_next(battle.state, 0) is BattleActions.EndTurn)


func test_clones_keep_cooldowns() -> void:
	var battle := _battle(2)
	_cast(battle)
	var copy := battle.state.clone()
	assert_false(BattleActions.CastSpell.can_afford(copy.units[0], 0))


func test_the_hud_model_follows_cooldowns() -> void:
	var battle := _battle(2)
	var model := HudModel.from_state(battle.state)
	for event in _cast(battle).events:
		model.apply(event)
	assert_eq(model.infos[0].cooldowns, [2] as Array[int], "set by the cast")
	battle.perform(BattleActions.EndTurn.new(0))
	var events := battle.perform(BattleActions.EndTurn.new(1)).events
	for event in events:
		model.apply(event)
	assert_eq(model.infos[0].cooldowns, [1] as Array[int], "one turn down")
	assert_eq(HudModel.from_state(battle.state).infos[0].cooldowns, [1] as Array[int], "matches the state")


func test_the_description_names_the_cooldown() -> void:
	var spell := BattleFixtures.damage_spell()
	spell.cooldown = 3
	assert_true("Every 3 turns" in SpellBar.detail_lines(spell))
	spell.cooldown = 1
	assert_true("Once per turn" in SpellBar.detail_lines(spell))
