extends TestCase
## Content descriptions read the same in English once routed through tr().


func _damage(low: int, high: int, scaling := 100, type: DamageType = null) -> DamageEffect:
	var effect := DamageEffect.new()
	effect.min_amount = low
	effect.max_amount = high
	effect.power_scaling = scaling
	effect.damage_type = type
	return effect


func test_damage_and_heal_descriptions() -> void:
	var fire := DamageType.new()
	fire.display_name = "Fire"
	assert_eq(_damage(5, 7).describe(), "5-7 damage")
	assert_eq(_damage(5, 5, 50).describe(), "5 damage (50% Power)")
	assert_eq(_damage(3, 4, 100, fire).describe(), "3-4 fire damage")
	assert_eq(_damage(3, 4, 150, fire).describe(), "3-4 fire damage (150% Power)")
	var heal := HealEffect.new()
	heal.min_amount = 6
	heal.max_amount = 10
	assert_eq(heal.describe(), "heals 6-10")
	heal.target_filter = EffectData.TargetFilter.ALLIES
	assert_eq(heal.full_description(), "heals 6-10 (allies only)")


func test_status_and_modifier_descriptions() -> void:
	var slow := StatModifier.new()
	slow.stat = StatModifier.Stat.MP
	slow.amount = -2
	var guard := StatModifier.new()
	guard.stat = StatModifier.Stat.DAMAGE_TAKEN_PERCENT
	guard.amount = 25
	assert_eq([slow.describe(), guard.describe()], ["-2 MP", "+25% damage taken"])
	var poison := StatusData.new()
	poison.display_name = "Poison"
	poison.duration = 3
	poison.tick_effects.append(_damage(3, 4))
	poison.modifiers.append(slow)
	assert_eq(poison.describe(), "3-4 damage per turn, -2 MP")
	var apply := ApplyStatusEffect.new()
	apply.status = poison
	assert_eq(apply.describe(), "Poison for 3 turns (3-4 damage per turn, -2 MP)")
	poison.duration = 1
	assert_eq(apply.describe(), "Poison for 1 turn (3-4 damage per turn, -2 MP)")
	apply.target_filter = EffectData.TargetFilter.CASTER
	assert_eq(apply.describe(), "Poison for your next turn (3-4 damage per turn, -2 MP)")
	poison.duration = 2
	assert_eq(apply.describe(), "Poison for your next 2 turns (3-4 damage per turn, -2 MP)")


func test_rune_rarity_names() -> void:
	var rune := RuneData.new()
	var names: Array[String] = []
	for rarity in RuneData.Rarity.values():
		rune.rarity = rarity
		names.append(rune.rarity_name())
	assert_eq(names, ["Common", "Rare", "Epic", "Legendary"] as Array[String])
