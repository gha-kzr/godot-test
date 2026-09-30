extends TestCase
## The run screen: floor strip, party HP, report with learned spells, focusable buttons.

const SCENE := preload("res://scenes/game/run_screen.tscn")


func _tower() -> TowerConfig:
	return load("res://data/tower/tower.tres") as TowerConfig


func _profile_on_floor(floor_number: int) -> Profile:
	var profile := Profile.create(load("res://data/progression/roster.tres") as Roster)
	RunDirector.start_tower(profile, _tower(), 1)
	profile.run.floor_number = floor_number
	return profile


func _screen(profile: Profile, report: RunDirector.Report = null, title := "Floor cleared") -> RunScreen:
	var screen := SCENE.instantiate() as RunScreen
	(Engine.get_main_loop() as SceneTree).root.add_child(screen)
	screen.show_report(report if report != null else RunDirector.Report.new(), profile, title)
	return screen


func test_the_floor_strip_marks_cleared_next_elite_and_boss_floors() -> void:
	var screen := _screen(_profile_on_floor(5))
	var strip := screen.get_node("%FloorStrip")
	assert_eq(strip.get_child_count(), FloorStrip.WINDOW)
	assert_eq(strip.get_child(0).name, &"Floor1")
	assert_eq(strip.get_node("Floor4").self_modulate, FloorStrip.CLEARED_TINT)
	assert_eq(strip.get_node("Floor5").theme_type_variation, &"ChipActive", "the next floor")
	assert_true(strip.find_child("EliteMark", true, false).get_parent().get_parent().get_parent().name == &"Floor5", "floor 5 is an elite")
	assert_true(strip.get_node("Floor10").find_child("BossMark", true, false) != null, "floor 10 is a boss")
	assert_true(strip.get_node("Floor6").find_child("BossMark", true, false) == null)
	screen.free()


func test_the_strip_scrolls_with_the_run() -> void:
	var screen := _screen(_profile_on_floor(17))
	var strip := screen.get_node("%FloorStrip")
	assert_eq(strip.get_child(0).name, &"Floor13", "four cleared floors stay in view")
	assert_true(strip.find_child("Floor17", true, false) != null)
	screen.free()


func test_the_party_shows_its_hp() -> void:
	var profile := _profile_on_floor(2)
	profile.run.hero_hp = [10, -1, 5] as Array[int]
	var screen := _screen(profile)
	var chips := screen.get_node("%PartyHpRow").get_children()
	assert_eq(chips.size(), 3)
	assert_eq((chips[0].find_child("HpLabel", true, false) as Label).text, "10 / %d HP" % RunDirector.max_hp(profile, 0))
	assert_eq((chips[1].find_child("HpLabel", true, false) as Label).text.split(" / ")[0], str(RunDirector.max_hp(profile, 1)), "-1 is full HP")
	assert_true((chips[0].find_child("NameLabel", true, false) as Label).text.contains("Lv 1"))
	screen.free()


func test_a_level_up_lists_the_spells_it_unlocks() -> void:
	var profile := _profile_on_floor(2)
	var report := RunDirector.Report.new()
	report.rewards = BattleRewards.new()
	report.level_ups = [Profile.LevelUp.new(0, 2, 3), Profile.LevelUp.new(1, 1, 2)] as Array[Profile.LevelUp]
	var hero := profile.heroes[0].hero
	var learned := hero.reward_for(3).spells
	assert_true(not learned.is_empty(), "the fixture hero learns a spell at level 3")
	var screen := _screen(profile, report)
	var lines := (screen.get_node("%Lines") as Label).text
	assert_true(lines.contains("%s reached level 3 and learned %s." % [hero.display_name(), learned[0].display_name]), lines)
	assert_false(lines.contains("Mage reached level 2 and"), "no spell at level 2: just the level")
	screen.free()


func test_a_stage_run_has_no_floor_strip_and_the_run_end_no_party() -> void:
	var profile := _profile_on_floor(1)
	profile.run.mode = RunState.Mode.STAGE
	profile.run.stage = _tower().stages[0]
	var screen := _screen(profile)
	assert_false((screen.get_node("%FloorStrip") as Control).visible)
	screen.free()
	profile.run = null
	screen = _screen(profile)
	assert_false((screen.get_node("%PartyHpRow") as Control).visible)
	assert_false((screen.get_node("%Boons") as Control).visible)
	screen.free()


func test_buttons_take_focus_and_esc_does_not_leave() -> void:
	var profile := _profile_on_floor(3)
	var screen := _screen(profile)
	var next := screen.find_child("NextButton", true, false) as Button
	assert_eq(next.focus_mode, Control.FOCUS_ALL)
	var backs := {"count": 0}
	screen.back_pressed.connect(func() -> void: backs.count += 1)
	var escape := InputEventAction.new()
	escape.action = &"ui_cancel"
	escape.pressed = true
	screen._unhandled_input(escape)
	assert_eq(backs.count, 0, "leaving the run is an explicit choice")
	screen.free()


func test_the_party_button_asks_for_the_hub_between_floors_only() -> void:
	var screen := _screen(_profile_on_floor(3))
	var requests := {"count": 0}
	screen.party_pressed.connect(func() -> void: requests.count += 1)
	(screen.find_child("PartyButton", true, false) as Button).pressed.emit()
	assert_eq(requests.count, 1)
	screen.free()
	var profile := _profile_on_floor(11)
	profile.run.choice_pending = true
	screen = _screen(profile)
	assert_true(screen.find_child("PartyButton", true, false) != null, "also at a boss choice")
	screen.free()
	profile.run = null
	screen = _screen(profile)
	assert_true(screen.find_child("PartyButton", true, false) == null, "no run, no party button: Back is there")
	screen.free()


func test_the_party_chips_carry_a_thin_xp_bar() -> void:
	var profile := _profile_on_floor(2)
	profile.heroes[0].xp = 10
	var screen := _screen(profile)
	var chip := screen.get_node("%PartyHpRow").get_child(0)
	var bar := chip.find_child("XpBar", true, false) as ProgressBar
	assert_eq([bar.value, bar.max_value], [10.0, 20.0])
	screen.free()


func _xp_chip(screen: RunScreen, slot := 0) -> Node:
	return screen.get_node("%PartyHpRow").get_child(slot)


func test_the_xp_bar_is_two_tone_with_the_gain_and_its_text() -> void:
	var profile := _profile_on_floor(2)
	profile.heroes[0].level = 2
	profile.heroes[0].xp = 30  # Level 2 spans 20..50: 10 of 30 now.
	var report := RunDirector.Report.new()
	report.rewards = BattleRewards.new()
	report.rewards.xp = 7
	var screen := _screen(profile, report)
	var chip := _xp_chip(screen)
	var solid := chip.find_child("XpBar", true, false) as ProgressBar
	var gain := chip.find_child("GainBar", true, false) as ProgressBar
	assert_eq([solid.value, gain.value, solid.max_value], [3.0, 10.0, 30.0], "3 before the fight, 10 now")
	assert_eq(solid.theme_type_variation, &"XpBarOverlay")
	assert_eq(gain.theme_type_variation, &"XpGainBar")
	assert_eq((chip.find_child("XpLabel", true, false) as Label).text, "XP 30 / 50 (+7)")
	screen.free()


func test_a_level_up_shows_a_full_bar_and_says_so() -> void:
	var profile := _profile_on_floor(2)
	profile.heroes[0].level = 3
	profile.heroes[0].xp = 52
	var report := RunDirector.Report.new()
	report.rewards = BattleRewards.new()
	report.rewards.xp = 27
	report.level_ups = [Profile.LevelUp.new(0, 2, 3)] as Array[Profile.LevelUp]
	var screen := _screen(profile, report)
	var chip := _xp_chip(screen)
	var solid := chip.find_child("XpBar", true, false) as ProgressBar
	assert_eq(solid.value, solid.max_value, "full")
	assert_eq((chip.find_child("XpLabel", true, false) as Label).text, "Level up! (+27 XP)")
	var other := _xp_chip(screen, 1)
	assert_false((other.find_child("XpLabel", true, false) as Label).text.begins_with("Level up"), "only the hero that levelled")
	screen.free()


func test_without_a_fight_the_text_has_no_gain() -> void:
	var profile := _profile_on_floor(2)
	profile.heroes[0].xp = 10
	var screen := _screen(profile)
	assert_eq((_xp_chip(screen).find_child("XpLabel", true, false) as Label).text, "XP 10 / 20")
	var gain := _xp_chip(screen).find_child("GainBar", true, false) as ProgressBar
	var solid := _xp_chip(screen).find_child("XpBar", true, false) as ProgressBar
	assert_eq(gain.value, solid.value, "no lighter segment")
	screen.free()


func test_a_hero_at_the_level_cap_shows_a_full_gold_bar_not_a_pale_one() -> void:
	var profile := _profile_on_floor(2)
	profile.heroes[0].level = profile.roster.config.level_cap
	profile.heroes[0].xp = 999
	var report := RunDirector.Report.new()
	report.rewards = BattleRewards.new()
	report.rewards.xp = 30
	var screen := _screen(profile, report)
	var chip := _xp_chip(screen)
	var solid := chip.find_child("XpBar", true, false) as ProgressBar
	assert_eq(solid.value, solid.max_value, "full gold: nothing left to gain")
	assert_true((chip.find_child("XpLabel", true, false) as Label).text.contains("max level"))
	screen.free()
