extends TestCase
## Life steal, spells aimed at an ally or an enemy only, boss-only spells, and the boss Ghoul
## feasting on its ally when it is worth it.


func _lifesteal_spell(percent: int, filter := EffectData.TargetFilter.ALL) -> SpellData:
	var spell := BattleFixtures.damage_spell(3, 1, 1, 10)
	(spell.effects[0] as DamageEffect).lifesteal_percent = percent
	spell.effects[0].target_filter = filter
	return spell


func _battle(layout: String, spell: SpellData, caster_hp: int) -> Battle:
	var state := BattleFixtures.state(layout, 3)
	state.units[0].data.spells = [spell] as Array[SpellData]
	state.units[0].data.max_hp = 50
	state.units[0].hp = caster_hp
	var battle := Battle.new(state)
	battle.start()
	return battle


func test_lifesteal_heals_a_share_of_the_damage_dealt() -> void:
	var battle := _battle("0p 0e", _lifesteal_spell(50), 30)
	var result := battle.perform(BattleActions.CastSpell.new(0, 0, Vector2i(1, 0)))
	assert_true(result.ok(), result.error)
	assert_eq(battle.state.units[0].hp, 35, "half of 10")
	assert_true(result.events.any(func(e: BattleEvents.Event) -> bool: return e is BattleEvents.Healed and e.unit_id == 0))


func test_lifesteal_counts_only_what_was_dealt_and_caps_at_max_hp() -> void:
	var battle := _battle("0p 0e", _lifesteal_spell(400), 45)
	battle.state.units[1].hp = 2  # Only 2 damage can land.
	battle.perform(BattleActions.CastSpell.new(0, 0, Vector2i(1, 0)))
	assert_eq(battle.state.units[0].hp, 50, "8 would heal, capped at the max")
	var spared := _battle("0p 0p 0e", _lifesteal_spell(100, EffectData.TargetFilter.ENEMIES), 20)
	spared.perform(BattleActions.CastSpell.new(0, 0, Vector2i(1, 0)))
	assert_eq(spared.state.units[0].hp, 20, "an ally the filter spares gives nothing")


func test_a_spell_can_require_an_enemy_or_an_ally() -> void:
	var state := BattleFixtures.state("0p 0p 0e", 3)
	var spell := BattleFixtures.damage_spell(3, 1, 2, 1)
	spell.target_unit = SpellData.TargetUnit.ENEMY
	assert_eq(Targeting.targetable_cells(state, 0, spell), [Vector2i(2, 0)] as Array[Vector2i], "the enemy only")
	spell.target_unit = SpellData.TargetUnit.ALLY
	assert_eq(Targeting.targetable_cells(state, 0, spell), [Vector2i(1, 0)] as Array[Vector2i], "the ally only")
	spell.min_range = 0
	assert_false(Vector2i(0, 0) in Targeting.targetable_cells(state, 0, spell), "never the caster itself")
	assert_true("Targets an ally" in SpellBar.detail_lines(spell))


func test_only_the_boss_ghoul_knows_feast() -> void:
	var ghoul := load("res://data/enemies/ghoul.tres") as EnemyData
	var feast := load("res://data/spells/feast.tres") as SpellData
	assert_false(feast in ghoul.build(5).unit.spells, "a normal ghoul")
	assert_false(feast in ghoul.build(5, load("res://data/presets/elite.tres")).unit.spells, "an elite")
	assert_true(feast in ghoul.build(5, load("res://data/presets/boss.tres")).unit.spells, "the boss")
	assert_false(feast in ghoul.unit.spells, "the shared template is untouched")
	assert_eq(ghoul.get_validation_errors(), PackedStringArray())


func _boss_and_ally(boss_hp_share: float, hero_in_reach: bool) -> BattleState:
	var ghoul := load("res://data/enemies/ghoul.tres") as EnemyData
	var boss := ghoul.build(10, load("res://data/presets/boss.tres"))
	var escort := ghoul.build(10)
	var hero := BattleFixtures.unit("Hero", 50, 3, 6, 200)
	var layout := "0e 0e 0p 0 0" if hero_in_reach else "0e 0e 0 0 0 0 0 0p"
	var map := MapData.new()
	map.layout = layout
	var state := BattleState.create(map.parse(), [hero] as Array[UnitData], [boss.unit, escort.unit] as Array[UnitData], 1,
			[], [boss, escort])
	state.units[1].hp = roundi(state.units[1].max_hp() * boss_hp_share)
	var battle := Battle.new(state)
	battle.start()
	while state.turn_order.current_unit_id() != 1:
		battle.perform(BattleActions.EndTurn.new(state.turn_order.current_unit_id()))
	return state


func _feasts(state: BattleState) -> bool:
	var action := EnemyAI.choose_next(state, 1, state.units[1].ai_profile)
	var cast := action as BattleActions.CastSpell
	return cast != null and state.units[1].data.spells[cast.spell_index].display_name == "Feast"


func test_a_healthy_boss_ghoul_never_eats_its_ally() -> void:
	assert_false(_feasts(_boss_and_ally(1.0, false)), "nothing to heal, no hero near")
	assert_false(_feasts(_boss_and_ally(1.0, true)))


func test_a_wounded_boss_ghoul_eats_its_ally_and_gets_gorged() -> void:
	var state := _boss_and_ally(0.4, true)
	assert_true(_feasts(state), "badly hurt: feasting beats biting the hero")
	var battle := Battle.new(state)
	var hp_before := state.units[1].hp
	var escort_before := state.units[2].hp
	battle.perform(EnemyAI.choose_next(state, 1, state.units[1].ai_profile))
	assert_true(state.units[2].hp < escort_before, "the escort was bitten")
	assert_eq(state.units[1].hp - hp_before, 4 * (escort_before - state.units[2].hp), "four times the bite")
	assert_true(state.units[1].find_status(load("res://data/statuses/gorged.tres")) != null, "and gorged")
	assert_false(_feasts(state), "the cooldown: not again right away")
