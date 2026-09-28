extends TestCase
## The AI drives unit 0 (P0, acts first) unless a test says otherwise; its opponents are the E units.

const Move := BattleActions.Move
const CastSpell := BattleActions.CastSpell
const EndTurn := BattleActions.EndTurn


func _fighter(unit_name: String, initiative: int, spells: Array[SpellData], max_hp := 20, mp := 3) -> UnitData:
	var data := BattleFixtures.unit(unit_name, initiative, mp, 6, max_hp)
	data.spells = spells
	return data


func _melee() -> Array[SpellData]:
	return [BattleFixtures.damage_spell()] as Array[SpellData]


func _battle(layout: String, players: Array[UnitData], enemies: Array[UnitData], rng_seed := 1) -> Battle:
	var battle := Battle.new(BattleFixtures.state_with(layout, players, enemies, rng_seed))
	battle.start()
	return battle


# --- Choices ---

func test_kills_a_low_hp_target_rather_than_hurting_a_healthy_one() -> void:
	var ranged := [BattleFixtures.damage_spell(3, 1, 3, 5)] as Array[SpellData]
	var battle := _battle("0p 0e 0 0e", [_fighter("P0", 200, ranged)],
			[_fighter("E0", 100, _melee()), _fighter("E1", 90, _melee(), 3)])
	var action := EnemyAI.choose_next(battle.state, 0)
	assert_true(action is CastSpell, "casts")
	assert_eq((action as CastSpell).target, Vector2i(3, 0), "targets the 3-HP enemy")


func test_walks_toward_the_enemy_when_nothing_is_in_range() -> void:
	var battle := _battle("0p 0 0 0 0 0 0 0e", [_fighter("P0", 200, _melee())], [_fighter("E0", 100, _melee())])
	var action := EnemyAI.choose_next(battle.state, 0)
	assert_true(action is Move, "moves")
	assert_eq((action as Move).destination, Vector2i(3, 0), "as far as its 3 MP allow")


func test_walks_around_a_wall_instead_of_into_a_dead_end() -> void:
	# The pocket above P0 is closer as the crow flies, but a dead end.
	var layout := """
		0 0 0e 0 0
		0 # #  # 0
		0 # 0  # 0
		0 # 0p # 0
		0 0 0  0 0
	"""
	var battle := _battle(layout, [_fighter("P0", 200, _melee())], [_fighter("E0", 100, _melee())])
	var action := EnemyAI.choose_next(battle.state, 0)
	assert_true(action is Move, "moves")
	assert_true((action as Move).destination in [Vector2i(0, 4), Vector2i(4, 4)],
			"heads around the wall, got %s" % (action as Move).destination)


func test_moves_into_range_then_casts() -> void:
	var battle := _battle("0p 0 0 0e", [_fighter("P0", 200, _melee())], [_fighter("E0", 100, _melee())])
	var first := EnemyAI.choose_next(battle.state, 0)
	assert_true(first is Move, "moves first")
	assert_eq((first as Move).destination, Vector2i(2, 0), "next to the enemy")
	assert_true(battle.perform(first).ok())
	var second := EnemyAI.choose_next(battle.state, 0)
	assert_true(second is CastSpell, "then casts")
	assert_eq((second as CastSpell).target, Vector2i(3, 0))


func test_avoids_hitting_an_ally_with_an_area() -> void:
	# Aiming at E0 would also hit P1; aiming one cell past it hits E0 alone.
	var blast := [BattleFixtures.damage_spell(3, 2, 3, 5, AreaShape.Kind.CIRCLE, 1)] as Array[SpellData]
	var battle := _battle("0p 0p 0e 0 0", [_fighter("P0", 200, blast, 20, 0), _fighter("P1", 190, _melee())],
			[_fighter("E0", 100, _melee())])
	var action := EnemyAI.choose_next(battle.state, 0)
	assert_true(action is CastSpell, "casts")
	assert_eq((action as CastSpell).target, Vector2i(3, 0))


func test_ends_its_turn_when_out_of_ap_next_to_the_enemy() -> void:
	var battle := _battle("0p 0e", [_fighter("P0", 200, _melee())], [_fighter("E0", 100, _melee())])
	battle.state.units[0].ap = 0
	assert_true(EnemyAI.choose_next(battle.state, 0) is EndTurn)


func test_ignores_free_spells() -> void:
	var free := [BattleFixtures.damage_spell(0)] as Array[SpellData]
	var battle := _battle("0p 0e", [_fighter("P0", 200, free)], [_fighter("E0", 100, _melee())])
	assert_true(EnemyAI.choose_next(battle.state, 0) is EndTurn, "a free spell could be cast forever")


func test_does_not_see_future_rolls() -> void:
	# A steady 5 vs. a 1-10 roll, with AP for only one: an AI peeking at the real RNG would
	# take the roll exactly when it's high, so its choice would change with the seed.
	var steady := BattleFixtures.damage_spell(4, 1, 1, 5)
	var gamble := BattleFixtures.damage_spell(4, 1, 1, 0)
	(gamble.effects[0] as DamageEffect).min_amount = 1
	(gamble.effects[0] as DamageEffect).max_amount = 10
	var choices := []
	for rng_seed in range(1, 21):
		var battle := _battle("0p 0e", [_fighter("P0", 200, [steady, gamble] as Array[SpellData])],
				[_fighter("E0", 100, _melee())], rng_seed)
		var action := EnemyAI.choose_next(battle.state, 0)
		assert_true(action is CastSpell, "casts")
		choices.append((action as CastSpell).spell_index)
	for choice in choices:
		assert_eq(choice, choices[0], "same choice whatever the real RNG state")


func test_decides_on_the_average_roll() -> void:
	# A steady 6 beats a 1-10 roll (average 5.5) every time, whatever the dice would say.
	var steady := BattleFixtures.damage_spell(4, 1, 1, 6)
	var gamble := BattleFixtures.damage_spell(4, 1, 1, 0)
	(gamble.effects[0] as DamageEffect).min_amount = 1
	(gamble.effects[0] as DamageEffect).max_amount = 10
	for rng_seed in range(1, 21):
		var battle := _battle("0p 0e", [_fighter("P0", 200, [gamble, steady] as Array[SpellData])],
				[_fighter("E0", 100, _melee())], rng_seed)
		battle.state.turn_order.round_number = rng_seed  # Varies any AI-side dice too.
		var action := EnemyAI.choose_next(battle.state, 0)
		assert_true(action is CastSpell and (action as CastSpell).spell_index == 1, "seed %d: picks the steady spell" % rng_seed)


func test_counts_a_kill_only_if_the_average_roll_kills() -> void:
	# 5-8 damage (average 6.5, rounded down to 6). The 7-HP enemy is scanned second, so
	# the AI only picks it over the healthy one if it counts the kill.
	var chancy := BattleFixtures.damage_spell(4, 1, 1, 0)
	(chancy.effects[0] as DamageEffect).min_amount = 5
	(chancy.effects[0] as DamageEffect).max_amount = 8
	for rng_seed in range(1, 11):
		var battle := _battle("0e 0p 0e", [_fighter("P0", 200, [chancy] as Array[SpellData])],
				[_fighter("E0", 100, _melee(), 20), _fighter("E1", 90, _melee(), 7)], rng_seed)
		var action := EnemyAI.choose_next(battle.state, 0) as CastSpell
		assert_eq(action.target, Vector2i(0, 0), "seed %d: 7 HP is not an expected kill" % rng_seed)
		battle.state.units[2].hp = 6
		action = EnemyAI.choose_next(battle.state, 0) as CastSpell
		assert_eq(action.target, Vector2i(2, 0), "seed %d: 6 HP is" % rng_seed)


func test_kills_rather_than_heals_with_the_default_profile() -> void:
	# Healing the ally is worth 10; killing the 4-HP enemy is worth 4 + 10.
	var mend := SpellData.new()
	mend.display_name = "Mend"
	mend.ap_cost = 4
	mend.min_range = 0
	mend.max_range = 3
	mend.needs_line_of_sight = false
	mend.area = AreaShape.new()
	var heal := HealEffect.new()
	heal.min_amount = 10
	heal.max_amount = 10
	mend.effects = [heal] as Array[EffectData]
	var poke := BattleFixtures.damage_spell(4, 1, 1, 4)
	var battle := _battle("0e 0p 0p", [_fighter("P0", 200, [mend, poke] as Array[SpellData]), _fighter("P1", 190, _melee())],
			[_fighter("E0", 100, _melee(), 4)])
	battle.state.units[1].hp = 10
	var action := EnemyAI.choose_next(battle.state, 0)
	assert_true(action is CastSpell and (action as CastSpell).spell_index == 1, "kills the enemy")

	# A profile that values healing highly heals instead.
	var healer := AIProfile.new()
	healer.heal_weight = 2.0
	action = EnemyAI.choose_next(battle.state, 0, healer)
	assert_true(action is CastSpell and (action as CastSpell).spell_index == 0, "heals the ally")


func test_heals_an_injured_ally_when_no_enemy_is_in_range() -> void:
	var mend := SpellData.new()
	mend.display_name = "Mend"
	mend.ap_cost = 3
	mend.min_range = 0
	mend.max_range = 3
	mend.needs_line_of_sight = false
	mend.area = AreaShape.new()
	var heal := HealEffect.new()
	heal.min_amount = 5
	heal.max_amount = 5
	mend.effects = [heal] as Array[EffectData]
	var battle := _battle("0p 0p 0 0 0 0 0 0 0e", [_fighter("P0", 200, [mend] as Array[SpellData], 20, 0), _fighter("P1", 190, _melee())],
			[_fighter("E0", 100, _melee())])
	battle.state.units[1].hp = 12
	var action := EnemyAI.choose_next(battle.state, 0)
	assert_true(action is CastSpell, "casts")
	assert_eq((action as CastSpell).target, Vector2i(1, 0), "on the injured ally")


func test_never_casts_when_every_option_hurts_its_own_side() -> void:
	# The only unit in range is an ally.
	var battle := _battle("0p 0p 0 0 0 0e", [_fighter("P0", 200, _melee(), 20, 0), _fighter("P1", 190, _melee())],
			[_fighter("E0", 100, _melee())])
	assert_true(EnemyAI.choose_next(battle.state, 0) is EndTurn)


func test_casts_from_where_it_stands_when_it_can() -> void:
	# In range already: moving would reach the same casts for more MP.
	var ranged := [BattleFixtures.damage_spell(3, 1, 3, 5)] as Array[SpellData]
	var battle := _battle("0p 0 0e 0", [_fighter("P0", 200, ranged)], [_fighter("E0", 100, _melee())])
	assert_true(EnemyAI.choose_next(battle.state, 0) is CastSpell, "casts without moving")


func test_rejects_a_unit_whose_turn_it_is_not() -> void:
	var battle := _battle("0p 0e", [_fighter("P0", 200, _melee())], [_fighter("E0", 100, _melee())])
	expect_error("not unit 1's turn")
	assert_true(EnemyAI.choose_next(battle.state, 1) is EndTurn)


func test_does_not_change_the_state() -> void:
	var battle := _battle("0p 0 0 0e 0e", [_fighter("P0", 200, _melee())],
			[_fighter("E0", 100, _melee()), _fighter("E1", 90, _melee())])
	var before := battle.state.clone()
	var rng_state := battle.state.rng.state
	EnemyAI.choose_next(battle.state, 0)
	for unit in battle.state.units:
		var original := before.units[unit.id]
		assert_eq([unit.cell, unit.hp, unit.ap, unit.mp], [original.cell, original.hp, original.ap, original.mp],
				"unit %d unchanged" % unit.id)
	assert_eq(battle.state.turn_order.current_unit_id(), before.turn_order.current_unit_id())
	assert_eq(battle.state.turn_order.round_number, before.turn_order.round_number)
	assert_eq(battle.state.rng.state, rng_state, "the real dice are untouched")
	assert_false(battle.state.use_average_rolls, "average rolls stay in the simulation")


# --- Full battles ---

func test_ai_vs_ai_battles_only_use_valid_actions_and_end() -> void:
	var layout := """
		0p 0p 0  1 1  0
		0  #  0  2 1  0
		0  0  .  1 0  0
		0  1  1  0 #  0
		0  0  0  0 0e 0e
	"""
	var slash := BattleFixtures.damage_spell(3, 1, 1, 6)
	var bolt := BattleFixtures.damage_spell(4, 2, 5, 4, AreaShape.Kind.SINGLE, 0, true)
	bolt.height_extends_range = true
	var blast := BattleFixtures.damage_spell(5, 2, 3, 3, AreaShape.Kind.CIRCLE, 1)
	var kit := [slash, bolt, blast] as Array[SpellData]
	for rng_seed in [1, 2, 3]:
		var battle := _battle(layout, [_fighter("P0", 200, kit), _fighter("P1", 150, kit)],
				[_fighter("E0", 180, kit), _fighter("E1", 120, kit)], rng_seed)
		var actions := 0
		while not battle.state.is_over() and actions < 500:
			var actor := battle.state.turn_order.current_unit_id()
			var result := battle.perform(EnemyAI.choose_next(battle.state, actor))
			if not result.ok():
				assert_true(false, "seed %d: invalid action: %s" % [rng_seed, result.error])
				break
			actions += 1
		assert_true(battle.state.is_over(), "seed %d: battle ends within 500 actions" % rng_seed)
