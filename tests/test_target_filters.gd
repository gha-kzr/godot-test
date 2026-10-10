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
	state.friendly_fire = _friendly_fire
	_state = state
	var battle := Battle.new(state)
	battle.start()
	var result := battle.perform(BattleActions.CastSpell.new(0, 0, target))
	assert_true(result.ok(), result.error)
	return result.events


var _state: BattleState
## These tests are about the filters, so friendly fire is on unless a test turns it off.
var _friendly_fire := true


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


func _without_friendly_fire(effects: Array[EffectData], layout := "0p 0p 0e 0e", target := Vector2i(2, 0)) -> Array[BattleEvents.Event]:
	_friendly_fire = false
	var events := _cast(effects, layout, target)
	_friendly_fire = true
	return events


func test_without_friendly_fire_a_harmful_effect_spares_the_casters_team() -> void:
	# Aimed at P1 (1,0): the circle holds P0 (the caster), P1 and E0.
	var events := _without_friendly_fire([_damage(2)] as Array[EffectData], "0p 0p 0e 0e", Vector2i(1, 0))
	assert_eq(_hit_ids(events), [2] as Array[int], "only the enemy")
	assert_eq(_state.units[0].hp, 10, "the caster is spared")
	assert_eq(_state.units[1].hp, 10, "so is P1")


func test_without_friendly_fire_a_heal_and_a_helpful_status_still_reach_allies() -> void:
	var events := _without_friendly_fire([_heal(5)] as Array[EffectData], "0p 0p 0e 0e", Vector2i(1, 0))
	assert_true(_hit_ids(events).has(0) and _hit_ids(events).has(1), "allies are healed: %s" % [_hit_ids(events)])
	var guard := BattleFixtures.status("Guard", 2, 0, [] as Array[StatModifier], true)
	var statused: Array[int] = []
	for event in _without_friendly_fire([BattleFixtures.apply_status(guard)] as Array[EffectData], "0p 0p 0e 0e", Vector2i(1, 0)):
		if event is BattleEvents.StatusApplied:
			statused.append((event as BattleEvents.StatusApplied).unit_id)
	statused.sort()
	assert_eq(statused, [0, 1, 2] as Array[int], "a positive status lands on everyone in the area")


func test_without_friendly_fire_a_harmful_status_spares_allies_too() -> void:
	var poison := BattleFixtures.status("Poison", 2, 1)
	var statused: Array[int] = []
	for event in _without_friendly_fire([BattleFixtures.apply_status(poison)] as Array[EffectData], "0p 0p 0e 0e", Vector2i(1, 0)):
		if event is BattleEvents.StatusApplied:
			statused.append((event as BattleEvents.StatusApplied).unit_id)
	assert_eq(statused, [2] as Array[int])


func test_without_friendly_fire_an_effect_aimed_at_the_caster_still_hits_it() -> void:
	var events := _without_friendly_fire([_damage(2, Filter.CASTER)] as Array[EffectData], "0p 0p 0e 0e", Vector2i(1, 0))
	assert_eq(_hit_ids(events), [0] as Array[int], "a self-inflicted cost is not friendly fire")


func test_the_damage_preview_follows_the_rule() -> void:
	_friendly_fire = false
	_cast([_damage(2)] as Array[EffectData], "0p 0p 0e 0e", Vector2i(1, 0))
	_friendly_fire = true
	var entries := DamagePreview.for_cast(_state, 0, 0, Vector2i(1, 0))
	var ids: Array[int] = []
	for entry in entries:
		ids.append(entry.unit_id)
	assert_true(ids.has(2) and not ids.has(1), "the preview shows no damage on the ally: %s" % [ids])
