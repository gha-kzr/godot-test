extends TestCase
## The damage preview: exact bounds from the battle's own formula, read-only.

const Filter := EffectData.TargetFilter


func _damage(low: int, high: int, type: DamageType = null, filter := Filter.ALL) -> DamageEffect:
	var effect := DamageEffect.new()
	effect.min_amount = low
	effect.max_amount = high
	effect.damage_type = type
	effect.target_filter = filter
	return effect


func _heal(low: int, high: int) -> HealEffect:
	var effect := HealEffect.new()
	effect.min_amount = low
	effect.max_amount = high
	return effect


## P0 casts `effects` (range 0-4, area per args) from the layout's first cell; one spell.
func _battle(layout: String, effects: Array[EffectData], area := AreaShape.Kind.SINGLE, size := 0, rng_seed := 1) -> Battle:
	var caster := BattleFixtures.unit("P0", 200)
	caster.spells = [BattleFixtures.effect_spell(effects, 2, 0, 4, area, size)] as Array[SpellData]
	var map := MapData.new()
	map.layout = layout
	var parsed := map.parse()
	var players: Array[UnitData] = [caster]
	var enemies: Array[UnitData] = []
	for i in parsed.enemy_spawns.size():
		enemies.append(BattleFixtures.unit("E%d" % i, 100 - i))
	for i in range(1, parsed.player_spawns.size()):
		players.append(BattleFixtures.unit("P%d" % i, 200 - i))
	var battle := Battle.new(BattleState.create(parsed, players, enemies, rng_seed))
	battle.start()
	return battle


func _preview(battle: Battle, target: Vector2i) -> Array[DamagePreview.Entry]:
	return DamagePreview.for_cast(battle.state, 0, 0, target)


func test_bounds_are_exact_and_every_real_roll_lands_inside() -> void:
	var seen := {}
	for seed_value in 60:
		var battle := _battle("0p 0 0e", [_damage(3, 5)] as Array[EffectData], AreaShape.Kind.SINGLE, 0, seed_value + 1)
		var entry := _preview(battle, Vector2i(2, 0))[0]
		assert_eq([entry.unit_id, entry.min_damage, entry.max_damage], [1, 3, 5])
		var result := battle.perform(BattleActions.CastSpell.new(0, 0, Vector2i(2, 0)))
		var dealt := 20 - battle.state.units[1].hp
		seen[dealt] = true
		assert_true(dealt >= entry.min_damage and dealt <= entry.max_damage, "real damage %d inside" % dealt)
		assert_true(result.ok(), result.error)
	assert_eq(seen.keys().size(), 3, "both bounds and the middle really happen")


func test_power_and_resistance_count() -> void:
	var fire := DamageType.new()
	fire.display_name = "Fire"
	var battle := _battle("0p 0 0e", [_damage(10, 10, fire)] as Array[EffectData])
	battle.state.units[0].permanent_modifiers.append(BattleFixtures.modifier(StatModifier.Stat.POWER, 50))
	var ward := BattleFixtures.modifier(StatModifier.Stat.RESISTANCE_PERCENT, 20)
	ward.damage_type = fire
	battle.state.units[1].permanent_modifiers.append(ward)
	var entry := _preview(battle, Vector2i(2, 0))[0]
	assert_eq([entry.min_damage, entry.max_damage], [12, 12], "10 x 150 % x 80 %")


func test_the_preview_changes_nothing() -> void:
	var battle := _battle("0p 0 0e", [_damage(3, 5)] as Array[EffectData])
	var before := [battle.state.units[1].hp, battle.state.units[0].ap, battle.state.rng.state]
	_preview(battle, Vector2i(2, 0))
	assert_eq([battle.state.units[1].hp, battle.state.units[0].ap, battle.state.rng.state], before)
	assert_eq(battle.state.roll_bound, BattleState.RollBound.NONE)


func test_a_kill_is_flagged_and_damage_is_capped_by_hp() -> void:
	var battle := _battle("0p 0 0e", [_damage(3, 5)] as Array[EffectData])
	battle.state.units[1].hp = 4
	var entry := _preview(battle, Vector2i(2, 0))[0]
	assert_true(entry.can_kill, "the highest roll kills")
	assert_eq([entry.min_damage, entry.max_damage], [3, 4])
	battle.state.units[1].hp = 6
	assert_false(_preview(battle, Vector2i(2, 0))[0].can_kill, "5 isn't enough")


func test_heals_are_capped_by_missing_hp_and_shown_with_a_plus() -> void:
	var battle := _battle("0p 0e", [_heal(6, 10)] as Array[EffectData])
	battle.state.units[0].hp = 18
	var entry := _preview(battle, Vector2i(0, 0))[0]
	assert_eq([entry.min_heal, entry.max_heal, entry.amount_text()], [2, 2, "+2"])
	battle.state.units[0].hp = 5
	assert_eq(_preview(battle, Vector2i(0, 0))[0].amount_text(), "+6-10")


func test_filters_and_areas_decide_who_is_listed() -> void:
	var battle := _battle("0p 0 0e 0e", [_damage(4, 4, null, Filter.ENEMIES)] as Array[EffectData], AreaShape.Kind.CIRCLE, 1)
	var entries := _preview(battle, Vector2i(2, 0))
	assert_eq(entries.map(func(e: DamagePreview.Entry) -> int: return e.unit_id), [1, 2], "both enemies in the circle")
	var ally := _battle("0p 0p 0e", [_damage(4, 4, null, Filter.ENEMIES)] as Array[EffectData], AreaShape.Kind.CIRCLE, 1)
	assert_eq(_preview(ally, Vector2i(1, 0)).map(func(e: DamagePreview.Entry) -> int: return e.unit_id), [2], "the ally in the area is left out")


func test_statuses_the_spell_would_apply_are_listed() -> void:
	var poison := BattleFixtures.status("Poison", 3, 2)
	var battle := _battle("0p 0 0e", [_damage(3, 3), BattleFixtures.apply_status(poison)] as Array[EffectData])
	var entry := _preview(battle, Vector2i(2, 0))[0]
	assert_eq(entry.statuses, [poison] as Array[StatusData])
	assert_eq(entry.amount_text(), "3")


func test_an_illegal_cast_previews_nothing() -> void:
	var battle := _battle("0p 0 0 0 0 0e", [_damage(3, 3)] as Array[EffectData])
	assert_eq(_preview(battle, Vector2i(5, 0)).size(), 0, "out of range")


func test_a_fully_resisted_hit_lists_nobody() -> void:
	var battle := _battle("0p 0 0e", [_damage(3, 5)] as Array[EffectData])
	battle.state.units[1].permanent_modifiers.append(BattleFixtures.modifier(StatModifier.Stat.DAMAGE_TAKEN_PERCENT, -100))
	assert_eq(_preview(battle, Vector2i(2, 0)).size(), 0)


func test_the_preview_follows_line_of_sight_over_a_block() -> void:
	var spell := BattleFixtures.damage_spell(2, 1, 4, 4, AreaShape.Kind.SINGLE, 0, true)
	for case: Array in [["0p # 0e", 0], ["2p # 0e", 1]]:
		var caster := BattleFixtures.unit("P0", 200)
		caster.spells = [spell] as Array[SpellData]
		var battle := Battle.new(BattleFixtures.state_with(case[0], [caster], [BattleFixtures.unit("E0", 100)]))
		battle.start()
		assert_eq(_preview(battle, Vector2i(2, 0)).size(), case[1], "layout %s" % case[0])
