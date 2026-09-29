extends TestCase
## The party screen shows the profile and asks the Game to change it through signals.

const PARTY_SCENE := preload("res://scenes/game/party_screen.tscn")


func _screen(profile: Profile, summary := "") -> PartyScreen:
	var screen := PARTY_SCENE.instantiate() as PartyScreen
	(Engine.get_main_loop() as SceneTree).root.add_child(screen)
	screen.show_profile(profile, summary)
	return screen


func _profile() -> Profile:
	return Profile.create(load("res://data/progression/roster.tres") as Roster)


func test_lists_heroes_and_shows_a_locked_one() -> void:
	var profile := _profile()
	profile.unlocked = [0, 1] as Array[int]
	var screen := _screen(profile)
	var heroes := screen.get_node("%HeroList").get_children()
	assert_eq(heroes.size(), 3)
	assert_true((heroes[0] as Button).text.begins_with("Knight  Lv 1"))
	assert_true((heroes[2] as Button).disabled, "a locked hero")
	assert_eq((heroes[2] as Button).text, "Ranger (locked)")
	screen.free()


func test_details_show_level_xp_stats_spells_and_runes() -> void:
	var profile := _profile()
	profile.heroes[0].xp = 30
	profile.heroes[0].level = 2
	profile.heroes[0].runes[1] = load("res://data/runes/fire_ward.tres")
	var screen := _screen(profile)
	var details := screen.get_node("%Details")
	assert_eq((details.get_node("XpLabel") as Label).text, "XP 30 / 50")
	var stats := (details.get_node("Stats") as Label).text
	assert_true(stats.contains("HP 44"), "40 + 4 from level 2: %s" % stats)
	assert_true(stats.contains("Power +2%"), stats)
	assert_true(stats.contains("Fire +25%"), stats)
	var slot := screen.get_node("%RuneSlots").get_node("Slot1") as Button
	assert_eq(slot.text, "Fire Ward Rune")
	assert_true((screen.get_node("%RuneSlots").get_node("Slot0") as Button).disabled, "empty slot")
	screen.free()


func test_selecting_a_hero_switches_the_details() -> void:
	var screen := _screen(_profile())
	(screen.get_node("%HeroList").get_node("Hero1") as Button).pressed.emit()
	assert_eq(screen.selected_hero, 1)
	await (Engine.get_main_loop() as SceneTree).process_frame
	var title := screen.get_node("%Details").get_child(0) as Label
	assert_true(title.text.begins_with("Mage"), title.text)
	screen.free()


func test_stash_and_slot_clicks_ask_the_game() -> void:
	var profile := _profile()
	profile.stash = [load("res://data/runes/might.tres"), load("res://data/runes/focus.tres")] as Array[RuneData]
	profile.heroes[1].runes[4] = load("res://data/runes/vitality.tres")
	var screen := _screen(profile)
	var requests: Array = []
	screen.equip_requested.connect(func(hero: int, index: int) -> void: requests.append(["equip", hero, index]))
	screen.unequip_requested.connect(func(hero: int, slot: int) -> void: requests.append(["unequip", hero, slot]))
	screen.select_hero(1)
	(screen.get_node("%Stash").get_node("Stash1") as Button).pressed.emit()
	(screen.get_node("%RuneSlots").get_node("Slot4") as Button).pressed.emit()
	assert_eq(requests, [["equip", 1, 1], ["unequip", 1, 4]])
	assert_eq(profile.stash.size(), 2, "the screen itself changes nothing")
	screen.free()


func test_summary_and_messages() -> void:
	var screen := _screen(_profile(), "Victory! +27 XP for each hero.")
	var summary := screen.get_node("%Summary") as Label
	assert_true(summary.visible)
	assert_eq(summary.text, "Victory! +27 XP for each hero.")
	screen.show_profile(screen._profile, "", "")
	assert_false(summary.visible)
	screen.free()


func _tower() -> TowerConfig:
	return load("res://data/tower/tower.tres") as TowerConfig


func test_the_hub_asks_for_a_tower_run_or_a_stage() -> void:
	var profile := _profile()
	profile.cleared_stages.append(_tower().stages[0])
	var screen := PARTY_SCENE.instantiate() as PartyScreen
	(Engine.get_main_loop() as SceneTree).root.add_child(screen)
	screen.show_profile(profile, "", "", _tower())
	var requests: Array = []
	screen.tower_pressed.connect(func(start: int) -> void: requests.append(["tower", start]))
	screen.stage_pressed.connect(func(index: int) -> void: requests.append(["stage", index]))
	(screen.find_child("TowerButton", true, false) as Button).pressed.emit()
	(screen.find_child("Stage1", true, false) as Button).pressed.emit()
	assert_eq(requests, [["tower", 11], ["stage", 1]], "the highest starting floor by default")
	assert_true((screen.find_child("Stage0", true, false) as Button).text.ends_with("✓"), "cleared")
	assert_true((screen.find_child("Stage2", true, false) as Button).disabled, "locked")
	screen.free()


func test_the_hub_offers_the_saved_run() -> void:
	var profile := _profile()
	RunDirector.start_tower(profile, _tower(), 1)
	profile.run.floor_number = 7
	var screen := PARTY_SCENE.instantiate() as PartyScreen
	(Engine.get_main_loop() as SceneTree).root.add_child(screen)
	screen.show_profile(profile, "", "", _tower())
	var requests: Array = []
	screen.continue_pressed.connect(func() -> void: requests.append("continue"))
	screen.abandon_pressed.connect(func() -> void: requests.append("abandon"))
	(screen.find_child("ContinueButton", true, false) as Button).pressed.emit()
	(screen.find_child("AbandonButton", true, false) as Button).pressed.emit()
	assert_eq(requests, ["continue", "abandon"])
	assert_eq(screen.find_child("TowerButton", true, false), null)
	assert_true((screen.get_node("%Hub").get_child(0) as Label).text.contains("floor 7"))
	screen.free()
