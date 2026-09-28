extends TestCase
## Statuses over turns: ticks at the carrier's turn start, countdown and expiry at its turn
## end, deaths from ticks, modifiers on refill. P0 acts first, then E0, E1, … in order.

const EndTurn := BattleActions.EndTurn
const MP := StatModifier.Stat.MP
const AP := StatModifier.Stat.AP


func _battle(layout := "0p 0e", enemy_count := 1, enemy_hp := 20) -> Battle:
	var enemies: Array[UnitData] = []
	for i in enemy_count:
		enemies.append(BattleFixtures.unit("E%d" % i, 100 - i, 3, 6, enemy_hp))
	var players: Array[UnitData] = [BattleFixtures.unit("P0", 200)]
	var battle := Battle.new(BattleFixtures.state_with(layout, players, enemies))
	battle.start()
	return battle


func _end(battle: Battle) -> Array[BattleEvents.Event]:
	var result := battle.perform(EndTurn.new(battle.state.current_unit().id))
	assert_true(result.ok(), result.error)
	return result.events


func _names(events: Array[BattleEvents.Event]) -> Array[String]:
	var names: Array[String] = []
	for event in events:
		var text := "?"
		if event is BattleEvents.TurnStarted: text = "start %d"
		elif event is BattleEvents.TurnEnded: text = "end %d"
		elif event is BattleEvents.StatusTicked: text = "tick %d"
		elif event is BattleEvents.DamageDealt: text = "hit %d"
		elif event is BattleEvents.Healed: text = "heal %d"
		elif event is BattleEvents.StatusExpired: text = "expire %d"
		elif event is BattleEvents.UnitDied: text = "died %d"
		elif event is BattleEvents.BattleEnded:
			names.append("battle over")
			continue
		names.append(text % event.subject_id())
	return names


func test_dot_hits_at_the_carriers_turn_start() -> void:
	var battle := _battle()
	battle.state.units[1].add_status(BattleFixtures.status("Poison", 2, 3), 0)
	var events := _end(battle)
	assert_eq(_names(events), ["end 0", "start 1", "tick 1", "hit 1"] as Array[String])
	assert_eq(battle.state.units[1].hp, 17)


func test_n_turns_means_n_ticks_then_expiry_at_its_last_turn_end() -> void:
	var battle := _battle()
	var poison := BattleFixtures.status("Poison", 2, 3)
	battle.state.units[1].add_status(poison, 0)
	_end(battle)  # E0's first turn: tick 1.
	assert_eq(battle.state.units[1].find_status(poison).turns_left, 2, "counts down at turn end")
	_end(battle)  # E0 ends turn 1; P0's turn.
	assert_eq(battle.state.units[1].find_status(poison).turns_left, 1)
	var events := _end(battle)  # E0's second turn: tick 2.
	assert_eq(_names(events), ["end 0", "start 1", "tick 1", "hit 1"] as Array[String])
	assert_true(battle.state.units[1].find_status(poison) != null, "still visible during its last turn")
	events = _end(battle)  # E0 ends its last turn.
	assert_eq(_names(events), ["expire 1", "end 1", "start 0"] as Array[String])
	assert_eq(battle.state.units[1].statuses.size(), 0)
	_end(battle)
	assert_eq(battle.state.units[1].hp, 14, "exactly two ticks")


func test_a_self_buff_does_not_lose_the_turn_it_was_cast_in() -> void:
	var battle := _battle()
	var p0 := battle.state.units[0]
	p0.add_status(BattleFixtures.status("Haste", 1, 0, [BattleFixtures.modifier(MP, 2)] as Array[StatModifier], true), 0)
	assert_eq(p0.mp, 5, "+2 MP right away")
	_end(battle)  # P0's turn ends: not counted, it started without the status.
	assert_eq(p0.statuses.size(), 1)
	_end(battle)  # E0's turn ends → P0's turn starts.
	assert_eq(p0.mp, 5, "refilled with +2")
	var events := _end(battle)
	assert_eq(_names(events).slice(0, 2), ["expire 0", "end 0"] as Array[String], "gone after the next turn")


func test_modifiers_apply_on_refills_during_the_duration_only() -> void:
	var battle := _battle()
	var e0 := battle.state.units[1]
	e0.add_status(BattleFixtures.status("Slow", 1, 0, [BattleFixtures.modifier(AP, -2)] as Array[StatModifier]), 0)
	_end(battle)
	assert_eq(e0.ap, 4, "slowed turn")
	_end(battle)
	_end(battle)
	assert_eq(e0.ap, 6, "back to normal")


func test_hot_heals_at_turn_start() -> void:
	var battle := _battle()
	var e0 := battle.state.units[1]
	e0.hp = 10
	e0.add_status(BattleFixtures.status("Regen", 2, -4, [] as Array[StatModifier], true), 1)
	var events := _end(battle)
	assert_eq(_names(events), ["end 0", "start 1", "tick 1", "heal 1"] as Array[String])
	assert_eq(e0.hp, 14)


func test_a_dot_kill_skips_to_the_next_unit() -> void:
	var battle := _battle("0p 0e 0e", 2)
	battle.state.units[1].hp = 2
	battle.state.units[1].add_status(BattleFixtures.status("Poison", 2, 3), 0)
	var events := _end(battle)
	assert_eq(_names(events), ["end 0", "start 1", "tick 1", "hit 1", "died 1", "start 2"] as Array[String],
			"no TurnEnded for the unit that died")
	assert_eq(battle.state.current_unit().id, 2)
	assert_eq(battle.state.current_unit().ap, 6, "the next unit refilled")


func test_several_units_dying_to_dots_in_a_row() -> void:
	var battle := _battle("0p 0e 0e 0e", 3)
	for id in [1, 2]:
		battle.state.units[id].hp = 1
		battle.state.units[id].add_status(BattleFixtures.status("Poison", 2, 3), 0)
	var events := _end(battle)
	assert_eq(_names(events), ["end 0", "start 1", "tick 1", "hit 1", "died 1",
			"start 2", "tick 2", "hit 2", "died 2", "start 3"] as Array[String])
	assert_eq(battle.state.turn_order.upcoming(), [3, 0] as Array[int])


func test_the_battle_ends_on_a_dot_kill() -> void:
	var battle := _battle()
	battle.state.units[1].hp = 2
	battle.state.units[1].add_status(BattleFixtures.status("Poison", 2, 3), 0)
	var events := _end(battle)
	assert_eq(_names(events), ["end 0", "start 1", "tick 1", "hit 1", "died 1", "battle over"] as Array[String])
	assert_eq(battle.state.outcome(), BattleState.Outcome.PLAYER_WON)


func test_a_status_keeps_ticking_after_its_caster_dies() -> void:
	var battle := _battle("0p 0e 0e", 2)
	battle.state.units[1].add_status(BattleFixtures.status("Poison", 3, 2), 2)  # Cast by E1…
	battle.state.units[2].hp = 0  # … who then dies.
	battle.state.turn_order.remove(2)
	_end(battle)
	assert_eq(battle.state.units[1].hp, 18, "still ticks")


func test_ticks_are_seeded() -> void:
	var amounts: Array[int] = []
	for i in 2:
		var battle := _battle()
		var poison := BattleFixtures.status("Poison", 2, 1)
		(poison.tick_effects[0] as DamageEffect).max_amount = 10
		battle.state.units[1].add_status(poison, 0)
		_end(battle)
		amounts.append(20 - battle.state.units[1].hp)
	assert_eq(amounts[0], amounts[1])


func test_subject_ids() -> void:
	var poison := BattleFixtures.status("Poison", 2, 1)
	assert_eq(BattleEvents.StatusTicked.new(3, poison).subject_id(), 3)
	assert_eq(BattleEvents.StatusExpired.new(4, poison).subject_id(), 4)
	assert_eq(BattleEvents.SpellCast.new(5, BattleFixtures.damage_spell(), Vector2i.ZERO, [] as Array[Vector2i], 3).subject_id(), 5)
	assert_eq(BattleEvents.BattleEnded.new(BattleState.Outcome.DRAW).subject_id(), -1)
