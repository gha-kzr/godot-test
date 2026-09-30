extends TestCase
## Settings persist in a ConfigFile, survive bad files, and rebinding keeps the InputMap right.

const PATH := "user://test_settings/settings.cfg"


func _store() -> SettingsStore:
	DirAccess.make_dir_recursive_absolute(PATH.get_base_dir())
	var store := SettingsStore.new(PATH)
	store.delete()
	return store


func after_each_clean() -> void:
	SettingsStore.new(PATH).delete()
	DirAccess.remove_absolute(PATH.get_base_dir())
	SettingsApplier.reset_bindings(Settings.new())


func test_defaults_without_a_file() -> void:
	var settings := _store().load_or_default()
	assert_eq([settings.window_mode, settings.ui_scale, settings.bindings.size(), settings.dismissed_hints.size()],
			[Settings.WindowMode.WINDOWED, 1.0, 0, 0])


func test_settings_round_trip() -> void:
	var store := _store()
	var settings := Settings.new()
	settings.window_mode = Settings.WindowMode.FULLSCREEN
	settings.ui_scale = 1.25
	settings.bindings[&"end_turn"] = KEY_G
	settings.dismissed_hints = ["hub_intro"] as Array[String]
	assert_true(store.save(settings))
	var loaded := store.load_or_default()
	assert_eq([loaded.window_mode, loaded.ui_scale, loaded.bindings[&"end_turn"], loaded.dismissed_hints],
			[Settings.WindowMode.FULLSCREEN, 1.25, int(KEY_G), ["hub_intro"] as Array[String]])


func test_a_corrupt_file_gives_defaults_and_bad_values_fall_back_one_by_one() -> void:
	var store := _store()
	var file := FileAccess.open(PATH, FileAccess.WRITE)
	file.store_string("[display]\nui_scale=1.3\nwindow_mode=7\n[keys]\nend_turn=-5\nnot_an_action=65\nspell_1=\"x\"\n")
	file.close()
	var settings := store.load_or_default()
	assert_eq(settings.ui_scale, 1.25, "snapped to the nearest allowed scale")
	assert_eq(settings.window_mode, Settings.WindowMode.WINDOWED, "invalid mode ignored")
	assert_eq(settings.bindings.size(), 0, "negative, unknown and non-numeric bindings ignored")
	file = FileAccess.open(PATH, FileAccess.WRITE)
	file.store_string("this is [not a config")
	file.close()
	assert_eq(store.load_or_default().ui_scale, 1.0)


func test_rebinding_swaps_the_key_and_reset_restores_it() -> void:
	var settings := Settings.new()
	assert_eq(SettingsApplier.key_of(&"spell_1"), int(KEY_1), "project default")
	assert_eq(SettingsApplier.set_binding(settings, &"spell_1", KEY_Z), "")
	assert_eq(SettingsApplier.key_of(&"spell_1"), int(KEY_Z))
	assert_eq(settings.bindings[&"spell_1"], int(KEY_Z))
	SettingsApplier.reset_bindings(settings)
	assert_eq(SettingsApplier.key_of(&"spell_1"), int(KEY_1))
	assert_eq(settings.bindings.size(), 0)


func test_a_key_used_by_another_action_is_refused() -> void:
	var settings := Settings.new()
	var error := SettingsApplier.set_binding(settings, &"spell_1", KEY_2)
	assert_true(error.contains("Spell 2"), error)
	assert_eq(SettingsApplier.key_of(&"spell_1"), int(KEY_1), "unchanged")
	assert_eq(settings.bindings.size(), 0)
	assert_eq(SettingsApplier.set_binding(settings, &"spell_1", KEY_1), "", "its own key is fine")


func test_rebinding_keeps_other_events_of_the_action() -> void:
	var settings := Settings.new()
	SettingsApplier.set_binding(settings, &"camera_rotate_left", KEY_J)
	var keys := InputMap.action_get_events(&"camera_rotate_left").filter(func(e: InputEvent) -> bool: return e is InputEventKey)
	assert_eq(keys.size(), 1, "one key, not two")


func test_the_spell_bar_follows_a_rebound_key() -> void:
	var settings := Settings.new()
	SettingsApplier.set_binding(settings, &"spell_2", KEY_Z)
	var bar := (load("res://scenes/battle/hud/spell_bar.tscn") as PackedScene).instantiate() as SpellBar
	(Engine.get_main_loop() as SceneTree).root.add_child(bar)
	bar.show_spells([BattleFixtures.damage_spell(), BattleFixtures.damage_spell()] as Array[SpellData], 10)
	var received: Array[int] = []
	bar.spell_pressed.connect(func(index: int) -> void: received.append(index))
	for key: Key in [KEY_2, KEY_Z]:
		var press := InputEventKey.new()
		press.physical_keycode = key
		press.pressed = true
		bar.get_viewport().push_input(press)
		var release := press.duplicate() as InputEventKey
		release.pressed = false
		bar.get_viewport().push_input(release)
	assert_eq(received, [1] as Array[int], "only the new key presses spell 2")
	assert_eq((bar.slot(1).get_node("Key") as Label).text, "Z")
	bar.free()


func test_ui_scale_is_applied_to_the_window() -> void:
	var settings := Settings.new()
	settings.ui_scale = 1.5
	var window := Window.new()
	SettingsApplier.apply(settings, window)
	assert_eq(window.content_scale_factor, 1.5)
	window.free()


func test_number_row_keys_read_as_digits_on_any_layout() -> void:
	assert_eq(SettingsApplier.key_text(&"spell_3"), "3")
	assert_eq(SettingsApplier.key_text(&"end_turn"), "Space")


func test_keys_that_cant_be_bound_are_refused() -> void:
	var settings := Settings.new()
	for code: int in [0, -3, KEY_SHIFT, KEY_ENTER, KEY_ESCAPE, KEY_TAB, KEY_LEFT]:
		assert_ne(SettingsApplier.set_binding(settings, &"spell_1", code), "", "refused: %d" % code)
	assert_eq(settings.bindings.size(), 0)
	assert_true(SettingsApplier.set_binding(settings, &"spell_1", KEY_ENTER).contains("reserved"))


func test_a_key_of_a_fixed_spell_key_is_taken_too() -> void:
	var settings := Settings.new()
	var error := SettingsApplier.set_binding(settings, &"spell_1", KEY_6)
	assert_true(error.contains("Spell 6"), error)


func test_a_hand_edited_file_keeps_only_free_real_keys() -> void:
	var store := _store()
	var file := FileAccess.open(PATH, FileAccess.WRITE)
	file.store_string("[display]\nui_scale=[1, 2]\nwindow_mode={}\n[keys]\nspell_1=%d\nspell_2=%d\nspell_3=%d\nspell_4=%d\nend_turn=[5]\n" % [
			KEY_G, KEY_G, KEY_ESCAPE, KEY_SHIFT])
	file.close()
	var settings := store.load_or_default()
	assert_eq(settings.ui_scale, 1.0, "a list isn't a scale")
	assert_eq(settings.window_mode, Settings.WindowMode.WINDOWED)
	assert_eq(settings.bindings, {&"spell_1": int(KEY_G)} as Dictionary[StringName, int], "duplicate, Esc, modifier and a list dropped")


func test_window_mode_is_skipped_in_the_editors_game_tab_and_at_web_startup() -> void:
	assert_eq(SettingsApplier.supports_window_mode(), not OS.has_feature("mobile") and not Engine.is_embedded_in_editor())
