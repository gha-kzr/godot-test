extends TestCase
## Spells resolve effect by effect over the units fixed in their area; each effect's
## target filter picks which of them it applies to.

const Filter := EffectData.TargetFilter


func _damage(amount: int, filter := Filter.ALL) -> DamageEffect:
	var effect := DamageEffect.new()
	effect.min_amount = amount
	effect.max_amount = amount
	effect.target_filter = filter
	return effect


func _heal(amount: int, filter := Filter.ALL) -> HealEffect:
	var effect := HealEffect.new()
	effect.min_amount = amount
	effect.max_amount = amount
	effect.target_filter = filter
	return effect


## P0 casts on the middle cell of "0p 0p 0e 0e" area circle 1 → hits P1, E0 and E1 (not P0).
func _cast(effects: Array[EffectData], layout := "0p 0p 0e 0e", target := Vector2i(2, 0)) -> Array[BattleEvents.Event]:
	var caster := BattleFixtures.unit("P0", 200)
	caster.spells = [BattleFixtures.effect_spell(effects, 3, 0, 3, AreaShape.Kind.CIRCLE, 1)] as Array[SpellData]
	var state := BattleFixtures.state_with(layout, [caster, BattleFixtures.unit("P1", 190)],
			[BattleFixtures.unit("E0", 100), BattleFixtures.unit("E1", 90)])
	for unit in state.units:
		unit.hp = 10
	_state = state
	var battle := Battle.new(state)
	battle.start()
	var result := battle.perform(BattleActions.CastSpell.new(0, 0, target))
	assert_true(result.ok(), result.error)
	return result.events


var _state: BattleState


func _hit_ids(events: Array[BattleEvents.Event]) -> Array[int]:
	var ids: Array[int] = []
	for event in events:
		if event is BattleEvents.DamageDealt:
			ids.append((event as BattleEvents.DamageDealt).unit_id)
		elif event is BattleEvents.Healed:
			ids.append((event as BattleEvents.Healed).unit_id)
	return ids


func test_all_hits_everyone_in_the_area() -> void:
	assert_eq(_hit_ids(_cast([_damage(2)] as Array[EffectData])), [2, 1, 3] as Array[int], "area order: target cell first")


func test_enemies_only_skips_allies_in_the_area() -> void:
	assert_eq(_hit_ids(_cast([_damage(2, Filter.ENEMIES)] as Array[EffectData])), [2, 3] as Array[int])
	assert_eq(_state.units[1].hp, 10, "P1 untouched")


func test_allies_only_skips_enemies_in_the_area() -> void:
	assert_eq(_hit_ids(_cast([_heal(5, Filter.ALLIES)] as Array[EffectData])), [1] as Array[int])


func test_allies_include_the_caster_when_inside_the_area() -> void:
	var events := _cast([_heal(5, Filter.ALLIES)] as Array[EffectData], "0p 0p 0e 0e", Vector2i(0, 0))
	assert_eq(_hit_ids(events), [0, 1] as Array[int])


func test_caster_only_applies_once_even_outside_the_area() -> void:
	# A leech: damage the enemies, heal the caster (who stands outside the circle).
	var events := _cast([_damage(3, Filter.ENEMIES), _heal(4, Filter.CASTER)] as Array[EffectData])
	assert_eq(_hit_ids(events), [2, 3, 0] as Array[int])
	assert_eq(_state.units[0].hp, 14)


func test_effects_resolve_one_after_another_over_all_targets() -> void:
	var poison := BattleFixtures.status("Poison", 2, 1)
	var events := _cast([_damage(2, Filter.ENEMIES), BattleFixtures.apply_status(poison, Filter.ENEMIES)] as Array[EffectData])
	var kinds: Array[String] = []
	for event in events:
		if event is BattleEvents.DamageDealt:
			kinds.append("hit %d" % (event as BattleEvents.DamageDealt).unit_id)
		elif event is BattleEvents.StatusApplied:
			kinds.append("status %d" % (event as BattleEvents.StatusApplied).unit_id)
	assert_eq(kinds, ["hit 2", "hit 3", "status 2", "status 3"] as Array[String], "all hits, then all statuses")


func test_a_target_killed_by_an_earlier_effect_is_skipped() -> void:
	var poison := BattleFixtures.status("Poison", 2, 1)
	var events := _cast([_damage(10, Filter.ENEMIES), BattleFixtures.apply_status(poison)] as Array[EffectData])
	var statused: Array[int] = []
	for event in events:
		if event is BattleEvents.StatusApplied:
			statused.append((event as BattleEvents.StatusApplied).unit_id)
	assert_eq(statused, [1] as Array[int], "the enemies died to the hit; only P1 gets poisoned")
