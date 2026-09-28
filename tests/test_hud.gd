extends TestCase
## The HUD shows what it's given and reports clicks as signals.

const HUD_SCENE := preload("res://scenes/battle/hud.tscn")


func _hud() -> Hud:
	var hud := HUD_SCENE.instantiate() as Hud
	(Engine.get_main_loop() as SceneTree).root.add_child(hud)
	return hud


func _info(unit_name: String, is_player := true, hp := 20) -> Hud.UnitInfo:
	var info := Hud.UnitInfo.new()
	info.display_name = unit_name
	info.is_player = is_player
	info.hp = hp
	info.max_hp = 30
	info.ap = 4
	info.max_ap = 6
	info.mp = 1
	info.max_mp = 3
	return info


func _spells() -> Array[SpellData]:
	return [BattleFixtures.damage_spell(3), BattleFixtures.damage_spell(5)] as Array[SpellData]


func _spell_button(hud: Hud, index: int) -> Button:
	return hud.get_node("%SpellBar").get_child(index)


func test_unit_panel_shows_the_unit() -> void:
	var hud := _hud()
	hud.show_unit(_info("Knight"))
	assert_eq((hud.get_node("%UnitName") as Label).text, "Knight")
	assert_eq((hud.get_node("%HpLabel") as Label).text, "20 / 30 HP")
	assert_eq((hud.get_node("%ApLabel") as Label).text, "AP 4 / 6")
	assert_eq((hud.get_node("%MpLabel") as Label).text, "MP 1 / 3")
	assert_eq((hud.get_node("%HpBar") as ProgressBar).value, 20.0)
	hud.free()


func test_unit_info_copies_the_unit_state() -> void:
	var state := BattleFixtures.state("0p 0e")
	state.units[0].hp = 7
	var info := Hud.UnitInfo.from_unit(state.units[0])
	assert_eq([info.display_name, info.hp, info.max_hp, info.ap, info.mp, info.is_player], ["P0", 7, 20, 6, 3, true])


func test_turn_order_lists_units_and_marks_the_current_one() -> void:
	var hud := _hud()
	hud.show_turn_order([_info("Knight"), _info("Brute", false)] as Array[Hud.UnitInfo], 3)
	var chips := hud.get_node("%TurnOrder").get_children()
	assert_eq(chips.size(), 2)
	var current := (chips[0] as PanelContainer).get_theme_stylebox("panel") as StyleBoxFlat
	var next := (chips[1] as PanelContainer).get_theme_stylebox("panel") as StyleBoxFlat
	assert_true(current.border_width_top > 0 and next.border_width_top == 0, "only the current unit is outlined")
	assert_eq((hud.get_node("%RoundLabel") as Label).text, "Round 3")
	hud.show_turn_order([_info("Knight")] as Array[Hud.UnitInfo], 3)
	assert_eq(hud.get_node("%TurnOrder").get_child_count(), 1, "replaced, not added")
	hud.free()


func test_spells_are_disabled_without_enough_ap() -> void:
	var hud := _hud()
	hud.show_spells(_spells(), 4)
	assert_false(_spell_button(hud, 0).disabled, "3 AP spell with 4 AP")
	assert_true(_spell_button(hud, 1).disabled, "5 AP spell with 4 AP")
	assert_true(_spell_button(hud, 0).tooltip_text.contains("5 damage"), _spell_button(hud, 0).tooltip_text)
	hud.free()


func test_player_controls_can_be_disabled() -> void:
	var hud := _hud()
	hud.show_spells(_spells(), 10)
	hud.set_player_controls_enabled(false)
	assert_true(_spell_button(hud, 0).disabled)
	assert_true((hud.get_node("%EndTurnButton") as Button).disabled)
	hud.set_player_controls_enabled(true)
	assert_false(_spell_button(hud, 0).disabled)
	assert_false((hud.get_node("%EndTurnButton") as Button).disabled)
	hud.free()


func test_buttons_emit_signals_up() -> void:
	var hud := _hud()
	hud.show_spells(_spells(), 10)
	var received: Array = []
	hud.spell_selected.connect(func(index: int) -> void: received.append(["spell", index]))
	hud.end_turn_pressed.connect(func() -> void: received.append(["end"]))
	hud.view_toggle_pressed.connect(func() -> void: received.append(["view"]))
	hud.restart_pressed.connect(func() -> void: received.append(["restart"]))
	_spell_button(hud, 1).pressed.emit()
	(hud.get_node("%EndTurnButton") as Button).pressed.emit()
	(hud.get_node("%ViewButton") as Button).pressed.emit()
	(hud.get_node("%RestartButton") as Button).pressed.emit()
	assert_eq(received, [["spell", 1], ["end"], ["view"], ["restart"]])
	hud.free()


func test_keyboard_shortcuts_press_enabled_buttons_only() -> void:
	var hud := _hud()
	hud.show_spells(_spells(), 4)
	var received: Array[int] = []
	hud.spell_selected.connect(func(index: int) -> void: received.append(index))
	var ends := {"count": 0}
	hud.end_turn_pressed.connect(func() -> void: ends.count += 1)
	for key: Key in [KEY_1, KEY_2, KEY_SPACE]:
		var press := InputEventKey.new()
		press.physical_keycode = key
		press.pressed = true
		hud.get_viewport().push_input(press)
		var release := press.duplicate() as InputEventKey
		release.pressed = false
		hud.get_viewport().push_input(release)
	assert_eq(received, [0] as Array[int], "key 2's spell costs too much AP")
	assert_eq(ends.count, 1, "Space ends the turn")
	hud.free()


func test_selected_spell_shows_pressed_without_emitting() -> void:
	var hud := _hud()
	hud.show_spells(_spells(), 10)
	var emitted := {"count": 0}
	hud.spell_selected.connect(func(_index: int) -> void: emitted.count += 1)
	hud.set_selected_spell(1)
	assert_false(_spell_button(hud, 0).button_pressed)
	assert_true(_spell_button(hud, 1).button_pressed)
	hud.set_selected_spell(-1)
	assert_false(_spell_button(hud, 1).button_pressed)
	assert_eq(emitted.count, 0)
	hud.free()


func test_result_panel() -> void:
	var hud := _hud()
	hud.show_spells(_spells(), 10)
	hud.show_result(false)
	assert_true((hud.get_node("%ResultPanel") as Control).visible)
	assert_eq((hud.get_node("%ResultLabel") as Label).text, "Defeat")
	assert_true(_spell_button(hud, 0).disabled, "no more actions once it's over")
	hud.hide_result()
	assert_false((hud.get_node("%ResultPanel") as Control).visible)
	hud.free()


func test_banner_fades_in_and_out() -> void:
	var hud := _hud()
	Engine.time_scale = 20.0
	var banner := hud.get_node("%Banner") as Label
	await hud.show_banner("Knight's turn")
	assert_eq(banner.text, "Knight's turn")
	assert_eq(banner.modulate.a, 0.0, "gone again")
	hud.free()


func test_hud_lets_clicks_through_to_the_board_and_never_takes_focus() -> void:
	var hud := _hud()
	hud.show_spells(_spells(), 10)
	hud.show_turn_order([_info("Knight")] as Array[Hud.UnitInfo], 1)
	var nodes: Array[Node] = [hud]
	while not nodes.is_empty():
		var node: Node = nodes.pop_back()
		nodes.append_array(node.get_children())
		if node is Button:
			assert_eq((node as Button).focus_mode, Control.FOCUS_NONE, "%s takes no focus" % node.name)
	for path in ["Root", "Root/TopBar", "%TurnOrder", "%SpellBar", "Root/Actions", "%Banner"]:
		assert_eq((hud.get_node(path) as Control).mouse_filter, Control.MOUSE_FILTER_IGNORE, "%s ignores the mouse" % path)
	for chip in hud.get_node("%TurnOrder").get_children():
		assert_eq((chip as Control).mouse_filter, Control.MOUSE_FILTER_IGNORE, "turn chips ignore the mouse")
	hud.free()


func test_spell_description_covers_range_area_and_effects() -> void:
	var fireball := load("res://data/spells/fireball.tres") as SpellData
	assert_eq(Hud.spell_description(fireball), "Range 3-5, line of sight. Circle area 1. 5-7 damage.")
	var mend := load("res://data/spells/mend.tres") as SpellData
	assert_eq(Hud.spell_description(mend), "Range 0-3. Heals 6-10.")
	var firebolt := load("res://data/spells/firebolt.tres") as SpellData
	assert_true(Hud.spell_description(firebolt).contains("+range from high ground"))


func test_spells_can_be_rebuilt_from_inside_a_button_press() -> void:
	# E.g. an instant spell whose playback refreshes the HUD synchronously.
	var hud := _hud()
	hud.show_spells(_spells(), 10)
	hud.spell_selected.connect(func(_index: int) -> void: hud.show_spells(_spells(), 2))
	_spell_button(hud, 0).pressed.emit()
	assert_eq(hud.get_node("%SpellBar").get_child_count(), 2, "rebuilt")
	assert_true(_spell_button(hud, 0).disabled, "with the new AP")
	hud.free()
