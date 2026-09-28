extends TestCase
## The AI values statuses: expected total effect over the remaining turns, signed by who
## benefits, minus what a refresh replaces. The AI drives unit 0 (P0), which acts first.

const CastSpell := BattleActions.CastSpell
const Filter := EffectData.TargetFilter
const MP := StatModifier.Stat.MP


func _caster(spells: Array[SpellData], mp := 0) -> UnitData:
	var data := BattleFixtures.unit("P0", 200, mp)
	data.spells = spells
	return data


func _battle(layout: String, players: Array[UnitData], enemies: Array[UnitData]) -> Battle:
	var battle := Battle.new(BattleFixtures.state_with(layout, players, enemies))
	battle.start()
	return battle


func _poison_spell(poison: StatusData, filter := Filter.ALL) -> SpellData:
	return BattleFixtures.effect_spell([BattleFixtures.apply_status(poison, filter)] as Array[EffectData], 3, 1, 3)


func test_a_pure_dot_spell_gets_cast_on_an_enemy() -> void:
	var poison := BattleFixtures.status("Poison", 3, 3)
	var battle := _battle("0p 0 0e", [_caster([_poison_spell(poison)])], [BattleFixtures.unit("E0", 100)])
	var action := EnemyAI.choose_next(battle.state, 0)
	assert_true(action is CastSpell, "casts")
	assert_eq((action as CastSpell).target, Vector2i(2, 0))


func test_hot_goes_to_the_injured_ally() -> void:
	var regen := BattleFixtures.status("Regen", 3, -4, [] as Array[StatModifier], true)
	var spell := BattleFixtures.effect_spell([BattleFixtures.apply_status(regen, Filter.ALLIES)] as Array[EffectData], 3, 1, 3)
	var battle := _battle("0p 0p 0p 0 0 0 0 0e", [_caster([spell]), BattleFixtures.unit("P1", 190), BattleFixtures.unit("P2", 180)],
			[BattleFixtures.unit("E0", 100)])
	battle.state.units[2].hp = 8  # P2 is hurt, P1 is full.
	var action := EnemyAI.choose_next(battle.state, 0)
	assert_true(action is CastSpell, "casts")
	assert_eq((action as CastSpell).target, Vector2i(2, 0), "on the injured ally")


func test_no_hot_on_full_hp_allies() -> void:
	var regen := BattleFixtures.status("Regen", 3, -4, [] as Array[StatModifier], true)
	var spell := BattleFixtures.effect_spell([BattleFixtures.apply_status(regen, Filter.ALLIES)] as Array[EffectData], 3, 1, 3)
	var battle := _battle("0p 0p 0 0 0 0 0e", [_caster([spell]), BattleFixtures.unit("P1", 190)], [BattleFixtures.unit("E0", 100)])
	assert_true(EnemyAI.choose_next(battle.state, 0) is BattleActions.EndTurn, "nothing to heal")


func test_no_recasting_a_fresh_status_but_extending_a_fading_one() -> void:
	var poison := BattleFixtures.status("Poison", 3, 3)
	var battle := _battle("0p 0e", [_caster([_poison_spell(poison)])], [BattleFixtures.unit("E0", 100)])
	var enemy := battle.state.units[1]
	enemy.add_status(poison, 0)
	assert_true(EnemyAI.choose_next(battle.state, 0) is BattleActions.EndTurn, "a full poison is already on")
	enemy.statuses[0].turns_left = 1
	assert_true(EnemyAI.choose_next(battle.state, 0) is CastSpell, "worth extending")


func test_replacing_scores_only_the_change() -> void:
	var profile := AIProfile.new()
	var before := BattleFixtures.state("0p 0e")
	var strong := BattleFixtures.status("Poison", 2, 6)
	before.units[1].add_status(strong, 0)  # 6 x 2 = 12 ahead.
	var downgraded := before.clone()
	downgraded.units[1].statuses[0] = StatusInstance.new(BattleFixtures.status("Poison", 3, 1), 0, 3)  # 1 x 3 = 3.
	assert_true(EnemyAI._status_score(before, downgraded, UnitState.Team.PLAYER, profile) < 0.0, "a downgrade scores negative")
	var refreshed := before.clone()
	assert_eq(EnemyAI._status_score(before, refreshed, UnitState.Team.PLAYER, profile), 0.0, "no change, no score")
	refreshed.units[1].statuses[0].turns_left = 3
	assert_eq(EnemyAI._status_score(before, refreshed, UnitState.Team.PLAYER, profile), 6.0 * profile.status_weight,
			"one more turn of 6 damage")


func test_slows_an_enemy_but_never_an_ally() -> void:
	var slow := BattleFixtures.status("Slow", 2, 0, [BattleFixtures.modifier(MP, -2)] as Array[StatModifier])
	var battle := _battle("0e 0p 0p", [_caster([_poison_spell(slow)]), BattleFixtures.unit("P1", 190)], [BattleFixtures.unit("E0", 100)])
	var action := EnemyAI.choose_next(battle.state, 0)
	assert_true(action is CastSpell and (action as CastSpell).target == Vector2i(0, 0), "slows the enemy")
	battle = _battle("0p 0p 0 0 0 0 0e", [_caster([_poison_spell(slow)]), BattleFixtures.unit("P1", 190)], [BattleFixtures.unit("E0", 100)])
	assert_true(EnemyAI.choose_next(battle.state, 0) is BattleActions.EndTurn, "only an ally in range: no cast")


func test_buffs_itself_with_haste() -> void:
	var haste := BattleFixtures.status("Haste", 2, 0, [BattleFixtures.modifier(MP, 2)] as Array[StatModifier], true)
	var spell := BattleFixtures.effect_spell([BattleFixtures.apply_status(haste, Filter.CASTER)] as Array[EffectData], 3, 0, 0)
	var battle := _battle("0p 0 0 0 0 0 0e", [_caster([spell])], [BattleFixtures.unit("E0", 100)])
	assert_true(EnemyAI.choose_next(battle.state, 0) is CastSpell, "a self-buff is worth casting")


func test_a_mixed_spell_outscores_its_damage_only_version() -> void:
	var strike := BattleFixtures.damage_spell(3, 1, 1, 5)
	var poison_strike := BattleFixtures.damage_spell(3, 1, 1, 5)
	poison_strike.effects.append(BattleFixtures.apply_status(BattleFixtures.status("Poison", 2, 2)))
	var battle := _battle("0p 0e", [_caster([strike, poison_strike])], [BattleFixtures.unit("E0", 100)])
	var action := EnemyAI.choose_next(battle.state, 0)
	assert_true(action is CastSpell and (action as CastSpell).spell_index == 1, "prefers the poisoned strike")


func test_status_value_accounts_for_damage_taken_and_remaining_hp() -> void:
	var profile := AIProfile.new()
	var state := BattleFixtures.state("0p 0e")
	var enemy := state.units[1]
	enemy.add_status(BattleFixtures.status("Poison", 3, 4), 0)
	assert_eq(EnemyAI._statuses_benefit(enemy, profile), -12.0, "4 x 3 turns")
	enemy.statuses[0].counting = true
	assert_eq(EnemyAI._statuses_benefit(enemy, profile), -8.0, "one turn already counted")
	enemy.hp = 5
	assert_eq(EnemyAI._statuses_benefit(enemy, profile), -5.0, "capped at the HP left")
	enemy.hp = 20
	enemy.add_status(BattleFixtures.status("Vulnerable", 2, 0,
			[BattleFixtures.modifier(StatModifier.Stat.DAMAGE_TAKEN_PERCENT, 50)] as Array[StatModifier]), 0)
	assert_eq(EnemyAI._statuses_benefit(enemy, profile), -12.0 - 10.0, "poison x150%, plus 50% x 2 turns x 10 incoming")


func test_the_ai_leaves_real_statuses_untouched() -> void:
	var poison := BattleFixtures.status("Poison", 3, 3)
	var battle := _battle("0p 0e", [_caster([_poison_spell(poison)])], [BattleFixtures.unit("E0", 100)])
	battle.state.units[1].add_status(poison, 0)
	battle.state.units[1].statuses[0].turns_left = 1
	EnemyAI.choose_next(battle.state, 0)
	assert_eq(battle.state.units[1].statuses.size(), 1)
	assert_eq(battle.state.units[1].statuses[0].turns_left, 1)


func test_status_value_follows_real_turns() -> void:
	# Poison 3 x 3 turns on E0: after E0's first turn, 2 ticks (6 damage) are still ahead.
	var profile := AIProfile.new()
	var battle := _battle("0p 0e", [_caster([] as Array[SpellData])], [BattleFixtures.unit("E0", 100)])
	var enemy := battle.state.units[1]
	enemy.add_status(BattleFixtures.status("Poison", 3, 3), 0)
	assert_eq(EnemyAI._statuses_benefit(enemy, profile), -9.0, "3 ticks ahead")
	battle.perform(BattleActions.EndTurn.new(0))  # E0's turn: tick 1.
	assert_eq(EnemyAI._statuses_benefit(enemy, profile), -6.0, "during E0's turn, 2 ahead")
	battle.perform(BattleActions.EndTurn.new(1))  # Back to P0.
	assert_eq(EnemyAI._statuses_benefit(enemy, profile), -6.0, "still 2 ahead on P0's turn")
	battle.perform(BattleActions.EndTurn.new(0))
	battle.perform(BattleActions.EndTurn.new(1))
	assert_eq(EnemyAI._statuses_benefit(enemy, profile), -3.0, "1 ahead")
