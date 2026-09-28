extends TestCase
## Status content: modifiers, statuses, the apply-status effect and target filters.


func _damage(low: int, high: int) -> DamageEffect:
	var effect := DamageEffect.new()
	effect.min_amount = low
	effect.max_amount = high
	return effect


func _modifier(stat: StatModifier.Stat, amount: int) -> StatModifier:
	var modifier := StatModifier.new()
	modifier.stat = stat
	modifier.amount = amount
	return modifier


func _poison() -> StatusData:
	var status := StatusData.new()
	status.display_name = "Poison"
	status.short_label = "P"
	status.duration = 3
	status.tick_effects = [_damage(3, 4)] as Array[EffectData]
	return status


func assert_has_error(errors: PackedStringArray, expected: String) -> void:
	assert_true(Array(errors).any(func(e: String) -> bool: return expected in e),
			"errors %s should contain '%s'" % [errors, expected])


func test_modifier_descriptions() -> void:
	assert_eq(_modifier(StatModifier.Stat.MP, 2).describe(), "+2 MP")
	assert_eq(_modifier(StatModifier.Stat.AP, -1).describe(), "-1 AP")
	assert_eq(_modifier(StatModifier.Stat.DAMAGE_TAKEN_PERCENT, 25).describe(), "+25% damage taken")
	assert_eq(_modifier(StatModifier.Stat.DAMAGE_TAKEN_PERCENT, -30).describe(), "-30% damage taken")


func test_status_description_lists_ticks_then_modifiers() -> void:
	var status := _poison()
	status.modifiers = [_modifier(StatModifier.Stat.MP, -2)] as Array[StatModifier]
	assert_eq(status.describe(), "3-4 damage per turn, -2 MP")


func test_apply_status_description() -> void:
	var effect := ApplyStatusEffect.new()
	effect.status = _poison()
	assert_eq(effect.describe(), "Poison for 3 turns (3-4 damage per turn)")
	effect.status.duration = 1
	assert_true(effect.describe().contains("for 1 turn "), effect.describe())


func test_target_filter_shows_in_full_descriptions() -> void:
	var heal := HealEffect.new()
	heal.min_amount = 6
	heal.max_amount = 10
	assert_eq(heal.full_description(), "heals 6-10", "ALL adds nothing")
	heal.target_filter = EffectData.TargetFilter.ALLIES
	assert_eq(heal.full_description(), "heals 6-10 (allies only)")
	heal.target_filter = EffectData.TargetFilter.ENEMIES
	assert_eq(heal.full_description(), "heals 6-10 (enemies only)")
	heal.target_filter = EffectData.TargetFilter.CASTER
	assert_eq(heal.full_description(), "heals 6-10 (caster only)")


func test_a_valid_status_has_no_errors() -> void:
	assert_eq(_poison().get_validation_errors(), PackedStringArray())
	var guard := StatusData.new()
	guard.display_name = "Guard"
	guard.short_label = "G"
	guard.modifiers = [_modifier(StatModifier.Stat.DAMAGE_TAKEN_PERCENT, -30)] as Array[StatModifier]
	assert_eq(guard.get_validation_errors(), PackedStringArray(), "modifiers only is fine")


func test_status_validation_errors() -> void:
	var empty := StatusData.new()
	var errors := empty.get_validation_errors()
	assert_has_error(errors, "status has no display_name")
	assert_has_error(errors, "no short_label")
	assert_has_error(errors, "no tick effects and no modifiers")

	var status := _poison()
	status.duration = 0
	status.tick_effects.append(null)
	status.tick_effects.append(_damage(5, 2))
	status.modifiers = [null, _modifier(StatModifier.Stat.AP, 0)] as Array[StatModifier]
	errors = status.get_validation_errors()
	assert_has_error(errors, "Poison: duration must be >= 1")
	assert_has_error(errors, "Poison: empty tick effect slot")
	assert_has_error(errors, "Poison: damage min_amount (5) > max_amount (2)")
	assert_has_error(errors, "Poison: empty modifier slot")
	assert_has_error(errors, "Poison: modifier of AP has amount 0")


func test_ticks_cannot_apply_statuses_or_filter_targets() -> void:
	var status := _poison()
	var nested := ApplyStatusEffect.new()
	nested.status = _poison()
	var filtered := _damage(1, 1)
	filtered.target_filter = EffectData.TargetFilter.ENEMIES
	status.tick_effects = [nested, filtered] as Array[EffectData]
	var errors := status.get_validation_errors()
	assert_has_error(errors, "a tick can't apply a status")
	assert_has_error(errors, "leave target_filter at ALL")


func test_apply_status_effect_validation_includes_its_status() -> void:
	var effect := ApplyStatusEffect.new()
	assert_has_error(effect.get_validation_errors(), "has no status")
	effect.status = _poison()
	effect.status.short_label = ""
	assert_has_error(effect.get_validation_errors(), "Poison: no short_label")


func test_spell_validation_reaches_status_errors() -> void:
	var effect := ApplyStatusEffect.new()
	effect.status = _poison()
	effect.status.duration = 0
	var spell := BattleFixtures.damage_spell()
	spell.effects.append(effect)
	assert_has_error(spell.get_validation_errors(), "Hit: Poison: duration must be >= 1")


func test_short_labels_stay_short() -> void:
	var status := _poison()
	status.short_label = "PSN"
	assert_has_error(status.get_validation_errors(), "short_label longer than 2 characters")
