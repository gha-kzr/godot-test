extends TestCase
## Runes, loot tables and battle rewards (resolved at the end of a won fight).


func _loot(runes: Array[RuneData], chance := 1.0, rolls := 1) -> LootTable:
	var table := LootTable.new()
	table.runes = runes
	table.drop_chance = chance
	table.rolls = rolls
	return table


## P0 vs E0 and E1 (xp 10 and 15, each with a loot table), outcome set by who's dead.
func _state(rng_seed := 1) -> BattleState:
	var builds: Array = []
	var enemies: Array[UnitData] = []
	for entry in [["E0", 10, "Might"], ["E1", 15, "Ward"]]:
		var enemy := EnemyData.new()
		enemy.unit = BattleFixtures.unit(entry[0], 100)
		enemy.xp_base = entry[1]
		enemy.loot_table = _loot([BattleFixtures.rune(entry[2])] as Array[RuneData])
		builds.append(enemy.build(1))
		enemies.append(enemy.unit)
	var map := MapData.new()
	map.layout = "0p 0e 0e"
	return BattleState.create(map.parse(), [BattleFixtures.unit("P0", 200)] as Array[UnitData], enemies, rng_seed, [], builds)


func test_a_win_gives_every_killed_enemys_xp_and_loot() -> void:
	var state := _state()
	state.units[1].hp = 0
	state.units[2].hp = 0
	var rewards := BattleRewards.compute(state)
	assert_eq(rewards.xp, 25)
	assert_eq(rewards.runes.map(func(r: RuneData) -> String: return r.display_name), ["Might", "Ward"])


func test_deeper_enemies_drop_higher_level_runes() -> void:
	var state := _state()
	state.units[1].hp = 0
	state.units[2].hp = 0
	state.units[2].reward.enemy_level = 29
	var rewards := BattleRewards.compute(state)
	assert_true(rewards.runes[0].level <= 2, "a level 1 enemy")
	assert_true(rewards.runes[1].level >= 6, "a level 29 enemy: 1 + 29 / 5")
	assert_eq(rewards.runes[1].display_name, "Ward")
	assert_true(rewards.runes[1].origin().level == 1)


func test_a_loss_or_draw_gives_nothing() -> void:
	var state := _state()
	state.units[0].hp = 0
	state.units[1].hp = 0
	var rewards := BattleRewards.compute(state)
	assert_eq([rewards.xp, rewards.runes.size()], [0, 0], "lost, though E0 died")
	state.units[2].hp = 0
	rewards = BattleRewards.compute(state)
	assert_eq([rewards.xp, rewards.runes.size()], [0, 0], "draw")


func test_loot_is_deterministic_per_battle_seed() -> void:
	var drops: Array = []
	for i in 2:
		var state := _state(42)
		state.units[1].reward.loot_table = _loot([BattleFixtures.rune("A"), BattleFixtures.rune("B"), BattleFixtures.rune("C")] as Array[RuneData], 0.5, 5)
		state.units[1].hp = 0
		state.units[2].hp = 0
		drops.append(BattleRewards.compute(state).runes.map(func(r: RuneData) -> String: return r.display_name))
	assert_eq(drops[0], drops[1])


func test_rarity_weights_the_picks() -> void:
	var common := BattleFixtures.rune("Common", RuneData.Rarity.COMMON)
	var legendary := BattleFixtures.rune("Legendary", RuneData.Rarity.LEGENDARY)
	var table := _loot([common, legendary] as Array[RuneData], 1.0, 1000)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var legendaries := table.roll(rng).filter(func(r: RuneData) -> bool: return r == legendary).size()
	assert_true(legendaries > 40 and legendaries < 150, "about 5/65 of 1000, got %d" % legendaries)


func test_drop_chance_and_empty_tables() -> void:
	var rng := RandomNumberGenerator.new()
	assert_eq(_loot([BattleFixtures.rune("A")] as Array[RuneData], 0.0, 10).roll(rng).size(), 0)
	assert_eq(_loot([] as Array[RuneData], 1.0, 10).roll(rng).size(), 0)


func test_rune_rules_and_validation() -> void:
	assert_false(BattleFixtures.rune("C", RuneData.Rarity.RARE).is_unique())
	assert_true(BattleFixtures.rune("E", RuneData.Rarity.EPIC).is_unique())
	assert_true(BattleFixtures.rune("L", RuneData.Rarity.LEGENDARY).is_unique())
	assert_eq(BattleFixtures.rune("Might").describe(), "+5 Power")
	var bad := RuneData.new()
	var errors := Array(bad.get_validation_errors())
	assert_true(errors.any(func(e: String) -> bool: return "no display_name" in e))
	assert_true(errors.any(func(e: String) -> bool: return "no modifiers" in e))
	var table := _loot([] as Array[RuneData])
	assert_true(Array(table.get_validation_errors()).any(func(e: String) -> bool: return "no runes" in e))
	var enemy := EnemyData.new()
	enemy.unit = BattleFixtures.unit("E")
	enemy.loot_table = table
	assert_true(Array(enemy.get_validation_errors()).any(func(e: String) -> bool: return "E: loot table" in e), "reaches the enemy")


func test_loot_ignores_how_many_dice_the_battle_rolled() -> void:
	var drops: Array = []
	for rolls_before in [0, 50]:
		var state := _state(42)
		state.units[1].reward.loot_table = _loot([BattleFixtures.rune("A"), BattleFixtures.rune("B"), BattleFixtures.rune("C")] as Array[RuneData], 0.5, 5)
		for i in rolls_before:
			state.rng.randi()
		var copy := state.clone()
		copy.units[1].hp = 0
		copy.units[2].hp = 0
		drops.append(BattleRewards.compute(copy).runes.map(func(r: RuneData) -> String: return r.display_name))
	assert_eq(drops[0], drops[1], "seeded from the battle seed, not the dice state")
