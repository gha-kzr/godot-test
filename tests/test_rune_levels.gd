extends TestCase
## Rune levels: scaling, naming, the one-per-hero rule across levels, how depth sets the level of a
## drop, and saving a leveled rune.

const MIGHT := "res://data/runes/might.tres"      # +8 Power
const FOCUS := "res://data/runes/focus.tres"      # +1 AP, +5 Power
const SWIFTNESS := "res://data/runes/swiftness.tres"  # epic


func _rune(path: String) -> RuneData:
	return load(path) as RuneData


func test_level_one_is_the_file_itself_and_levels_scale_the_amounts() -> void:
	var might := _rune(MIGHT)
	assert_true(RuneData.leveled(might, 1) == might, "level 1 is the file")
	var third := RuneData.leveled(might, 3)
	assert_eq(third.level, 3)
	assert_eq(third.modifiers[0].amount, 11, "8 x 1.4")
	assert_eq(RuneData.leveled(might, 10).modifiers[0].amount, 22, "8 x 2.8")
	assert_eq(might.modifiers[0].amount, 8, "the file is untouched")
	assert_true(third.origin() == might)
	assert_eq(RuneData.leveled(might, 99).level, RuneData.MAX_LEVEL, "capped")
	assert_eq(RuneData.leveled(third, 2).level, 2, "from a copy, by its file")


func test_ap_and_mp_stay_flat_and_negative_amounts_grow_in_size() -> void:
	var focus := RuneData.leveled(_rune(FOCUS), 6)
	for modifier in focus.modifiers:
		if modifier.stat == StatModifier.Stat.AP:
			assert_eq(modifier.amount, 1, "AP does not scale")
		else:
			assert_eq(modifier.amount, 10, "Power 5 x 2")
	var shield := StatModifier.new()
	shield.stat = StatModifier.Stat.DAMAGE_TAKEN_PERCENT
	shield.amount = -10
	assert_eq(RuneData.scaled_amount(shield, 6), -20)
	shield.amount = -1
	assert_eq(RuneData.scaled_amount(shield, 2), -1, "never below the base size")


func test_kind_title_salvage_and_fuse_numbers() -> void:
	var might := _rune(MIGHT)
	var third := RuneData.leveled(might, 3)
	assert_true(third.is_same_kind(RuneData.leveled(might, 3)))
	assert_false(third.is_same_kind(might))
	assert_false(might.is_same_kind(_rune(FOCUS)))
	assert_eq(might.title(), might.display_name)
	assert_true(third.title().contains("3"))
	assert_eq(third.salvage_value(), RuneData.SALVAGE_ESSENCE[might.rarity] * 3)
	assert_eq(third.fuse_cost(), 20, "5 x the target level")
	assert_eq(RuneData.leveled(might, 10).fuse_cost(), 0, "nothing above the top")


func test_depth_sets_the_drop_level_with_a_little_luck() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var shallow := {}
	var deep := {}
	for i in 200:
		shallow[RuneData.level_for_enemy(3, rng)] = true
		deep[RuneData.level_for_enemy(29, rng)] = true
	assert_eq(shallow.keys().size(), 2, "level 1 or a lucky 2")
	assert_true(shallow.has(1) and shallow.has(2))
	assert_true(deep.has(6) and deep.has(7) and not deep.has(5))
	assert_eq(RuneData.level_for_enemy(500, rng), RuneData.MAX_LEVEL)


func test_one_per_hero_holds_across_levels() -> void:
	var profile := Profile.create(load("res://data/progression/roster.tres") as Roster)
	var swiftness := _rune(SWIFTNESS)
	profile.stash.append(swiftness)
	profile.stash.append(RuneData.leveled(swiftness, 4))
	assert_eq(profile.equip(0, 0), "")
	assert_false(profile.equip(0, 0).is_empty(), "the level 4 copy is the same epic rune")


func test_leveled_runes_survive_a_save() -> void:
	var roster := load("res://data/progression/roster.tres") as Roster
	var profile := Profile.create(roster)
	profile.stash.append(RuneData.leveled(_rune(MIGHT), 4))
	profile.stash.append(_rune(FOCUS))
	profile.stash.append(RuneData.leveled(_rune(FOCUS), 2))
	profile.heroes[0].runes[0] = RuneData.leveled(_rune(MIGHT), 7)
	var loaded := Profile.from_dict(JSON.parse_string(JSON.stringify(profile.to_dict())), roster)
	assert_eq(loaded.stash.size(), 3)
	assert_eq(loaded.stash[0].level, 4)
	assert_true(loaded.stash[0].origin() == _rune(MIGHT))
	assert_eq(loaded.stash[0].modifiers[0].amount, 13, "scaled again on load")
	assert_true(loaded.stash[1] == _rune(FOCUS), "a level 1 rune is the file")
	assert_eq(loaded.stash[2].level, 2)
	assert_eq(loaded.heroes[0].runes[0].level, 7)


func _profile_with(runes: Array[RuneData], essence := 0) -> Profile:
	var profile := Profile.create(load("res://data/progression/roster.tres") as Roster)
	profile.stash.assign(runes)
	profile.essence = essence
	return profile


func test_salvaging_gives_essence_by_rarity_and_level() -> void:
	var might := _rune(MIGHT)
	var profile := _profile_with([might, RuneData.leveled(might, 3), _rune(SWIFTNESS)])
	assert_eq(profile.salvage_rune(1), "")
	assert_eq(profile.essence, might.salvage_value() * 3)
	assert_eq(profile.stash.size(), 2)
	assert_eq(profile.salvage_rune(1), "")  # The epic one.
	assert_eq(profile.essence, might.salvage_value() * 3 + RuneData.SALVAGE_ESSENCE[RuneData.Rarity.EPIC])
	assert_false(profile.salvage_rune(7).is_empty(), "no such rune")


func test_three_identical_runes_and_essence_fuse_into_the_next_level() -> void:
	var might := _rune(MIGHT)
	var focus := _rune(FOCUS)
	var profile := _profile_with([might, focus, might, RuneData.leveled(might, 2), might], 10)
	assert_eq(profile.fuse_group(0), [0, 2, 4] as Array[int])
	assert_eq(profile.fuse_group(3), [] as Array[int], "a lone level 2")
	assert_eq(profile.fuse_error(0), "")
	assert_eq(profile.fuse(0), "")
	assert_eq(profile.essence, 0, "level 2 costs 10")
	assert_eq(profile.stash.size(), 3)
	assert_eq(profile.stash[0].level, 2, "the result takes the first copy's place")
	assert_true(profile.stash[0].origin() == might)
	assert_true(profile.stash[1] == focus, "the others stay")


func test_a_fuse_needs_copies_essence_and_room_to_grow() -> void:
	var might := _rune(MIGHT)
	var profile := _profile_with([might, might], 99)
	assert_false(profile.fuse(0).is_empty(), "two copies are not enough")
	profile.stash.append(might)
	profile.essence = 9
	assert_true(profile.fuse_error(0).contains("10"), "the cost is named")
	assert_eq(profile.stash.size(), 3, "a refused fuse changes nothing")
	var top := RuneData.leveled(might, RuneData.MAX_LEVEL)
	var capped := _profile_with([top, top, top], 999)
	assert_false(capped.fuse(0).is_empty(), "nothing above the top level")


func test_essence_is_saved() -> void:
	var roster := load("res://data/progression/roster.tres") as Roster
	var profile := Profile.create(roster)
	profile.essence = 42
	var loaded := Profile.from_dict(JSON.parse_string(JSON.stringify(profile.to_dict())), roster)
	assert_eq(loaded.essence, 42)
