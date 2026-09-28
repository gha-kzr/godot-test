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
	assert_eq(config.level_for_xp(99999), 10, "capped")
	assert_eq(config.xp_for_next(1), 20)
	assert_eq(config.xp_for_next(10), -1)
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
	profile.apply_rewards(_rewards(100000))
	assert_eq(profile.heroes[0].level, 10)


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
	for i in 4:
		hero.level_rewards[i].spells = [BattleFixtures.damage_spell()] as Array[SpellData]
	assert_true(Array(hero.get_validation_errors()).any(func(e: String) -> bool: return "at most 4" in e))
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
	assert_true(errors.any(func(e: String) -> bool: return "3 XP thresholds" in e))
