extends TestCase


func _valid_spell() -> SpellData:
	var spell := SpellData.new()
	spell.display_name = "Strike"
	spell.area = AreaShape.new()
	spell.effects = [DamageEffect.new()] as Array[EffectData]
	return spell


func test_valid_spell_has_no_errors() -> void:
	assert_eq(_valid_spell().get_validation_errors().size(), 0)


func test_spell_errors() -> void:
	var spell := _valid_spell()
	spell.min_range = 4
	spell.max_range = 2
	assert_has_error(spell.get_validation_errors(), "min_range (4) > max_range (2)")

	spell = _valid_spell()
	spell.area = null
	assert_has_error(spell.get_validation_errors(), "no area")

	spell = _valid_spell()
	spell.effects = []
	assert_has_error(spell.get_validation_errors(), "no effects")


func test_nested_errors_bubble_up_to_the_unit() -> void:
	var spell := _valid_spell()
	var damage := DamageEffect.new()
	damage.min_amount = 10
	damage.max_amount = 5
	spell.effects = [damage] as Array[EffectData]
	spell.area.kind = AreaShape.Kind.CIRCLE
	var unit := UnitData.new()
	unit.display_name = "Knight"
	unit.spells = [spell] as Array[SpellData]
	var errors := unit.get_validation_errors()
	assert_has_error(errors, "Knight: Strike: damage min_amount (10) > max_amount (5)")
	assert_has_error(errors, "Knight: Strike: area size must be >= 1 for CIRCLE")


func test_spell_costing_more_ap_than_the_unit_has() -> void:
	var spell := _valid_spell()
	spell.ap_cost = 7
	var unit := UnitData.new()
	unit.display_name = "Knight"
	unit.ap = 6
	unit.spells = [spell] as Array[SpellData]
	assert_has_error(unit.get_validation_errors(), "Strike costs 7 AP but the unit has 6")


func assert_has_error(errors: PackedStringArray, expected: String) -> void:
	assert_true(Array(errors).any(func(e: String) -> bool: return expected in e),
			"errors %s should contain '%s'" % [errors, expected])


func test_ai_profile_rejects_negative_weights() -> void:
	var profile := AIProfile.new()
	assert_eq(profile.get_validation_errors().size(), 0)
	profile.heal_weight = -1.0
	assert_has_error(profile.get_validation_errors(), "heal_weight must be >= 0")
