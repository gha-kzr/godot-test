extends TestCase
## The HUD model follows the event stream and ends up where the battle state is.


func _caster(unit_name: String, initiative: int, spells: Array[SpellData]) -> UnitData:
	var data := BattleFixtures.unit(unit_name, initiative, 3, 6, 40)
	data.spells = spells
	return data


func _spells() -> Array[SpellData]:
	var poison := BattleFixtures.status("Poison", 3, 2)
	var haste := BattleFixtures.status("Haste", 2, 0, [BattleFixtures.modifier(StatModifier.Stat.MP, 2)] as Array[StatModifier], true)
	var slow := BattleFixtures.status("Slow", 2, 0, [BattleFixtures.modifier(StatModifier.Stat.AP, -2)] as Array[StatModifier])
	return [
		BattleFixtures.damage_spell(2, 1, 4, 3),
		BattleFixtures.effect_spell([BattleFixtures.apply_status(poison, EffectData.TargetFilter.ENEMIES)] as Array[EffectData], 2, 1, 4),
		BattleFixtures.effect_spell([BattleFixtures.apply_status(haste, EffectData.TargetFilter.CASTER)] as Array[EffectData], 1, 0, 0),
		BattleFixtures.effect_spell([BattleFixtures.apply_status(slow, EffectData.TargetFilter.ENEMIES)] as Array[EffectData], 2, 1, 4),
	] as Array[SpellData]


func _same(model: HudModel, state: BattleState, label: String) -> void:
	var fresh := HudModel.from_state(state)
	for id in fresh.infos:
		var got := model.infos[id]
		var want := fresh.infos[id]
		assert_eq([got.hp, got.ap, got.mp, got.max_ap, got.max_mp], [want.hp, want.ap, want.mp, want.max_ap, want.max_mp], "%s: unit %d numbers" % [label, id])
		var got_statuses: Array = got.statuses.map(func(s: StatusInfo) -> Array: return [s.display_name, s.turns_left])
		var want_statuses: Array = want.statuses.map(func(s: StatusInfo) -> Array: return [s.display_name, s.turns_left])
		assert_eq(got_statuses, want_statuses, "%s: unit %d statuses" % [label, id])
	assert_eq(model.upcoming().map(func(i: UnitInfo) -> int: return i.unit_id), fresh.upcoming().map(func(i: UnitInfo) -> int: return i.unit_id), "%s: order" % label)
	assert_eq([model.round_number, model.current_id], [fresh.round_number, fresh.current_id], "%s: round and current" % label)


func test_following_a_whole_battle_ends_where_the_state_is() -> void:
	var state := BattleFixtures.state_with("0p 0p 0 0 0 0e 0e",
			[_caster("P0", 200, _spells()), _caster("P1", 190, _spells())] as Array[UnitData],
			[_caster("E0", 100, _spells()), _caster("E1", 90, _spells())] as Array[UnitData], 5)
	var battle := Battle.new(state)
	var model := HudModel.from_state(state)
	var events := battle.start()
	for event in events:
		model.apply(event)
	_same(model, state, "start")
	var statuses_seen := 0
	for step in 120:
		if state.is_over():
			break
		var unit_id := state.current_unit().id
		var result := battle.perform(EnemyAI.choose_next(state, unit_id))
		if not result.ok():
			break
		for event in result.events:
			model.apply(event)
			if event is BattleEvents.StatusApplied:
				statuses_seen += 1
		_same(model, state, "step %d" % step)
	assert_true(statuses_seen > 0, "the battle exercised statuses")


func test_the_model_does_not_run_ahead_of_unplayed_events() -> void:
	var state := BattleFixtures.state("0p 0e")
	var model := HudModel.from_state(state)
	var hp := model.infos[1].hp
	var events: Array[BattleEvents.Event] = [BattleEvents.DamageDealt.new(1, 5, hp - 5), BattleEvents.UnitDied.new(1)]
	assert_eq(model.infos[1].hp, hp, "nothing applied yet")
	model.apply(events[0])
	assert_eq(model.infos[1].hp, hp - 5)
	assert_eq(model.upcoming().size(), 2)
	model.apply(events[1])
	assert_eq(model.infos[1].hp, 0)
	assert_eq(model.upcoming().size(), 1, "the dead leave the order")


func test_turn_events_carry_ap_and_mp_and_ticks_their_turns_left() -> void:
	var state := BattleFixtures.state("0p 0e")
	var poison := BattleFixtures.status("Poison", 3, 2)
	state.units[1].add_status(poison, 0)
	var battle := Battle.new(state)
	var events := battle.start()
	events.append_array(battle.perform(BattleActions.EndTurn.new(0)).events)
	var started: Array = events.filter(func(e: BattleEvents.Event) -> bool: return e is BattleEvents.TurnStarted)
	assert_eq([(started[0] as BattleEvents.TurnStarted).ap, (started[0] as BattleEvents.TurnStarted).mp], [6, 3])
	var ticks: Array = events.filter(func(e: BattleEvents.Event) -> bool: return e is BattleEvents.StatusTicked)
	assert_eq((ticks[0] as BattleEvents.StatusTicked).turns_left, 3)


func test_the_order_continues_after_the_acting_unit_dies() -> void:
	var state := BattleFixtures.state("0p 0p 0p 0e")  # Ids 0-2 players, 3 an enemy.
	var model := HudModel.from_state(state)
	model.apply(BattleEvents.TurnStarted.new(1, 1, 6, 3))
	model.apply(BattleEvents.UnitDied.new(1))
	var ids: Array = model.upcoming().map(func(i: UnitInfo) -> int: return i.unit_id)
	assert_eq(ids, [2, 3, 0], "the unit after the dead one heads the order")
