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
	var heroes := screen.get_node("%HeroTabs").get_children()
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
	assert_eq((screen.find_child("XpLabel", true, false) as Label).text, "XP 30 / 50")
	var stats := (screen.find_child("Stats", true, false) as Label).text
	assert_true(stats.contains("HP 49"), "44 + 5 from level 2: %s" % stats)
	assert_true(stats.contains("Power +2%"), stats)
	assert_true(stats.contains("Fire +25%"), stats)
	var slot := screen.find_child("Slot1", true, false) as Button
	assert_eq(slot.text, "Fire Ward Rune")
	assert_true((screen.find_child("Slot0", true, false) as Button).disabled, "empty slot")
	screen.free()


func test_selecting_a_hero_switches_the_details() -> void:
	var screen := _screen(_profile())
	(screen.find_child("Hero1", true, false) as Button).pressed.emit()
	assert_eq(screen.selected_hero, 1)
	var title := screen.find_child("HeroTitle", true, false) as Label
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
	(screen.find_child("Stash1", true, false) as Button).pressed.emit()
	(screen.find_child("Slot4", true, false) as Button).pressed.emit()
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
	assert_true((screen.find_child("Stage0", true, false) as Button).text.ends_with("(cleared)"), "cleared")
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
	assert_true((screen.get_node("%DestinationBar").get_child(0) as Label).text.contains("floor 7"))
	screen.free()


func _frame() -> void:
	await (Engine.get_main_loop() as SceneTree).process_frame


func test_every_hub_button_takes_keyboard_focus() -> void:
	var profile := _profile()
	profile.stash = [load("res://data/runes/might.tres")] as Array[RuneData]
	profile.heroes[0].runes[0] = load("res://data/runes/vitality.tres")
	var screen := PARTY_SCENE.instantiate() as PartyScreen
	(Engine.get_main_loop() as SceneTree).root.add_child(screen)
	screen.show_profile(profile, "", "", _tower())
	var nodes: Array[Node] = [screen]
	var buttons := 0
	while not nodes.is_empty():
		var node: Node = nodes.pop_back()
		if node is TutorialOverlay:
			continue  # Its Skip link must not take the keyboard focus the spotlight blocks.
		nodes.append_array(node.get_children())
		if node is BaseButton or node is OptionButton:
			buttons += 1
			assert_eq((node as Control).focus_mode, Control.FOCUS_ALL, "%s takes focus" % node.name)
	assert_true(buttons > 10, "the hub's buttons were checked")
	screen.free()


func test_spells_are_listed_and_a_click_shows_the_description() -> void:
	var screen := _screen(_profile())
	var spells := screen.find_child("Spells", true, false)
	assert_true(spells.get_child_count() >= 2, "the hero's spells")
	var first := spells.get_child(0) as Button
	assert_true(first.icon != null, "with its icon")
	var info := screen.find_child("SpellInfo", true, false) as Label
	assert_eq(info.text, "")
	first.pressed.emit()
	assert_true(info.text.contains("AP") and info.text.contains("Range"), info.text)
	screen.free()


func test_the_title_button_asks_to_go_back() -> void:
	var screen := _screen(_profile())
	var backs := {"count": 0}
	screen.back_pressed.connect(func() -> void: backs.count += 1)
	(screen.get_node("%MenuButton") as Button).pressed.emit()
	assert_eq(backs.count, 1)
	screen.free()


func test_selecting_a_hero_keeps_focus_and_reports_it() -> void:
	var screen := _screen(_profile())
	var picks: Array[int] = []
	screen.hero_selected.connect(func(index: int) -> void: picks.append(index))
	var tab := screen.find_child("Hero1", true, false) as Button
	tab.grab_focus()
	tab.pressed.emit()
	await _frame()
	assert_eq(picks, [1] as Array[int])
	assert_eq(screen.get_viewport().gui_get_focus_owner(), tab, "the tab isn't rebuilt under the player")
	assert_true(tab.button_pressed)
	screen.free()


func test_focus_returns_to_the_rebuilt_button_after_a_change() -> void:
	var profile := _profile()
	profile.stash = [load("res://data/runes/might.tres"), load("res://data/runes/focus.tres")] as Array[RuneData]
	var screen := _screen(profile)
	(screen.find_child("Stash0", true, false) as Button).grab_focus()
	profile.stash.remove_at(0)  # As after an equip.
	screen.show_profile(profile)
	await _frame()
	await _frame()
	var focused := screen.get_viewport().gui_get_focus_owner()
	assert_true(focused != null and focused.name == &"Stash0", "focus is back on the list")
	screen.free()


func test_xp_shows_on_the_tabs_and_inside_a_gold_bar_in_the_panel() -> void:
	var profile := _profile()
	profile.heroes[0].xp = 30
	profile.heroes[0].level = 2
	var screen := _screen(profile)
	var tab_bar := screen.find_child("Hero0", true, false).get_node("XpBar") as ProgressBar
	assert_eq([tab_bar.value, tab_bar.max_value], [10.0, 30.0])
	assert_eq(tab_bar.theme_type_variation, &"XpBar")
	var bar := screen.get_node("%HeroPanel").find_child("XpBar", true, false) as ProgressBar
	assert_eq([bar.value, bar.max_value], [10.0, 30.0], "the panel's bar")
	assert_true(bar.find_child("XpLabel", true, false) != null, "with its text drawn inside")
	assert_true(bar.custom_minimum_size.y >= 20.0, "tall enough to read")
	screen.free()


func test_hp_shows_above_the_xp_bar_on_the_tabs_and_in_the_panel() -> void:
	var profile := _profile()
	RunDirector.start_tower(profile, _tower(), 1)
	profile.run.hero_hp[0] = 12
	var screen := PARTY_SCENE.instantiate() as PartyScreen
	(Engine.get_main_loop() as SceneTree).root.add_child(screen)
	screen.show_profile(profile, "", "", _tower())
	var tab := screen.find_child("Hero0", true, false)
	var tab_hp := tab.get_node("HpBar") as ProgressBar
	assert_eq([tab_hp.value, tab_hp.max_value], [12.0, float(RunDirector.max_hp(profile, 0))])
	assert_true(tab_hp.offset_top < tab.get_node("XpBar").offset_top, "HP sits above XP on the tab")
	var panel := screen.get_node("%HeroPanel")
	var hp := panel.find_child("HpBar", true, false) as ProgressBar
	assert_eq(hp.value, 12.0)
	assert_eq((hp.find_child("HpLabel", true, false) as Label).text, "HP 12 / %d" % RunDirector.max_hp(profile, 0))
	assert_true(hp.get_index() < panel.find_child("XpBar", true, false).get_index(), "HP above XP in the panel")
	screen.free()


func _stash_profile() -> Profile:
	var profile := _profile()
	profile.stash = [load("res://data/runes/might.tres"), load("res://data/runes/focus.tres"), load("res://data/runes/vitality.tres")] as Array[RuneData]
	return profile


func test_drop_turns_a_row_into_an_inline_question_and_yes_asks_the_game() -> void:
	var screen := _screen(_stash_profile())
	var drops: Array[int] = []
	screen.drop_requested.connect(func(index: int) -> void: drops.append(index))
	(screen.find_child("Drop1", true, false) as Button).pressed.emit()
	var question := screen.find_child("DropQuestion1", true, false) as Label
	assert_eq(question.text, "Drop %s?" % load("res://data/runes/focus.tres").display_name)
	assert_true(screen.find_child("Stash1", true, false) == null, "that row shows the question instead of the rune")
	assert_true(screen.find_child("Stash0", true, false) != null and screen.find_child("Drop0", true, false) != null, "other rows are untouched")
	assert_eq(screen.get_viewport().gui_get_focus_owner().name, &"DropNo1", "the safe answer is focused")
	assert_eq(drops.size(), 0, "asking isn't dropping")
	(screen.find_child("DropYes1", true, false) as Button).pressed.emit()
	assert_eq(drops, [1] as Array[int])
	screen.free()


func test_no_puts_the_rune_back_and_keeps_the_focus_on_its_drop_button() -> void:
	var screen := _screen(_stash_profile())
	var drops := {"count": 0}
	screen.drop_requested.connect(func(_index: int) -> void: drops.count += 1)
	(screen.find_child("Drop2", true, false) as Button).pressed.emit()
	(screen.find_child("DropNo2", true, false) as Button).pressed.emit()
	assert_true(screen.find_child("Stash2", true, false) != null and screen.find_child("DropQuestion2", true, false) == null)
	assert_eq(screen.get_viewport().gui_get_focus_owner().name, &"Drop2")
	assert_eq(drops.count, 0)
	screen.free()


func test_focus_lands_on_the_next_rune_after_a_drop() -> void:
	var profile := _stash_profile()
	var screen := _screen(profile)
	(screen.find_child("Drop2", true, false) as Button).pressed.emit()
	(screen.find_child("DropYes2", true, false) as Button).pressed.emit()
	profile.drop_rune(2)  # What the Game does, then it shows the profile again.
	screen.show_profile(profile)
	await _frame()
	await _frame()
	var focused := screen.get_viewport().gui_get_focus_owner()
	assert_true(focused != null and focused.name == &"Stash1", "the last rune is gone: focus goes to the new last one")
	screen.free()


func test_the_drop_question_stays_with_its_rune_when_the_stash_changes_elsewhere() -> void:
	var profile := _stash_profile()
	var screen := _screen(profile)
	(screen.find_child("Drop2", true, false) as Button).pressed.emit()
	assert_true(screen.find_child("DropQuestion2", true, false) != null)
	var asked := profile.stash[2]
	profile.stash.remove_at(0)  # E.g. an equip of the first rune.
	screen.show_profile(profile)
	assert_true(screen.find_child("DropQuestion1", true, false) != null, "the question moved up with its rune")
	assert_eq((screen.find_child("DropQuestion1", true, false) as Label).text, "Drop %s?" % asked.display_name)
	assert_true(screen.find_child("DropQuestion2", true, false) == null)
	profile.stash.erase(asked)  # The asked rune itself left the list.
	screen.show_profile(profile)
	assert_true(screen.find_child("DropYes0", true, false) == null and screen.find_child("DropYes1", true, false) == null, "no stale question")
	screen.free()


func test_a_question_about_a_rune_that_left_doesnt_come_back_with_a_copy_of_it() -> void:
	var profile := _stash_profile()
	var screen := _screen(profile)
	(screen.find_child("Drop0", true, false) as Button).pressed.emit()
	var asked := profile.stash[0]
	profile.stash.remove_at(0)
	screen.show_profile(profile)  # The asked rune is gone.
	profile.stash.append(asked)  # Found again later: the same resource.
	screen.show_profile(profile)
	assert_true(screen.find_child("DropYes2", true, false) == null, "a new rune is not the one that was asked about")
	screen.free()
