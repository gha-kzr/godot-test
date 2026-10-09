extends TestCase
## Every screen can be driven with arrows, Enter and Esc alone (keyboard now, gamepad later:
## both go through the same ui_* actions).


func _frame() -> void:
	await (Engine.get_main_loop() as SceneTree).process_frame


func _tap(viewport: Viewport, key: Key) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.keycode = key
		event.physical_keycode = key
		event.pressed = pressed
		viewport.push_input(event)


func _focused(screen: Node) -> Control:
	return screen.get_viewport().gui_get_focus_owner()


## Focuses the first control, then presses `key` `steps` times, returning the names of the
## controls focus visited (the start included).
func _walk(screen: Screen, key: Key, steps: int) -> Array[StringName]:
	screen.focus_first()
	await _frame()
	var visited: Array[StringName] = []
	for step in steps:
		var control := _focused(screen)
		if control != null and control.name not in visited:
			visited.append(control.name)
		_tap(screen.get_viewport(), key)
		await _frame()
	return visited


func _add(scene: PackedScene) -> Screen:
	var screen := scene.instantiate() as Screen
	(Engine.get_main_loop() as SceneTree).root.add_child(screen)
	return screen


func test_title_arrows_move_between_the_buttons_and_enter_presses() -> void:
	var screen := _add(load("res://scenes/game/title_screen.tscn")) as TitleScreen
	screen.show_title("T")
	await _frame()
	screen.focus_first()
	await _frame()
	assert_eq(_focused(screen).name, &"SoloButton")
	_tap(screen.get_viewport(), KEY_DOWN)
	await _frame()
	assert_eq(_focused(screen).name, &"MultiplayerButton")
	_tap(screen.get_viewport(), KEY_DOWN)
	await _frame()
	assert_eq(_focused(screen).name, &"SettingsButton")
	var pressed := {"settings": 0}
	screen.settings_pressed.connect(func() -> void: pressed.settings += 1)
	_tap(screen.get_viewport(), KEY_ENTER)
	await _frame()
	assert_eq(pressed.settings, 1, "Enter presses the focused button")
	screen.free()


func test_settings_can_be_walked_with_the_down_arrow() -> void:
	var screen := _add(load("res://scenes/game/settings_screen.tscn")) as SettingsScreen
	screen.show_settings(Settings.new())
	await _frame()
	var visited := await _walk(screen, KEY_DOWN, 30)
	for wanted: StringName in [&"BackButton", &"UiScale", &"Key_spell_1", &"Key_show_order", &"ResetKeysButton", &"ShowHintsButton", &"ResetSaveButton"]:
		assert_true(wanted in visited, "%s is reachable: %s" % [wanted, visited])
	SettingsApplier.reset_bindings(Settings.new())
	screen.free()


func test_hub_arrows_reach_every_column() -> void:
	var profile := Profile.create(load("res://data/progression/roster.tres") as Roster)
	profile.stash = [load("res://data/runes/might.tres")] as Array[RuneData]
	profile.heroes[0].runes[0] = load("res://data/runes/vitality.tres")
	var screen := _add(load("res://scenes/game/party_screen.tscn")) as PartyScreen
	screen.show_profile(profile, "", "", load("res://data/tower/tower.tres") as TowerConfig)
	await _frame()
	var down := await _walk(screen, KEY_DOWN, 40)
	var right := await _walk(screen, KEY_RIGHT, 12)
	var seen := down + right
	var stage_reached := seen.any(func(n: StringName) -> bool: return str(n).begins_with("Stage"))
	assert_true(stage_reached, "a stage button is reachable: %s" % [seen])
	for wanted: StringName in [&"MenuButton", &"Hero0", &"Hero1", &"TowerButton"]:
		assert_true(wanted in seen, "%s is reachable: %s" % [wanted, seen])
	assert_true(&"Stash0" in seen or &"Slot0" in seen, "the rune columns are reachable: %s" % [seen])
	screen.free()


func test_run_screen_starts_on_its_next_button_and_enter_continues() -> void:
	var profile := Profile.create(load("res://data/progression/roster.tres") as Roster)
	RunDirector.start_tower(profile, load("res://data/tower/tower.tres") as TowerConfig, 1)
	var screen := _add(load("res://scenes/game/run_screen.tscn")) as RunScreen
	screen.show_report(RunDirector.Report.new(), profile, "Floor 1 cleared")
	await _frame()
	screen.focus_first()
	await _frame()
	assert_eq(_focused(screen).name, &"NextButton")
	var continues := {"count": 0}
	screen.next_pressed.connect(func() -> void: continues.count += 1)
	_tap(screen.get_viewport(), KEY_ENTER)
	await _frame()
	assert_eq(continues.count, 1)
	screen.free()


func test_a_long_rune_stash_can_be_walked_to_its_end() -> void:
	var profile := Profile.create(load("res://data/progression/roster.tres") as Roster)
	for i in 30:
		profile.stash.append(load("res://data/runes/might.tres") as RuneData)
	var screen := _add(load("res://scenes/game/party_screen.tscn")) as PartyScreen
	screen.show_profile(profile, "", "", load("res://data/tower/tower.tres") as TowerConfig)
	await _frame()
	(screen.find_child("Stash0", true, false) as Button).grab_focus()
	for i in 29:
		_tap(screen.get_viewport(), KEY_DOWN)
		await _frame()
	assert_eq(_focused(screen).name, &"Stash29", "every rune, scrolled into view as focus moves")
	screen.free()
