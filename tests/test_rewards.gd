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
	var e0 := BattleFixtures.unit("E0", 100)
	e0.xp_reward = 10
	e0.loot_table = _loot([BattleFixtures.rune("Might")] as Array[RuneData])
	var e1 := BattleFixtures.unit("E1", 90)
	e1.xp_reward = 15
	e1.loot_table = _loot([BattleFixtures.rune("Ward")] as Array[RuneData])
	return BattleFixtures.state_with("0p 0e 0e", [BattleFixtures.unit("P0", 200)] as Array[UnitData], [e0, e1] as Array[UnitData], rng_seed)


func test_a_win_gives_every_killed_enemys_xp_and_loot() -> void:
	var state := _state()
	state.units[1].hp = 0
	state.units[2].hp = 0
	var rewards := BattleRewards.compute(state)
	assert_eq(rewards.xp, 25)
	assert_eq(rewards.runes.map(func(r: RuneData) -> String: return r.display_name), ["Might", "Ward"])


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
		state.units[1].data.loot_table = _loot([BattleFixtures.rune("A"), BattleFixtures.rune("B"), BattleFixtures.rune("C")] as Array[RuneData], 0.5, 5)
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
	var unit := BattleFixtures.unit("E")
	unit.loot_table = table
	assert_true(Array(unit.get_validation_errors()).any(func(e: String) -> bool: return "E: loot table" in e), "reaches the unit")


func test_loot_ignores_how_many_dice_the_battle_rolled() -> void:
	var drops: Array = []
	for rolls_before in [0, 50]:
		var state := _state(42)
		state.units[1].data.loot_table = _loot([BattleFixtures.rune("A"), BattleFixtures.rune("B"), BattleFixtures.rune("C")] as Array[RuneData], 0.5, 5)
		for i in rolls_before:
			state.rng.randi()
		var copy := state.clone()
		copy.units[1].hp = 0
		copy.units[2].hp = 0
		drops.append(BattleRewards.compute(copy).runes.map(func(r: RuneData) -> String: return r.display_name))
	assert_eq(drops[0], drops[1], "seeded from the battle seed, not the dice state")
