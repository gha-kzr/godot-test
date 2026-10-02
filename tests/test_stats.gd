extends TestCase
## Milestone 2 stats: power, per-type resistance, max HP, initiative, as permanent
## modifiers (levels, runes) or status modifiers, and the damage / heal formula.

const Stat := StatModifier.Stat


func _type(type_name: String) -> DamageType:
	var type := DamageType.new()
	type.display_name = type_name
	return type


func _modifier(stat: Stat, amount: int, type: DamageType = null) -> StatModifier:
	var modifier := BattleFixtures.modifier(stat, amount)
	modifier.damage_type = type
	return modifier


func _damage(amount: int, type: DamageType = null) -> DamageEffect:
	var effect := DamageEffect.new()
	effect.min_amount = amount
	effect.max_amount = amount
	effect.damage_type = type
	return effect


func _heal(amount: int) -> HealEffect:
	var effect := HealEffect.new()
	effect.min_amount = amount
	effect.max_amount = amount
	return effect


## P0 (unit 0) with the given permanent modifiers vs E0 (unit 1), 40 HP each.
func _state(p0_modifiers: Array[StatModifier] = []) -> BattleState:
	var map := MapData.new()
	map.layout = "0p 0e"
	var players: Array[UnitData] = [BattleFixtures.unit("P0", 200, 3, 6, 40)]
	var enemies: Array[UnitData] = [BattleFixtures.unit("E0", 100, 3, 6, 40)]
	return BattleState.create(map.parse(), players, enemies, 1, [p0_modifiers])


func _dealt(state: BattleState, effect: EffectData, caster := 0, target := 1) -> int:
	var events := effect.apply(state, caster, target)
	if events[0] is BattleEvents.DamageDealt:
		return (events[0] as BattleEvents.DamageDealt).amount
	return (events[0] as BattleEvents.Healed).amount


func test_power_scales_damage_and_heals() -> void:
	var state := _state([_modifier(Stat.POWER, 50)] as Array[StatModifier])
	assert_eq(_dealt(state, _damage(10)), 15, "+50% damage")
	state.units[0].hp = 10
	assert_eq(_dealt(state, _heal(10), 0, 0), 15, "+50% heal")


func test_negative_power_never_goes_below_zero() -> void:
	var state := _state([_modifier(Stat.POWER, -150)] as Array[StatModifier])
	assert_eq(_dealt(state, _damage(10)), 0)


func test_resistance_is_per_type_and_capped() -> void:
	var fire := _type("Fire")
	var physical := _type("Physical")
	var state := _state()
	state.units[1].permanent_modifiers.assign([_modifier(Stat.RESISTANCE_PERCENT, 30, fire)])
	assert_eq(_dealt(state, _damage(10, fire)), 7, "30% fire resistance")
	assert_eq(_dealt(state, _damage(10, physical)), 10, "other types untouched")
	assert_eq(_dealt(state, _damage(10)), 10, "untyped damage is never resisted")
	state.units[1].permanent_modifiers.append(_modifier(Stat.RESISTANCE_PERCENT, 80, fire))
	assert_eq(state.units[1].resistance_percent(fire), 100, "an enemy is capped at immunity")
	assert_eq(_dealt(state, _damage(10, fire)), 0, "immune")
	state.units[0].permanent_modifiers.assign([_modifier(Stat.RESISTANCE_PERCENT, 110, fire)])
	assert_eq(state.units[0].resistance_percent(fire), 75, "a hero at 75 %")
	assert_true(UnitInfo.from_unit(state.units[1]).combat_stats_text().contains("Fire immune"), "the card says so")


func test_negative_resistance_is_a_weakness() -> void:
	var fire := _type("Fire")
	var state := _state()
	state.units[1].permanent_modifiers.assign([_modifier(Stat.RESISTANCE_PERCENT, -50, fire)])
	assert_eq(_dealt(state, _damage(10, fire)), 15)


func test_power_resistance_and_damage_taken_combine() -> void:
	var fire := _type("Fire")
	var state := _state([_modifier(Stat.POWER, 20)] as Array[StatModifier])
	state.units[1].permanent_modifiers.assign([_modifier(Stat.RESISTANCE_PERCENT, 25, fire)])
	state.units[1].add_status(BattleFixtures.status("Vulnerable", 2, 0, [BattleFixtures.modifier(Stat.DAMAGE_TAKEN_PERCENT, 50)] as Array[StatModifier]), 0)
	assert_eq(_dealt(state, _damage(10, fire)), 14, "10 x 1.2 x 1.5 x 0.75 = 13.5, rounded")


func test_permanent_and_status_modifiers_add_up() -> void:
	var state := _state([_modifier(Stat.POWER, 10)] as Array[StatModifier])
	state.units[0].add_status(BattleFixtures.status("Fury", 2, 0, [_modifier(Stat.POWER, 15)] as Array[StatModifier], true), 0)
	assert_eq(state.units[0].power(), 25)


func test_max_hp_modifiers_raise_starting_and_capped_hp() -> void:
	var state := _state([_modifier(Stat.MAX_HP, 12)] as Array[StatModifier])
	assert_eq(state.units[0].max_hp(), 52)
	assert_eq(state.units[0].hp, 52, "starts full")
	assert_eq(state.units[1].hp, 40)
	state.units[0].hp = 50
	assert_eq(_dealt(state, _heal(10), 0, 0), 2, "heals cap at the modified max")


func test_initiative_modifiers_change_the_turn_order() -> void:
	var map := MapData.new()
	map.layout = "0p 0p 0e"
	var players: Array[UnitData] = [BattleFixtures.unit("P0", 150), BattleFixtures.unit("P1", 140)]
	var mods: Array = [[] as Array[StatModifier], [_modifier(Stat.INITIATIVE, 20)] as Array[StatModifier]]
	var state := BattleState.create(map.parse(), players, [BattleFixtures.unit("E0", 100)] as Array[UnitData], 1, mods)
	assert_eq(state.turn_order.upcoming(), [1, 0, 2] as Array[int], "P1 now acts before P0")


func test_ap_and_mp_modifiers_fill_the_first_turn() -> void:
	var state := _state([_modifier(Stat.MP, 1)] as Array[StatModifier])
	assert_eq(state.units[0].mp, 4)


func test_clones_keep_permanent_modifiers() -> void:
	var state := _state([_modifier(Stat.POWER, 50)] as Array[StatModifier])
	var copy := state.clone()
	assert_eq(copy.units[0].power(), 50)
	copy.units[0].permanent_modifiers.clear()
	assert_eq(state.units[0].power(), 50, "independent lists")


func test_descriptions_and_validation() -> void:
	var fire := _type("Fire")
	assert_eq(_modifier(Stat.POWER, 10).describe(), "+10 Power")
	assert_eq(_modifier(Stat.RESISTANCE_PERCENT, 15, fire).describe(), "+15% Fire resistance")
	assert_eq(_modifier(Stat.MAX_HP, 5).describe(), "+5 HP")
	assert_eq(_modifier(Stat.INITIATIVE, -10).describe(), "-10 initiative")
	assert_eq(_damage(5, fire).describe(), "5 fire damage")
	var bad := _modifier(Stat.RESISTANCE_PERCENT, 10)
	assert_true(Array(bad.get_validation_errors()).any(func(e: String) -> bool: return "has no damage_type" in e))
	assert_eq(DamageType.new().get_validation_errors().size(), 1)


func test_ai_values_ticks_with_the_casters_power() -> void:
	var state := _state([_modifier(Stat.POWER, 50)] as Array[StatModifier])
	state.units[1].add_status(BattleFixtures.status("Poison", 2, 4), 0)
	assert_eq(EnemyAI._statuses_benefit(state, state.units[1], AIProfile.new()), -12.0, "4 x 150% x 2 turns")


func test_types_match_exactly() -> void:
	var fire := _type("Fire")
	var typed_power := _modifier(Stat.POWER, 20, fire)
	var state := _state([typed_power] as Array[StatModifier])
	assert_eq(state.units[0].power(), 0, "a typed POWER isn't general power")
	assert_true(Array(typed_power.get_validation_errors()).any(func(e: String) -> bool: return "isn't a per-type stat" in e))


func test_statuses_cant_change_max_hp_or_initiative_yet() -> void:
	var status := BattleFixtures.status("Bulk", 2, 0, [_modifier(Stat.MAX_HP, 10)] as Array[StatModifier])
	assert_true(Array(status.get_validation_errors()).any(func(e: String) -> bool: return "can't change MAX_HP" in e))


func test_heals_never_go_negative_above_max_hp() -> void:
	var state := _state()
	state.units[0].hp = 45  # Above the 40 max (e.g. a lost bonus).
	assert_eq(_dealt(state, _heal(10), 0, 0), 0)
	assert_eq(state.units[0].hp, 45)


func test_innate_modifiers_apply_in_every_battle() -> void:
	var fire := _type("Fire")
	var data := BattleFixtures.unit("Salamander", 100, 3, 6, 30)
	data.innate_modifiers = [_modifier(Stat.RESISTANCE_PERCENT, 40, fire), _modifier(Stat.MAX_HP, 10)] as Array[StatModifier]
	var state := BattleFixtures.state_with("0p 0e", [BattleFixtures.unit("P0", 200)] as Array[UnitData], [data] as Array[UnitData])
	var salamander := state.units[1]
	assert_eq(salamander.max_hp(), 40)
	assert_eq(salamander.hp, 40, "starts full, innate HP included")
	assert_eq(salamander.resistance_percent(fire), 40)
	assert_eq(salamander.resistance_types(), [fire] as Array[DamageType])
	assert_eq(_dealt(state, _damage(10, fire)), 6)
	data.innate_modifiers.append(null)
	assert_true(Array(data.get_validation_errors()).any(func(e: String) -> bool: return "empty innate modifier slot" in e))


func test_the_damage_type_catalog_lists_every_type_in_order() -> void:
	var names := DamageType.all().map(func(t: DamageType) -> String: return t.display_name)
	assert_eq(names, ["Physical", "Fire", "Poison"])


func test_power_scaling_per_effect() -> void:
	var state := _state([_modifier(Stat.POWER, 50)] as Array[StatModifier])
	var heavy := _damage(10)
	heavy.power_scaling = 150
	assert_eq(_dealt(state, heavy), 18, "10 x (100 + 50 x 150%) = 17.5, rounded")
	var light := _damage(10)
	light.power_scaling = 50
	assert_eq(_dealt(state, light), 13, "10 x 1.25")
	state.units[1].hp = 40
	var fixed := _damage(10)
	fixed.power_scaling = 0
	assert_eq(_dealt(state, fixed), 10, "ignores Power")
	var heal := _heal(10)
	heal.power_scaling = 200
	state.units[0].hp = 1
	assert_eq(_dealt(state, heal, 0, 0), 20)
	assert_eq(heavy.describe(), "10 damage (150% Power)")
	assert_eq(_damage(10).describe(), "10 damage", "100% says nothing")


func test_rules_and_data_scripts_run_in_the_editor() -> void:
	# Editor code (previews, balance lab) can only run @tool scripts.
	for dir in ["res://scripts/data", "res://scripts/battle", "res://scripts/progression"]:
		for file in DirAccess.get_files_at(dir):
			if file.ends_with(".gd"):
				var script := load(dir.path_join(file)) as GDScript
				assert_true(script.is_tool(), "%s is @tool" % file)
