extends TestCase
## Saving and loading the profile. Heroes and runes are saved as temporary .tres files
## under user:// first, since saves reference resources by path.

const DIR := "user://test_save_store"


func _saved(resource: Resource, file: String) -> Resource:
	DirAccess.make_dir_recursive_absolute(DIR)
	var path := DIR.path_join(file)
	ResourceSaver.save(resource, path)
	return ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_REPLACE)


func _roster() -> Roster:
	var roster := Roster.new()
	for hero_name in ["Knight", "Mage", "Ranger"]:
		var hero := HeroData.new()
		hero.unit = BattleFixtures.unit(hero_name)
		roster.heroes.append(_saved(hero, "%s.tres" % hero_name.to_lower()))
	roster.config = ProgressionConfig.new()
	return roster


func _rune(rune_name: String, rarity := RuneData.Rarity.COMMON) -> RuneData:
	return _saved(BattleFixtures.rune(rune_name, rarity), "%s.tres" % rune_name.to_lower())


func _store() -> SaveStore:
	DirAccess.make_dir_recursive_absolute(DIR)
	var store := SaveStore.new(DIR.path_join("profile.json"))
	store.delete()
	return store


## Removes everything the test wrote under DIR.
func _clean() -> void:
	for file in DirAccess.get_files_at(DIR):
		DirAccess.remove_absolute(DIR.path_join(file))
	DirAccess.remove_absolute(DIR)


func _write(path: String, text: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()


func test_a_profile_survives_a_round_trip() -> void:
	var roster := _roster()
	var store := _store()
	var profile := Profile.create(roster)
	var might := _rune("Might")
	var focus := _rune("Focus", RuneData.Rarity.EPIC)
	profile.stash = [might, focus, might] as Array[RuneData]
	profile.equip(0, 1, 2)  # Focus in the Knight's slot 2.
	var rewards := BattleRewards.new()
	rewards.xp = 55
	profile.apply_rewards(rewards)
	profile.unlocked.append(2)
	profile.party = [2, 0] as Array[int]
	assert_true(store.save(profile))

	var loaded := store.load_or_create(roster)
	assert_eq([loaded.heroes[0].xp, loaded.heroes[0].level], [55, 3])
	assert_eq(loaded.heroes[0].runes[2], focus, "same resource")
	assert_eq(loaded.heroes[0].runes[0], null)
	assert_eq(loaded.stash, [might, might] as Array[RuneData])
	assert_eq(loaded.unlocked, [0, 1, 2] as Array[int])
	assert_eq(loaded.party, [2, 0] as Array[int])
	store.delete()
	_clean()

func test_no_save_starts_fresh() -> void:
	var profile := _store().load_or_create(_roster())
	assert_eq(profile.heroes[0].level, 1)
	assert_eq(profile.party, [0, 1] as Array[int])
	_clean()

func test_a_corrupt_save_starts_fresh_without_crashing() -> void:
	var store := _store()
	var file := FileAccess.open(store.path, FileAccess.WRITE)
	file.store_string("{ not json")
	file.close()
	expect_error("unreadable")
	var profile := store.load_or_create(_roster())
	assert_eq(profile.heroes[0].level, 1)
	store.delete()
	_clean()

func test_a_newer_save_starts_fresh() -> void:
	var store := _store()
	var file := FileAccess.open(store.path, FileAccess.WRITE)
	file.store_string(JSON.stringify({"version": Profile.SAVE_VERSION + 1, "heroes": []}))
	file.close()
	expect_error("save version")  # From Profile…
	expect_error("newer version")  # … and from SaveStore.
	var profile := store.load_or_create(_roster())
	assert_eq(profile.heroes[0].xp, 0)
	store.delete()
	_clean()

func test_unknown_resources_and_bad_indices_are_skipped() -> void:
	var roster := _roster()
	var might := _rune("Might")
	var data := {
		"version": 1,
		"heroes": [
			{"hero": roster.heroes[0].resource_path, "xp": 25, "runes": [might.resource_path, "res://gone.tres", null]},
			{"hero": "res://no_such_hero.tres", "xp": 999},
		],
		"unlocked": [0, 1, 7, "x"],
		"party": [0, 2],  # Hero 2 isn't unlocked: the roster's party is kept.
		"stash": ["res://gone.tres", might.resource_path],
	}
	expect_error("unknown rune")  # In the Knight's slots…
	expect_error("unknown rune")  # … and in the stash.
	expect_error("unknown hero")
	var profile := Profile.from_dict(data, roster)
	assert_eq([profile.heroes[0].xp, profile.heroes[0].level], [25, 2], "level from XP")
	assert_eq(profile.heroes[0].runes[0], might)
	assert_eq(profile.heroes[0].runes[1], null, "missing rune skipped")
	assert_eq(profile.unlocked, [0, 1] as Array[int], "bad indices dropped")
	assert_eq(profile.party, [0, 1] as Array[int])
	assert_eq(profile.stash, [might] as Array[RuneData])
	_clean()

func test_saving_overwrites_the_previous_save() -> void:
	var roster := _roster()
	var store := _store()
	var profile := Profile.create(roster)
	store.save(profile)
	profile.heroes[1].xp = 30
	store.save(profile)
	assert_eq(store.load_or_create(roster).heroes[1].xp, 30)
	assert_false(FileAccess.file_exists(store.path + ".tmp"), "no temp file left")
	store.delete()
	_clean()


func test_an_unreadable_save_is_moved_aside_not_overwritten() -> void:
	var store := _store()
	_write(store.path, "{ not json")
	expect_error("unreadable")
	var profile := store.load_or_create(_roster())
	store.save(profile)
	var backups := Array(DirAccess.get_files_at(DIR)).filter(func(f: String) -> bool: return f.ends_with(".bak"))
	assert_eq(backups.size(), 1, "moved aside")
	assert_eq(FileAccess.get_file_as_string(DIR.path_join(backups[0])), "{ not json", "intact")
	_clean()


func test_a_newer_save_is_never_overwritten() -> void:
	var store := _store()
	var newer := JSON.stringify({"version": Profile.SAVE_VERSION + 1, "heroes": []})
	_write(store.path, newer)
	expect_error("save version")
	expect_error("newer version")
	var profile := store.load_or_create(_roster())
	expect_error("not overwriting")
	assert_false(store.save(profile))
	assert_eq(FileAccess.get_file_as_string(store.path), newer, "left alone")
	_clean()


func test_malformed_fields_are_skipped_without_errors() -> void:
	var roster := _roster()
	var data := {"version": "two", "heroes": [{"hero": roster.heroes[0].resource_path, "xp": "lots", "runes": "x"}, 7],
			"unlocked": 3, "party": {"a": 1}, "stash": null}
	var profile := Profile.from_dict(data, roster)
	assert_eq(profile.heroes[0].xp, 0)
	assert_eq(profile.unlocked, [0, 1] as Array[int])
	assert_eq(profile.party, [0, 1] as Array[int])
	_clean()


func test_party_and_unlocks_follow_heroes_when_the_roster_is_reordered() -> void:
	var roster := _roster()
	var profile := Profile.create(roster)
	profile.unlocked.append(2)
	profile.party = [2, 0] as Array[int]  # Ranger, Knight.
	var data := profile.to_dict()
	var reordered := Roster.new()
	reordered.heroes = [roster.heroes[2], roster.heroes[0], roster.heroes[1]] as Array[HeroData]
	reordered.config = roster.config
	var loaded := Profile.from_dict(data, reordered)
	assert_eq(loaded.party, [0, 1] as Array[int], "still the Ranger then the Knight")
	assert_eq(loaded.heroes[loaded.party[0]].hero, roster.heroes[2])
	assert_true(loaded.is_unlocked(0) and loaded.is_unlocked(1) and loaded.is_unlocked(2))
	_clean()


func test_duplicate_party_entries_are_dropped() -> void:
	var roster := _roster()
	var data := {"version": 2, "party": [roster.heroes[0].resource_path, roster.heroes[0].resource_path]}
	assert_eq(Profile.from_dict(data, roster).party, [0] as Array[int])
	_clean()


func test_new_starting_unlocks_reach_old_saves() -> void:
	var roster := _roster()
	var data := {"version": 2, "unlocked": [roster.heroes[0].resource_path]}
	assert_eq(Profile.from_dict(data, roster).unlocked, [0, 1] as Array[int], "the roster's starting unlocks stay")
	_clean()
