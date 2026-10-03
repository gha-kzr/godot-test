extends TestCase
## Hero progression and the profile: XP and levels, level rewards, runes, battle input.

const Stat := StatModifier.Stat


func _reward(hp := 3, power := 3, spells: Array[SpellData] = []) -> LevelReward:
	var reward := LevelReward.new()
	reward.modifiers = [BattleFixtures.modifier(Stat.MAX_HP, hp), BattleFixtures.modifier(Stat.POWER, power)] as Array[StatModifier]
	reward.spells = spells
	return reward


func _hero(hero_name: String, unlock: SpellData = null) -> HeroData:
	var hero := HeroData.new()
	hero.unit = BattleFixtures.unit(hero_name, 150, 3, 6, 30)
	hero.unit.spells = [BattleFixtures.damage_spell()] as Array[SpellData]
	var rewards: Array[LevelReward] = []
	for level in range(2, 11):
		var unlocked: Array[SpellData] = []
		if level == 3 and unlock != null:
			unlocked.append(unlock)
		rewards.append(_reward(3, 3, unlocked))
	hero.level_rewards = rewards
	return hero


func _profile() -> Profile:
	var roster := Roster.new()
	var bolt := BattleFixtures.damage_spell(3, 1, 4, 6)
	bolt.display_name = "Bolt"
	roster.heroes = [_hero("Knight", bolt), _hero("Mage"), _hero("Ranger")] as Array[HeroData]
	roster.starting_unlocked = [0, 1] as Array[int]
	roster.starting_party = [0, 1] as Array[int]
	roster.config = ProgressionConfig.new()
	return Profile.create(roster)


func _rewards(xp: int, runes: Array[RuneData] = []) -> BattleRewards:
	var rewards := BattleRewards.new()
	rewards.xp = xp
	rewards.runes = runes
	return rewards


func test_a_new_profile_starts_at_level_1_with_the_roster_party() -> void:
	var profile := _profile()
	assert_eq(profile.heroes.size(), 3)
	assert_eq(profile.party, [0, 1] as Array[int])
	assert_true(profile.is_unlocked(1))
	assert_false(profile.is_unlocked(2), "the third hero starts locked")
	for record in profile.heroes:
		assert_eq([record.level, record.xp, record.runes.size()], [1, 0, 6])


func test_xp_curve_and_cap() -> void:
	var config := ProgressionConfig.new()
	assert_eq(config.level_for_xp(0), 1)
	assert_eq(config.level_for_xp(19), 1)
	assert_eq(config.level_for_xp(20), 2)
	assert_eq(config.level_for_xp(95), 4)
	assert_eq(config.level_for_xp(99999999), config.level_cap, "capped")
	assert_eq(config.xp_for_next(1), 20)
	assert_eq(config.xp_for_next(4), roundi(config.curve_coefficient * pow(4, config.curve_exponent)), "past the hand-set levels the curve takes over")
	assert_eq(config.xp_for_next(config.level_cap), -1)
	assert_eq(config.get_validation_errors(), PackedStringArray())


func test_rewards_give_full_xp_to_every_party_hero_and_report_level_ups() -> void:
	var profile := _profile()
	var level_ups := profile.apply_rewards(_rewards(55))
	assert_eq([profile.heroes[0].xp, profile.heroes[1].xp, profile.heroes[2].xp], [55, 55, 0], "not the hero outside the party")
	assert_eq(level_ups.size(), 2)
	assert_eq([level_ups[0].hero_index, level_ups[0].from_level, level_ups[0].to_level], [0, 1, 3], "two levels at once")
	assert_eq(profile.apply_rewards(_rewards(5)).size(), 0, "no level-up: nothing reported")


func test_levels_stop_at_the_cap() -> void:
	var profile := _profile()
	profile.roster.config.level_cap = 10
	profile.apply_rewards(_rewards(100000))
	assert_eq(profile.heroes[0].level, 10)
	profile.roster.config.level_cap = 100
	profile.heroes[0].xp = 100000000
	profile.apply_rewards(_rewards(1))
	assert_eq(profile.heroes[0].level, 100, "the real cap")


func test_level_rewards_become_permanent_modifiers_and_spells() -> void:
	var profile := _profile()
	var knight := profile.heroes[0]
	assert_eq(knight.modifiers().size(), 0, "level 1: nothing yet")
	assert_eq(knight.spells().size(), 1)
	profile.apply_rewards(_rewards(50))  # Level 3.
	assert_eq(knight.modifiers().size(), 4, "levels 2 and 3, 2 modifiers each")
	assert_eq(knight.spells().map(func(s: SpellData) -> String: return s.display_name), ["Hit", "Bolt"])
	assert_eq(knight.hero.unit.spells.size(), 1, "the template's kit is untouched")


func test_the_party_becomes_battle_input() -> void:
	var profile := _profile()
	profile.apply_rewards(_rewards(50))
	profile.stash = [BattleFixtures.rune("Might", RuneData.Rarity.COMMON, [BattleFixtures.modifier(Stat.POWER, 10)] as Array[StatModifier])] as Array[RuneData]
	assert_eq(profile.equip(0, 0), "")
	var map := MapData.new()
	map.layout = "0p 0p 0e"
	var state := BattleState.create(map.parse(), profile.battle_units(), [BattleFixtures.unit("E0", 100)] as Array[UnitData], 1,
			profile.battle_modifiers())
	var knight := state.units[0]
	assert_eq(knight.max_hp(), 36, "30 + 3 + 3")
	assert_eq(knight.hp, 36, "starts full")
	assert_eq(knight.power(), 16, "3 + 3 from levels, 10 from the rune")
	assert_eq(knight.data.spells.size(), 2, "unlocked spell included")
	assert_eq(state.units[1].power(), 6, "the Mage: levels only")


func test_equip_and_unequip_move_runes_between_stash_and_slots() -> void:
	var profile := _profile()
	var might := BattleFixtures.rune("Might")
	profile.stash = [might] as Array[RuneData]
	assert_eq(profile.equip(0, 0, 3), "")
	assert_eq(profile.heroes[0].runes[3], might)
	assert_eq(profile.stash.size(), 0)
	assert_eq(profile.unequip(0, 3), "")
	assert_eq(profile.stash, [might] as Array[RuneData])
	assert_eq(profile.heroes[0].runes[3], null)


func test_common_runes_stack_but_epic_ones_are_unique() -> void:
	var profile := _profile()
	var common := BattleFixtures.rune("Might", RuneData.Rarity.COMMON)
	var epic := BattleFixtures.rune("Focus", RuneData.Rarity.EPIC)
	profile.stash = [common, common, epic, epic] as Array[RuneData]
	assert_eq(profile.equip(0, 0), "")
	assert_eq(profile.equip(0, 0), "", "a second common copy is fine")
	assert_eq(profile.equip(0, 0), "")
	assert_true(profile.equip(0, 0).contains("one per hero"), "a second epic copy is refused")
	assert_eq(profile.stash.size(), 1, "the refused rune stays in the stash")
	assert_eq(profile.equip(1, 0), "", "another hero can wear it")


func test_equip_errors() -> void:
	var profile := _profile()
	profile.stash = [BattleFixtures.rune("Might")] as Array[RuneData]
	assert_ne(profile.equip(2, 0), "", "locked hero")
	assert_ne(profile.equip(0, 5), "", "no such rune")
	for slot in HeroRecord.RUNE_SLOTS:
		profile.heroes[0].runes[slot] = BattleFixtures.rune("Filler")
	assert_true(profile.equip(0, 0).contains("no free rune slot"))
	assert_ne(profile.equip(1, 0, 9), "", "bad slot")
	assert_ne(profile.unequip(1, 0), "", "empty slot")


func test_validation() -> void:
	var hero := _hero("Knight")
	assert_eq(hero.get_validation_errors(), PackedStringArray())
	var twice := BattleFixtures.damage_spell()
	for i in 2:
		hero.level_rewards[i].spells = [twice] as Array[SpellData]
	assert_true(Array(hero.get_validation_errors()).any(func(e: String) -> bool: return "learns Hit twice" in e))
	var roster := Roster.new()
	roster.heroes = [_hero("A")] as Array[HeroData]
	roster.starting_party = [0, 3] as Array[int]
	roster.starting_unlocked = [0] as Array[int]
	var errors := Array(roster.get_validation_errors())
	assert_true(errors.any(func(e: String) -> bool: return "no progression config" in e))
	assert_true(errors.any(func(e: String) -> bool: return "index 3 out of range" in e))
	var config := ProgressionConfig.new()
	config.xp_thresholds = [0, 10, 5] as Array[int]
	errors = Array(config.get_validation_errors())
	assert_true(errors.any(func(e: String) -> bool: return "must increase" in e))
	config.xp_thresholds = [0] as Array[int]
	config.xp_thresholds = [5] as Array[int]
	assert_true(Array(config.get_validation_errors()).any(func(e: String) -> bool: return "level 1 must need 0" in e))


func test_xp_progress_counts_from_the_current_level_and_fills_at_the_cap() -> void:
	var profile := Profile.create(load("res://data/progression/roster.tres") as Roster)
	profile.heroes[0].xp = 30
	profile.heroes[0].level = 2  # Thresholds 0, 20, 50: 10 of the 30 needed.
	assert_eq(profile.xp_progress(0), Vector2i(10, 30))
	assert_eq(profile.xp_text(0), "XP 30 / 50")
	profile.heroes[0].level = profile.roster.config.level_cap
	profile.heroes[0].xp = 999
	assert_eq(profile.xp_progress(0), Vector2i(1, 1), "a full bar at the cap")
	assert_eq(profile.xp_text(0), "XP 999 (max level)")


func test_dropping_a_rune_removes_it_for_good() -> void:
	var profile := Profile.create(load("res://data/progression/roster.tres") as Roster)
	profile.stash = [load("res://data/runes/might.tres"), load("res://data/runes/focus.tres")] as Array[RuneData]
	assert_eq(profile.drop_rune(0), "")
	assert_eq(profile.stash, [load("res://data/runes/focus.tres")] as Array[RuneData], "the other stays")
	assert_ne(profile.drop_rune(5), "", "no such rune")
	assert_ne(profile.drop_rune(-1), "")
	assert_eq(profile.stash.size(), 1, "a bad index changes nothing")


func test_the_xp_curve_is_one_smooth_rising_curve_with_a_cap_of_100() -> void:
	var config := load("res://data/progression/config.tres") as ProgressionConfig
	assert_eq(config.level_cap, 100)
	assert_eq([config.xp_for_level(2), config.xp_for_level(3), config.xp_for_level(4)], [20, 50, 90], "the first levels are hand-set")
	var last := -1
	for level in range(1, config.level_cap + 1):
		assert_true(config.xp_for_level(level) > last, "rises at level %d" % level)
		last = config.xp_for_level(level)
	assert_eq(config.level_for_xp(config.xp_for_level(57)), 57, "level_for_xp inverts it")
	assert_eq(config.level_for_xp(config.xp_for_level(57) - 1), 56)
	var steeper := config.duplicate() as ProgressionConfig
	steeper.curve_coefficient *= 2.0
	assert_true(steeper.xp_for_level(20) > config.xp_for_level(20) * 1.9, "the coefficient shifts the curve")
	assert_eq(steeper.xp_for_level(3), 50, "the hand-set levels don't move")
	var bare := ProgressionConfig.new()
	bare.xp_thresholds = [] as Array[int]
	assert_true(bare.xp_for_level(5) > bare.xp_for_level(4) and bare.xp_for_level(2) > 0, "empty table: the curve from level 2")



func _growth_hero() -> HeroData:
	var hero := _hero("Grower")
	hero.growth_reward = LevelReward.new()
	hero.growth_reward.modifiers = [BattleFixtures.modifier(StatModifier.Stat.MAX_HP, 4), BattleFixtures.modifier(StatModifier.Stat.POWER, 2)] as Array[StatModifier]
	var mp := LevelReward.new()
	mp.modifiers = [BattleFixtures.modifier(StatModifier.Stat.MP, 1)] as Array[StatModifier]
	hero.milestone_rewards = {15: mp}
	return hero


func test_levels_past_the_table_follow_the_growth_rule_and_milestones() -> void:
	var hero := _growth_hero()
	var table := hero.level_rewards.size()  # Levels 2 to table + 1.
	assert_eq(hero.reward_for(table + 1), hero.level_rewards[table - 1], "inside the table: the authored reward")
	assert_eq(hero.reward_for(1), null)
	var growth := hero.reward_for(table + 2)
	assert_eq(growth.modifiers.map(func(m: StatModifier) -> int: return m.amount), [4, 2])
	assert_eq(hero.reward_for(15).modifiers.map(func(m: StatModifier) -> int: return m.stat), [StatModifier.Stat.MAX_HP, StatModifier.Stat.POWER, StatModifier.Stat.MP], "growth plus the milestone")
	assert_eq(hero.reward_for(16).modifiers.size(), 2, "no milestone: growth only")
	var plain := _hero("Plain")
	assert_eq(plain.reward_for(table + 2), null, "no growth rule: nothing past the table")


func test_a_hero_at_a_high_level_has_the_growth_in_its_stats() -> void:
	var record := HeroRecord.new(_growth_hero())
	record.level = 20
	var hp := 0
	var mp := 0
	for modifier in record.modifiers():
		if modifier.stat == StatModifier.Stat.MAX_HP:
			hp += modifier.amount
		elif modifier.stat == StatModifier.Stat.MP:
			mp += modifier.amount
	var table := record.hero.level_rewards.size()
	var authored_hp := 0
	for reward in record.hero.level_rewards:
		for modifier in reward.modifiers:
			if modifier.stat == StatModifier.Stat.MAX_HP:
				authored_hp += modifier.amount
	assert_eq(hp, authored_hp + 4 * (20 - table - 1), "the table's HP, then 4 per level")
	assert_eq(mp, 1, "the milestone at 15, once")


func test_growth_rule_validation() -> void:
	var hero := _growth_hero()
	assert_eq(hero.get_validation_errors(), PackedStringArray())
	hero.growth_reward.spells = [BattleFixtures.damage_spell()] as Array[SpellData]
	assert_true(Array(hero.get_validation_errors()).any(func(e: String) -> bool: return "growth reward can't unlock" in e))
	hero.growth_reward.spells = [] as Array[SpellData]
	hero.milestone_rewards[3] = LevelReward.new()
	assert_true(Array(hero.get_validation_errors()).any(func(e: String) -> bool: return "inside the reward table" in e))


func test_the_shipped_heroes_keep_growing_to_the_cap() -> void:
	var roster := load("res://data/progression/roster.tres") as Roster
	for hero in roster.heroes:
		assert_true(hero.growth_reward != null, "%s has a growth rule" % hero.display_name())
		assert_eq(hero.get_validation_errors(), PackedStringArray())
		var at_10 := hero.reward_for(10).modifiers.map(func(m: StatModifier) -> int: return m.amount)
		var at_11 := hero.reward_for(11).modifiers.map(func(m: StatModifier) -> int: return m.amount)
		assert_eq(at_11, at_10, "%s: level 11 continues the rate of the table" % hero.display_name())
		var stats_10 := hero.reward_for(10).modifiers.map(func(m: StatModifier) -> int: return m.stat)
		var stats_11 := hero.reward_for(11).modifiers.map(func(m: StatModifier) -> int: return m.stat)
		assert_eq(stats_11, stats_10, "%s: the same stats, not just the same amounts" % hero.display_name())
		assert_true(hero.reward_for(15).modifiers.any(func(m: StatModifier) -> bool: return m.stat == StatModifier.Stat.MP), "+1 MP at 15")
		assert_true(hero.reward_for(20).modifiers.any(func(m: StatModifier) -> bool: return m.stat == StatModifier.Stat.AP), "+1 AP at 20")


func test_the_monotonic_guard_keeps_a_flat_curve_rising() -> void:
	var config := ProgressionConfig.new()
	config.xp_thresholds = [0, 20, 50, 90, 140, 200] as Array[int]
	config.curve_coefficient = 0.1  # The curve alone would sit far below the table.
	var last := config.xp_for_level(6)
	for level in range(7, 60):
		assert_true(config.xp_for_level(level) > last, "rises at level %d" % level)
		last = config.xp_for_level(level)
	assert_eq(config.level_for_xp(last), 59, "and level_for_xp still inverts it")


func test_the_roster_needs_a_growth_rule_when_the_cap_is_past_the_hero_table() -> void:
	var roster := load("res://data/progression/roster.tres") as Roster
	assert_eq(roster.get_validation_errors(), PackedStringArray())
	var copy := roster.duplicate_deep(Resource.DEEP_DUPLICATE_ALL) as Roster
	copy.heroes[0].growth_reward = null
	assert_true(Array(copy.get_validation_errors()).any(func(e: String) -> bool: return "no growth_reward" in e))
