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
	assert_eq(Hud.spell_description(fireball), "Range 3-5, line of sight. Circle area 1. 6-8 fire damage.")
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


func _status_info(status_name: String, turns: int, description: String) -> Hud.StatusInfo:
	var info := Hud.StatusInfo.new()
	info.display_name = status_name
	info.turns_left = turns
	info.description = description
	return info


func test_unit_panel_lists_statuses_with_tooltips() -> void:
	var hud := _hud()
	var info := _info("Knight")
	info.statuses = [_status_info("Poison", 2, "3-4 damage per turn"), _status_info("Guarded", 1, "-30% damage taken")] as Array[Hud.StatusInfo]
	hud.show_unit(info)
	var rows := hud.get_node("%StatusList").get_children()
	assert_eq(rows.size(), 2)
	assert_eq(((rows[0] as Control).get_child(1) as Label).text, "Poison, 2 turns")
	assert_eq(((rows[1] as Control).get_child(1) as Label).text, "Guarded, 1 turn")
	assert_eq((rows[0] as Control).tooltip_text, "3-4 damage per turn")
	info.statuses = [] as Array[Hud.StatusInfo]
	hud.show_unit(info)
	assert_eq(hud.get_node("%StatusList").get_child_count(), 0, "replaced")
	hud.free()


func test_modified_ap_and_mp_are_tinted() -> void:
	var hud := _hud()
	var info := _info("Knight")
	info.max_ap = 6
	info.base_ap = 6
	info.max_mp = 4
	info.base_mp = 3
	hud.show_unit(info)
	assert_eq((hud.get_node("%ApLabel") as Label).modulate, Color.WHITE)
	assert_eq((hud.get_node("%MpLabel") as Label).modulate, Hud.BUFFED_COLOR)
	info.max_mp = 1
	hud.show_unit(info)
	assert_eq((hud.get_node("%MpLabel") as Label).modulate, Hud.DEBUFFED_COLOR)
	hud.free()


func test_inspect_panel_shows_a_unit_and_hides() -> void:
	var hud := _hud()
	var panel := hud.get_node("%InspectPanel") as Control
	assert_false(panel.visible, "hidden at first")
	var info := _info("Brute", false)
	info.statuses = [_status_info("Crippled", 2, "-2 MP")] as Array[Hud.StatusInfo]
	info.spells = _spells()
	hud.show_inspected(info)
	assert_true(panel.visible)
	var rows := hud.get_node("%InspectRows")
	assert_eq((rows.get_child(0).get_child(1) as Label).text, "Brute (enemy)")
	assert_eq(rows.get_node("Statuses").get_child_count(), 1)
	var spells := rows.get_node("Spells").get_children()
	assert_eq(spells.size(), 2)
	assert_eq((spells[0] as Label).text, "Hit (3 AP)")
	assert_true((spells[0] as Label).tooltip_text.contains("5 damage"))
	hud.hide_inspected()
	assert_false(panel.visible)
	hud.free()


func test_unit_info_carries_statuses_modified_maxima_and_spells() -> void:
	var state := BattleFixtures.state("0p 0e")
	var unit := state.units[0]
	unit.data.spells = _spells()
	unit.add_status(BattleFixtures.status("Haste", 2, 0,
			[BattleFixtures.modifier(StatModifier.Stat.MP, 2)] as Array[StatModifier], true), 1)
	var info := Hud.UnitInfo.from_unit(unit)
	assert_eq([info.max_mp, info.base_mp, info.mp], [5, 3, 5])
	assert_eq(info.statuses.size(), 1)
	assert_eq([info.statuses[0].display_name, info.statuses[0].turns_left, info.statuses[0].description], ["Haste", 2, "+2 MP"])
	assert_eq(info.spells.size(), 2)


func test_power_and_resistances_always_show() -> void:
	var hud := _hud()
	var info := _info("Knight")
	hud.show_unit(info)
	assert_true((hud.get_node("%CombatStats") as Label).visible, "always shown")
	assert_eq((hud.get_node("%CombatStats") as Label).text, "Power: All +0%\nResist: none")
	info.power = 8
	info.resistances = {"Physical": 0, "Fire": 20, "Poison": -10}
	hud.show_unit(info)
	assert_eq((hud.get_node("%CombatStats") as Label).text, "Power: All +8%\nResist: Physical +0%, Fire +20%, Poison -10%")
	hud.show_inspected(info)
	assert_eq((hud.get_node("%InspectRows").get_node("CombatStats") as Label).text, "Power: All +8%\nResist: Physical +0%, Fire +20%, Poison -10%")
	hud.free()


func test_unit_info_reads_power_and_resistances() -> void:
	var ice := DamageType.new()  # Not one of the game's types.
	ice.display_name = "Ice"
	var ward := BattleFixtures.modifier(StatModifier.Stat.RESISTANCE_PERCENT, 25)
	ward.damage_type = ice
	var map := MapData.new()
	map.layout = "0p 0e"
	var state := BattleState.create(map.parse(), [BattleFixtures.unit("P0")] as Array[UnitData],
			[BattleFixtures.unit("E0")] as Array[UnitData], 1, [[ward, BattleFixtures.modifier(StatModifier.Stat.POWER, 9)] as Array[StatModifier]])
	var info := Hud.UnitInfo.from_unit(state.units[0])
	assert_eq(info.power, 9)
	assert_eq(info.resistances.keys(), ["Physical", "Fire", "Poison", "Ice"], "every game type in order, then the unit's own")
	assert_eq(info.resistances["Physical"], 0, "zeros included")
	assert_eq(info.resistances["Ice"], 25)
