extends TestCase
## Movement spells (MoveEffect): teleport, jump, charge, push, pull and the Backslash retreat.


static func _spell(kind: MoveEffect.Kind, min_range: int, max_range: int, distance := 2,
		filter := EffectData.TargetFilter.ENEMIES, damage := 0) -> SpellData:
	var spell := BattleFixtures.damage_spell(2, min_range, max_range, damage)
	spell.display_name = "Move"
	var effect := MoveEffect.new()
	effect.kind = kind
	effect.distance = distance
	effect.target_filter = filter
	var effects: Array[EffectData] = []
	if damage > 0:
		effects.append(spell.effects[0])
	if kind == MoveEffect.Kind.RETREAT:
		effects.append(effect)  # Backslash: the hit, then the leap back.
	else:
		effects.push_front(effect)
	spell.effects = effects
	return spell


## P0 casting `spell` on `layout`; returns the battle after the cast (or null if refused).
func _cast(layout: String, spell: SpellData, target: Vector2i) -> Battle:
	var state := BattleFixtures.state(layout, 3)
	state.units[0].data.spells = [spell] as Array[SpellData]
	for unit in state.units:
		unit.hp = 50
	var battle := Battle.new(state)
	battle.start()
	var result := battle.perform(BattleActions.CastSpell.new(0, 0, target))
	if not result.ok():
		return null
	_last_events = result.events
	return battle


var _last_events: Array[BattleEvents.Event] = []


func _displaced() -> BattleEvents.UnitDisplaced:
	for event in _last_events:
		if event is BattleEvents.UnitDisplaced:
			return event
	return null


func test_teleport_to_any_free_cell_in_range() -> void:
	var blink := _spell(MoveEffect.Kind.TELEPORT, 1, 4, 0, EffectData.TargetFilter.CASTER)
	var battle := _cast("0p # 2 0\n0 0 0 0e", blink, Vector2i(2, 0))
	assert_true(battle != null, "over the obstacle, up two levels")
	assert_eq(battle.state.units[0].cell, Vector2i(2, 0))
	assert_eq(_displaced().path, [Vector2i(2, 0)] as Array[Vector2i])
	assert_eq(_displaced().kind, MoveEffect.Kind.TELEPORT)
	assert_true(_cast("0p # 2 0\n0 0 0 0e", blink, Vector2i(3, 1)) == null, "an occupied cell")
	assert_true(_cast("0p # 2 0\n0 0 0 0e", blink, Vector2i(1, 0)) == null, "an obstacle")


func test_teleport_targets_only_free_cells() -> void:
	var state := BattleFixtures.state("0p 0 0e", 3)
	var blink := _spell(MoveEffect.Kind.TELEPORT, 1, 2, 0, EffectData.TargetFilter.CASTER)
	assert_eq(Targeting.targetable_cells(state, 0, blink), [Vector2i(1, 0)] as Array[Vector2i])


func test_jump_climbs_two_levels_but_not_three() -> void:
	var jump := _spell(MoveEffect.Kind.JUMP, 1, 3, 0, EffectData.TargetFilter.CASTER)
	assert_true(_cast("0p 2 3 0\n0 0 0 0e", jump, Vector2i(1, 0)) != null, "two levels")
	assert_true(_cast("0p 2 3 0\n0 0 0 0e", jump, Vector2i(2, 0)) == null, "three levels")
	assert_true(_cast("3p . 0 0\n0 0 0 0e", jump, Vector2i(2, 0)) != null, "over a hole, down three")


func test_charge_stops_next_to_the_target_then_hits() -> void:
	var charge := _spell(MoveEffect.Kind.CHARGE, 1, 4, 0, EffectData.TargetFilter.CASTER, 5)
	var battle := _cast("0p 0 0 0e", charge, Vector2i(3, 0))
	assert_true(battle != null)
	assert_eq(battle.state.units[0].cell, Vector2i(2, 0))
	assert_eq(_displaced().path, [Vector2i(1, 0), Vector2i(2, 0)] as Array[Vector2i])
	assert_eq(battle.state.units[1].hp, 45, "the hit lands after the dash")


func test_charge_needs_a_straight_clear_line() -> void:
	var charge := _spell(MoveEffect.Kind.CHARGE, 1, 4, 0, EffectData.TargetFilter.CASTER, 5)
	assert_true(_cast("0p # 0 0e", charge, Vector2i(3, 0)) == null, "an obstacle on the way")
	assert_true(_cast("0p 2 0 0e", charge, Vector2i(3, 0)) == null, "a climb too high on the way")
	assert_true(_cast("0p 0 0\n0 0 0e", charge, Vector2i(2, 1)) == null, "not in line")
	assert_true(_cast("0p 0 0 0\n0 0 0 0e", charge, Vector2i(2, 0)) == null, "nobody there")
	assert_true(_cast("0p 0e 0 0", charge, Vector2i(1, 0)) != null, "adjacent: just the hit")


func test_push_slides_away_and_stops_at_the_first_blocked_cell() -> void:
	var push := _spell(MoveEffect.Kind.PUSH, 1, 1, 3)
	var battle := _cast("0p 0e 0 0 0", push, Vector2i(1, 0))
	assert_eq(battle.state.units[1].cell, Vector2i(4, 0), "three cells")
	assert_eq(_displaced().path, [Vector2i(2, 0), Vector2i(3, 0), Vector2i(4, 0)] as Array[Vector2i])
	battle = _cast("0p 0e 0 #", push, Vector2i(1, 0))
	assert_eq(battle.state.units[1].cell, Vector2i(2, 0), "an obstacle")
	battle = _cast("0p 0e 0 .", push, Vector2i(1, 0))
	assert_eq(battle.state.units[1].cell, Vector2i(2, 0), "never into a hole")
	battle = _cast("0p 0e 0", push, Vector2i(1, 0))
	assert_eq(battle.state.units[1].cell, Vector2i(2, 0), "the edge")
	battle = _cast("0p 0e 1 2", push, Vector2i(1, 0))
	assert_eq(battle.state.units[1].cell, Vector2i(3, 0), "climbs one level at a time")
	battle = _cast("0p 0e 2", push, Vector2i(1, 0))
	assert_eq(battle.state.units[1].cell, Vector2i(1, 0), "not two")
	assert_true(_displaced() == null, "no move, no event")
	assert_eq(battle.state.units[1].hp, 50, "no collision damage")


func test_push_stops_against_another_unit() -> void:
	var push := _spell(MoveEffect.Kind.PUSH, 1, 1, 3)
	var battle := _cast("0p 0e 0 0e", push, Vector2i(1, 0))
	assert_eq(battle.state.units[1].cell, Vector2i(2, 0))


func test_pull_slides_toward_the_caster_and_stops_next_to_it() -> void:
	var pull := _spell(MoveEffect.Kind.PULL, 1, 6, 5, EffectData.TargetFilter.ENEMIES, 2)
	var battle := _cast("0p 0 0 0 0e", pull, Vector2i(4, 0))
	assert_eq(battle.state.units[1].cell, Vector2i(1, 0))
	assert_eq(battle.state.units[1].hp, 48, "the hit")


func test_retreat_leaps_back_after_the_hit() -> void:
	var backslash := _spell(MoveEffect.Kind.RETREAT, 1, 1, 3, EffectData.TargetFilter.CASTER, 4)
	var battle := _cast("0 0e 0p 0 0 0", backslash, Vector2i(1, 0))
	assert_eq(battle.state.units[1].hp, 46)
	assert_eq(battle.state.units[0].cell, Vector2i(5, 0), "three cells back")
	assert_eq(_displaced().kind, MoveEffect.Kind.RETREAT)
	battle = _cast("0 0e 0p 0 # 0", backslash, Vector2i(1, 0))
	assert_eq(battle.state.units[0].cell, Vector2i(3, 0), "stops before an obstacle")
	battle = _cast("0 0e 0p 2 3 0", backslash, Vector2i(1, 0))
	assert_eq(battle.state.units[0].cell, Vector2i(3, 0), "up two levels, not three")


func test_push_moves_every_target_in_the_area() -> void:
	var repulse := _spell(MoveEffect.Kind.PUSH, 0, 0, 2, EffectData.TargetFilter.ALL)
	repulse.area.kind = AreaShape.Kind.CIRCLE
	repulse.area.size = 1
	var battle := _cast("0 0 0\n0 0 0\n0 0e 0\n0 0p 0\n0 0p 0\n0 0 0", repulse, Vector2i(1, 3))
	assert_true(battle != null)
	assert_eq(battle.state.units[0].cell, Vector2i(1, 3), "the caster stays")
	assert_eq(battle.state.units[2].cell, Vector2i(1, 0), "the enemy above, pushed up")
	assert_eq(battle.state.units[1].cell, Vector2i(1, 5), "the ally below stopped at the edge")


func test_the_damage_preview_ignores_the_move() -> void:
	var state := BattleFixtures.state("0p 0 0 0e", 3)
	state.units[0].data.spells = [_spell(MoveEffect.Kind.CHARGE, 1, 4, 0, EffectData.TargetFilter.CASTER, 5)] as Array[SpellData]
	Battle.new(state).start()
	var entries := DamagePreview.for_cast(state, 0, 0, Vector2i(3, 0))
	assert_eq(entries.size(), 1)
	assert_eq(entries[0].max_damage, 5)
	assert_eq(state.units[0].cell, Vector2i(0, 0), "the real state is untouched")


func test_a_move_spell_commits_the_position() -> void:
	var blink := _spell(MoveEffect.Kind.TELEPORT, 1, 4, 0, EffectData.TargetFilter.CASTER)
	var state := BattleFixtures.state("0p 0 0 0 0\n0 0 0 0 0e", 3)
	state.units[0].data.spells = [blink] as Array[SpellData]
	var battle := Battle.new(state)
	battle.start()
	battle.perform(BattleActions.Move.new(0, Vector2i(1, 0)))
	assert_true(battle.perform(BattleActions.CastSpell.new(0, 0, Vector2i(4, 0))).ok())
	var reach := Movement.reach(battle.state, 0)
	assert_eq(reach.origin, Vector2i(4, 0), "the next move counts from the landing")
	assert_eq(reach.origin_budget, 2, "with the MP left")


func test_validation_matches_who_moves() -> void:
	var effect := MoveEffect.new()
	effect.kind = MoveEffect.Kind.TELEPORT
	effect.target_filter = EffectData.TargetFilter.ENEMIES
	assert_eq(effect.get_validation_errors().size(), 1, "a teleport moves the caster")
	effect.kind = MoveEffect.Kind.PUSH
	effect.target_filter = EffectData.TargetFilter.CASTER
	assert_eq(effect.get_validation_errors().size(), 1, "a push moves its targets")
	effect.target_filter = EffectData.TargetFilter.ENEMIES
	assert_eq(effect.get_validation_errors().size(), 0)


func test_the_preview_shows_where_units_land() -> void:
	var backslash := _spell(MoveEffect.Kind.RETREAT, 1, 1, 3, EffectData.TargetFilter.CASTER, 4)
	var state := BattleFixtures.state("0 0e 0p 0 0 0", 3)
	state.units[0].data.spells = [backslash] as Array[SpellData]
	Battle.new(state).start()
	assert_eq(DamagePreview.landings(state, 0, 0, Vector2i(1, 0)), {0: Vector2i(5, 0)} as Dictionary[int, Vector2i], "the caster leaps back")
	assert_eq(state.units[0].cell, Vector2i(2, 0), "the real state is untouched")
	var push := _spell(MoveEffect.Kind.PUSH, 1, 1, 2)
	state.units[0].data.spells = [push] as Array[SpellData]
	assert_eq(DamagePreview.landings(state, 0, 0, Vector2i(1, 0)), {1: Vector2i(0, 0)} as Dictionary[int, Vector2i], "the target stops at the edge")
	assert_eq(DamagePreview.landings(state, 0, 0, Vector2i(4, 0)), {} as Dictionary[int, Vector2i], "an illegal cast moves nobody")
