extends TestCase
## Enemies with levels and presets, encounters, and what they give.

const BRUTE := "res://data/enemies/brute.tres"


func _enemy(hp_per_level := 5, power_per_level := 3) -> EnemyData:
	var enemy := EnemyData.new()
	enemy.unit = BattleFixtures.unit("Brute", 100, 3, 6, 40)
	enemy.hp_per_level = hp_per_level
	enemy.power_per_level = power_per_level
	enemy.xp_base = 10
	enemy.xp_per_level = 2
	return enemy


func _stats(build: EnemyData.Build) -> UnitState:
	var map := MapData.new()
	map.layout = "0p 0e"
	var state := BattleState.create(map.parse(), [BattleFixtures.unit("P0", 200)] as Array[UnitData],
			[build.unit] as Array[UnitData], 1, [], [build])
	return state.units[1]


func test_level_growth_becomes_permanent_modifiers() -> void:
	var unit := _stats(_enemy().build(5))
	assert_eq(unit.max_hp(), 60, "40 + 4 levels x 5")
	assert_eq(unit.hp, 60, "starts full")
	assert_eq(unit.power(), 12, "4 levels x 3")
	assert_eq(unit.label, "Brute Lv 5")
	assert_eq(unit.reward.xp, 18, "10 + 4 x 2")


func test_level_1_is_the_base_unit() -> void:
	var build := _enemy().build(1)
	assert_eq(build.modifiers.size(), 0)
	assert_eq(build.label, "Brute Lv 1")
	assert_eq(_enemy().build(0).label, "Brute Lv 1", "levels start at 1")


func test_presets_boost_stats_rewards_and_look() -> void:
	var elite := load("res://data/presets/elite.tres") as DifficultyPreset
	var unit := _stats(_enemy().build(3, elite))
	assert_eq(unit.max_hp(), 75, "(40 + 10) x 1.5")
	assert_eq(unit.power(), 26, "6 from levels + 20")
	assert_eq(unit.reward.xp, 28, "(10 + 4) x 2")
	assert_eq(unit.reward.extra_rolls, 1)
	assert_eq(unit.label, "Brute Lv 3 · Elite")
	assert_eq(unit.visual_scale, 1.1)
	var normal := load("res://data/presets/normal.tres") as DifficultyPreset
	assert_eq(_enemy().build(3, normal).label, "Brute Lv 3", "no tag for normal")


func test_a_boss_brings_its_own_ai_profile_and_better_loot() -> void:
	var boss := load("res://data/presets/boss.tres") as DifficultyPreset
	var build := _enemy().build(1, boss)
	assert_eq(build.ai_profile, load("res://data/ai/sharp.tres"))
	assert_eq(build.reward.rarity_floor, RuneData.Rarity.RARE)
	assert_eq(build.visual_scale, 1.3)


func test_extra_rolls_and_rarity_floor_shape_the_loot() -> void:
	var common := BattleFixtures.rune("Common", RuneData.Rarity.COMMON)
	var rare := BattleFixtures.rune("Rare", RuneData.Rarity.RARE)
	var table := LootTable.new()
	table.rolls = 1
	table.drop_chance = 1.0
	table.runes = [common, rare] as Array[RuneData]
	var rng := RandomNumberGenerator.new()
	assert_eq(table.roll(rng, 2).size(), 3, "1 roll + 2 extra")
	var floored := table.roll(rng, 20, RuneData.Rarity.RARE)
	assert_true(floored.all(func(r: RuneData) -> bool: return r == rare), "rare or better only")
	var only_common := LootTable.new()
	only_common.drop_chance = 1.0
	only_common.runes = [common] as Array[RuneData]
	assert_eq(only_common.roll(rng, 0, RuneData.Rarity.LEGENDARY), [common] as Array[RuneData], "falls back to the table")
	var odds := table.drop_odds()
	assert_true(is_equal_approx(odds[common], 60.0 / 85.0))
	assert_true(is_equal_approx(table.drop_odds(RuneData.Rarity.RARE)[rare], 1.0))


func test_rewards_follow_the_spawn() -> void:
	var boss := load("res://data/presets/boss.tres") as DifficultyPreset
	var enemy := load(BRUTE) as EnemyData
	var map := MapData.new()
	map.layout = "0p 0e"
	var build := enemy.build(2, boss)
	var state := BattleState.create(map.parse(), [BattleFixtures.unit("P0", 200)] as Array[UnitData],
			[build.unit] as Array[UnitData], 3, [], [build])
	state.units[1].hp = 0
	var rewards := BattleRewards.compute(state)
	assert_eq(rewards.xp, 100, "(15 + 5) x 5")
	assert_true(rewards.runes.all(func(r: RuneData) -> bool: return r.rarity >= RuneData.Rarity.RARE), "boss floor")


func test_the_controller_uses_a_units_own_ai_profile_first() -> void:
	var controller := (load("res://scenes/battle/battle.tscn") as PackedScene).instantiate() as BattleController
	controller.encounter = load("res://data/encounters/slice.tres")
	var unit := UnitState.new(0, BattleFixtures.unit("E"), UnitState.Team.ENEMY, Vector2i.ZERO)
	assert_eq(controller._ai_profile_for(unit), controller.encounter.ai_profile, "the encounter's")
	unit.ai_profile = load("res://data/ai/sharp.tres")
	assert_eq(controller._ai_profile_for(unit), unit.ai_profile, "the unit's own")
	controller.free()


func test_encounter_builds_and_validation() -> void:
	var encounter := load("res://data/encounters/slice.tres") as Encounter
	assert_eq(encounter.get_validation_errors(), PackedStringArray())
	var builds := encounter.builds()
	assert_eq(builds.map(func(b: EnemyData.Build) -> String: return b.label), ["Brute Lv 1", "Archer Lv 1"])
	var bad := Encounter.new()
	bad.display_name = "Bad"
	var errors := Array(bad.get_validation_errors())
	assert_true(errors.any(func(e: String) -> bool: return "no map" in e))
	assert_true(errors.any(func(e: String) -> bool: return "no enemies" in e))
	bad.map = encounter.map
	for i in 3:
		bad.spawns.append(encounter.spawns[0])
	assert_true(Array(bad.get_validation_errors()).any(func(e: String) -> bool: return "3 enemies for 2 enemy spawns" in e))


func test_a_preset_enemy_shows_its_label_in_battle() -> void:
	var elite := load("res://data/presets/elite.tres") as DifficultyPreset
	var controller := (load("res://scenes/battle/battle.tscn") as PackedScene).instantiate() as BattleController
	controller.encounter = BattleFixtures.encounter("0p 0 0 0e", [BattleFixtures.unit("Ogre", 100)] as Array[UnitData], 0, elite)
	controller.players = [BattleFixtures.unit("P0", 200)] as Array[UnitData]
	controller.rng_seed = 1
	(Engine.get_main_loop() as SceneTree).root.add_child(controller)
	var ogre := controller.battle.state.units[1]
	assert_eq(ogre.label, "Ogre Lv 1 · Elite")
	assert_eq(Hud.UnitInfo.from_unit(ogre).display_name, "Ogre Lv 1 · Elite")
	assert_true(is_equal_approx((controller.units_view.view(1).get_node("Body") as Node3D).scale.x, 1.1), "bigger")
	controller.free()


func test_empty_slots_are_reported_not_crashed_on() -> void:
	var enemy := EnemyData.new()
	expect_error("no unit")
	assert_eq(enemy.build(1, load("res://data/presets/elite.tres")), null)
	var encounter := (load("res://data/encounters/slice.tres") as Encounter).duplicate_deep(Resource.DEEP_DUPLICATE_INTERNAL) as Encounter
	encounter.spawns.append(null)
	expect_error("skipping an empty or broken spawn")
	assert_eq(encounter.builds().size(), 2, "the good spawns still build")


func test_a_battle_refuses_an_invalid_encounter() -> void:
	var controller := (load("res://scenes/battle/battle.tscn") as PackedScene).instantiate() as BattleController
	controller.encounter = Encounter.new()
	controller.encounter.map = load("res://data/maps/slice.tres")
	expect_error("invalid encounter")
	(Engine.get_main_loop() as SceneTree).root.add_child(controller)
	assert_eq(controller.battle, null)
	controller.free()
