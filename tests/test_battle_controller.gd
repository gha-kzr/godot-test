extends TestCase
## The battle scene end to end: turn loop, player commands, enemy turns, result, restart.
## Time runs fast; waits are bounded by frames and the runner's per-test timeout.

const BATTLE_SCENE := preload("res://scenes/battle/battle.tscn")
const TIME_SCALE := 30.0
const MAX_WAIT_FRAMES := 3000


func _tree() -> SceneTree:
	return Engine.get_main_loop() as SceneTree


## The slice battle (enemy Archer acts first), or a small custom one; placement is skipped
## (Ready) unless `ready` is false.
func _controller(layout := "", players: Array[UnitData] = [], enemies: Array[UnitData] = [], ready := true) -> BattleController:
	Engine.time_scale = TIME_SCALE
	var controller := BATTLE_SCENE.instantiate() as BattleController
	controller.rng_seed = 7
	if not layout.is_empty():
		controller.encounter = BattleFixtures.encounter(layout, enemies)
		controller.players = players
	_tree().root.add_child(controller)
	if ready:
		controller.end_turn()
	return controller


func _fighter(unit_name: String, initiative: int, max_hp := 20, damage := 5) -> UnitData:
	var data := BattleFixtures.unit(unit_name, initiative, 3, 6, max_hp)
	data.spells = [BattleFixtures.damage_spell(3, 1, 1, damage)] as Array[SpellData]
	return data


func _wait_for(controller: BattleController, wanted: Array) -> bool:
	for i in MAX_WAIT_FRAMES:
		if controller.input_state in wanted:
			return true
		await _tree().process_frame
	return false


func _assert_views_in_sync(controller: BattleController) -> void:
	for unit in controller.battle.state.units:
		var view := controller.units_view.view(unit.id)
		assert_eq(view.visible, unit.is_alive(), "unit %d visibility" % unit.id)
		assert_eq(view.hp_text(), "%d/%d" % [unit.hp, unit.max_hp()], "unit %d HP" % unit.id)
		if unit.is_alive():
			assert_true(view.position.is_equal_approx(controller.board_view.cell_to_world(unit.cell)), "unit %d position" % unit.id)


func test_enemies_act_until_the_players_turn() -> void:
	var controller := _controller()
	assert_true(await _wait_for(controller, [BattleController.State.IDLE]), "reaches the player's turn")
	var current := controller.battle.state.current_unit()
	assert_eq(current.team, UnitState.Team.PLAYER)
	assert_true(controller.board_view.highlighted_count(BoardView.Highlight.REACH) > 0, "reachable cells shown")
	assert_false((controller.hud.get_node("%EndTurnButton") as Button).disabled, "player controls enabled")
	_assert_views_in_sync(controller)


func test_camera_opens_facing_the_player_spawns() -> void:
	var controller := _controller()
	var rig := controller.camera_rig
	var camera_side := rig.camera.global_position - rig.global_position
	var players_side := controller.board_view.cell_to_world(Vector2i(0, 8)) - controller.board_view.center()
	assert_true(Vector2(camera_side.x, camera_side.z).dot(Vector2(players_side.x, players_side.z)) > 0.0,
			"the camera looks from the players' side")


func test_clicking_a_reachable_cell_moves_the_unit() -> void:
	var controller := _controller("0p 0 0 0 0 0e", [_fighter("P0", 200)], [_fighter("E0", 100)])
	assert_true(await _wait_for(controller, [BattleController.State.IDLE]))
	controller.click_cell(Vector2i(2, 0))
	assert_eq(controller.input_state, BattleController.State.ANIMATING)
	assert_true(await _wait_for(controller, [BattleController.State.IDLE]))
	var unit := controller.battle.state.units[0]
	assert_eq(unit.cell, Vector2i(2, 0))
	assert_eq(unit.mp, 1)
	_assert_views_in_sync(controller)


func test_clicks_outside_the_reach_do_nothing() -> void:
	var controller := _controller("0p 0 0 0 0 0e", [_fighter("P0", 200)], [_fighter("E0", 100)])
	assert_true(await _wait_for(controller, [BattleController.State.IDLE]))
	controller.click_cell(Vector2i(4, 0))  # 4 away with 3 MP.
	controller.click_cell(Vector2i(5, 0))  # The enemy's cell.
	assert_eq(controller.input_state, BattleController.State.IDLE)
	assert_eq(controller.battle.state.units[0].cell, Vector2i(0, 0))


func test_selecting_a_spell_shows_its_range_and_cancel_goes_back() -> void:
	var controller := _controller("0p 0 0 0 0 0e", [_fighter("P0", 200)], [_fighter("E0", 100)])
	assert_true(await _wait_for(controller, [BattleController.State.IDLE]))
	controller.select_spell(0)
	assert_eq(controller.input_state, BattleController.State.TARGETING)
	assert_eq(controller.board_view.highlighted_count(BoardView.Highlight.RANGE), 1, "melee: one cell")
	assert_eq(controller.board_view.highlighted_count(BoardView.Highlight.REACH), 0, "reach hidden while aiming")
	assert_eq(controller.board_view.highlighted_count(BoardView.Highlight.RANGE_BLOCKED), 0, "melee needs no sight")
	controller.cancel()
	assert_eq(controller.input_state, BattleController.State.IDLE)
	controller.select_spell(0)
	controller.select_spell(0)
	assert_eq(controller.input_state, BattleController.State.IDLE, "selecting it again unselects it")


func test_spells_without_enough_ap_cannot_be_selected() -> void:
	var controller := _controller("0p 0e", [_fighter("P0", 200)], [_fighter("E0", 100)])
	assert_true(await _wait_for(controller, [BattleController.State.IDLE]))
	controller.battle.state.units[0].ap = 2
	controller.select_spell(0)
	assert_eq(controller.input_state, BattleController.State.IDLE)


func test_casting_on_the_last_enemy_wins() -> void:
	var controller := _controller("0p 0e", [_fighter("P0", 200)], [_fighter("E0", 100, 4)])
	assert_true(await _wait_for(controller, [BattleController.State.IDLE]))
	controller.select_spell(0)
	controller.click_cell(Vector2i(1, 0))
	assert_true(await _wait_for(controller, [BattleController.State.ENDED]), "the battle ends")
	assert_true((controller.hud.get_node("%ResultPanel") as Control).visible)
	assert_eq((controller.hud.get_node("%ResultLabel") as Label).text, "Victory!")
	assert_true((controller.hud.get_node("%EndTurnButton") as Button).disabled)
	_assert_views_in_sync(controller)


func test_ending_the_turn_lets_the_enemy_act_and_can_lose() -> void:
	var controller := _controller("0p 0 0e", [_fighter("P0", 200, 5)], [_fighter("E0", 100, 20, 5)])
	assert_true(await _wait_for(controller, [BattleController.State.IDLE]))
	controller.end_turn()
	assert_true(await _wait_for(controller, [BattleController.State.ENDED]), "the enemy walks up and kills P0")
	assert_eq((controller.hud.get_node("%ResultLabel") as Label).text, "Defeat")
	_assert_views_in_sync(controller)


func test_input_is_ignored_outside_the_players_turn() -> void:
	var controller := _controller()
	assert_eq(controller.battle.state.current_unit().data.display_name, "Archer", "an enemy acts first")
	controller.end_turn()
	controller.select_spell(0)
	controller.click_cell(Vector2i(1, 8))
	assert_true(controller.input_state in [BattleController.State.ANIMATING, BattleController.State.ENEMY_TURN])
	assert_eq(controller.battle.state.current_unit().data.display_name, "Archer", "still the Archer's turn")


func test_restart_mid_animation_starts_a_clean_battle() -> void:
	var controller := _controller("0p 0 0 0 0 0e", [_fighter("P0", 200)], [_fighter("E0", 100)])
	assert_true(await _wait_for(controller, [BattleController.State.IDLE]))
	controller.click_cell(Vector2i(3, 0))
	await _tree().process_frame  # Mid-walk.
	var old_battle := controller.battle
	controller.restart()
	assert_ne(controller.battle, old_battle)
	assert_eq(controller.input_state, BattleController.State.PLACING, "a new battle opens on placement")
	controller.end_turn()
	assert_true(await _wait_for(controller, [BattleController.State.IDLE]), "the new battle reaches the player's turn")
	assert_eq(controller.battle.state.units[0].cell, Vector2i(0, 0), "fresh positions")
	assert_false((controller.hud.get_node("%ResultPanel") as Control).visible)
	await _tree().create_timer(0.5).timeout  # Let any leftover coroutine of the old battle run.
	assert_eq(controller.battle.state.units[0].cell, Vector2i(0, 0), "the old battle's move never lands")
	assert_eq(controller.input_state, BattleController.State.IDLE)
	_assert_views_in_sync(controller)


func test_a_real_mouse_click_moves_the_unit() -> void:
	var controller := _controller("0p 0 0 0 0 0e", [_fighter("P0", 200)], [_fighter("E0", 100)])
	assert_true(await _wait_for(controller, [BattleController.State.IDLE]))
	await _tree().physics_frame
	await _tree().physics_frame
	var target := controller.board_view.to_global(controller.board_view.cell_to_world(Vector2i(2, 0)))
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = controller.camera_rig.camera.unproject_position(target)
	controller.get_viewport().push_input(click)
	assert_true(await _wait_for(controller, [BattleController.State.ANIMATING]), "the click started a move")
	assert_true(await _wait_for(controller, [BattleController.State.IDLE]))
	assert_eq(controller.battle.state.units[0].cell, Vector2i(2, 0))


## Waits until the caster has lunged and come back while the spell area is still lit,
## i.e. the EventPlayer is inside its area flash (polled per frame, no timing guesses).
func _wait_for_area_flash(controller: BattleController, caster_id: int) -> bool:
	var view := controller.units_view.view(caster_id)
	var start := view.position
	var lunged := false
	for i in MAX_WAIT_FRAMES:
		if not view.position.is_equal_approx(start):
			lunged = true
		elif lunged and controller.board_view.highlighted_count(BoardView.Highlight.AREA) > 0:
			return true
		await _tree().process_frame
	return false


func test_restart_during_a_cast_does_not_replay_old_events_on_the_new_battle() -> void:
	var controller := _controller("0p 0e", [_fighter("P0", 200)], [_fighter("E0", 100)])
	assert_true(await _wait_for(controller, [BattleController.State.IDLE]))
	Engine.time_scale = 1.0  # A flash lasts a few frames at most at high speed.
	controller.select_spell(0)
	controller.click_cell(Vector2i(1, 0))
	assert_true(await _wait_for_area_flash(controller, 0), "inside the area flash")
	controller.restart()
	controller.end_turn()
	Engine.time_scale = TIME_SCALE
	for i in 60:
		await _tree().process_frame  # Let the old playback's flash end and resume.
	assert_eq(controller.units_view.view(1).hp_text(), "20/20", "the old hit never lands on the new enemy")
	assert_eq(controller.input_state, BattleController.State.IDLE)
	_assert_views_in_sync(controller)


func test_moving_the_mouse_during_a_cast_keeps_its_area_flash() -> void:
	var controller := _controller("0p 0e", [_fighter("P0", 200)], [_fighter("E0", 100)])
	assert_true(await _wait_for(controller, [BattleController.State.IDLE]))
	Engine.time_scale = 1.0
	controller.select_spell(0)
	controller.click_cell(Vector2i(1, 0))
	assert_true(await _wait_for_area_flash(controller, 0), "inside the area flash")
	controller._hovered_cell = Vector2i(0, 0)  # What _physics_process does when the mouse moves.
	controller._update_hover()
	assert_eq(controller.board_view.highlighted_count(BoardView.Highlight.AREA), 1, "the flash stays")


func test_hover_shows_the_path_while_moving_and_the_area_while_aiming() -> void:
	var controller := _controller("0p 0 0 0 0 0e", [_fighter("P0", 200)], [_fighter("E0", 100)])
	assert_true(await _wait_for(controller, [BattleController.State.IDLE]))
	controller._hovered_cell = Vector2i(3, 0)
	controller._update_hover()
	assert_eq(controller.board_view.highlighted_count(BoardView.Highlight.PATH), 3, "path of 3 steps")
	controller._hovered_cell = Vector2i(5, 0)  # Out of reach.
	controller._update_hover()
	assert_eq(controller.board_view.highlighted_count(BoardView.Highlight.PATH), 0)
	controller.select_spell(0)
	controller._hovered_cell = Vector2i(1, 0)
	controller._update_hover()
	assert_eq(controller.board_view.highlighted_count(BoardView.Highlight.AREA), 1, "single-cell area")
	assert_eq(controller.board_view.highlighted_count(BoardView.Highlight.PATH), 0, "no path while aiming")


func test_a_mutual_wipe_is_shown_as_a_defeat() -> void:
	# The caster's circle hits both itself and the last enemy: a DRAW in the rules.
	var nova := BattleFixtures.damage_spell(3, 0, 1, 10, AreaShape.Kind.CIRCLE, 1)
	var caster := BattleFixtures.unit("P0", 200, 3, 6, 5)
	caster.spells = [nova] as Array[SpellData]
	var controller := _controller("0p 0e", [caster], [_fighter("E0", 100, 5)])
	assert_true(await _wait_for(controller, [BattleController.State.IDLE]))
	controller.select_spell(0)
	controller.click_cell(Vector2i(0, 0))
	assert_true(await _wait_for(controller, [BattleController.State.ENDED]))
	assert_eq(controller.battle.state.outcome(), BattleState.Outcome.DRAW)
	assert_eq((controller.hud.get_node("%ResultLabel") as Label).text, "Defeat")


func test_play_again_starts_a_new_battle_and_the_seed_is_shown() -> void:
	var controller := _controller("0p 0e", [_fighter("P0", 200)], [_fighter("E0", 100, 4)])
	assert_true(await _wait_for(controller, [BattleController.State.IDLE]))
	controller.select_spell(0)
	controller.click_cell(Vector2i(1, 0))
	assert_true(await _wait_for(controller, [BattleController.State.ENDED]))
	assert_eq((controller.hud.get_node("%SeedLabel") as Label).text, "Battle seed 7")
	var old_battle := controller.battle
	(controller.hud.get_node("%RestartButton") as Button).pressed.emit()
	assert_ne(controller.battle, old_battle)
	assert_false((controller.hud.get_node("%ResultPanel") as Control).visible)
	controller.end_turn()
	assert_true(await _wait_for(controller, [BattleController.State.IDLE]))


func test_a_failed_restart_keeps_the_current_battle() -> void:
	var controller := _controller("0p 0 0 0 0e", [_fighter("P0", 200)], [_fighter("E0", 100)])
	assert_true(await _wait_for(controller, [BattleController.State.IDLE]))
	var old_battle := controller.battle
	Engine.time_scale = 1.0  # A slow walk, to restart in the middle of it.
	controller.click_cell(Vector2i(3, 0))
	await _tree().process_frame
	assert_eq(controller.input_state, BattleController.State.ANIMATING, "mid-walk")
	controller.encounter = null
	expect_error("no encounter or map set")
	controller.restart()
	assert_eq(controller.battle, old_battle)
	Engine.time_scale = TIME_SCALE
	assert_true(await _wait_for(controller, [BattleController.State.IDLE]), "the walk finishes, still playable")
	assert_eq(controller.battle.state.units[0].cell, Vector2i(3, 0))


func test_escape_stops_aiming() -> void:
	var controller := _controller("0p 0e", [_fighter("P0", 200)], [_fighter("E0", 100)])
	assert_true(await _wait_for(controller, [BattleController.State.IDLE]))
	controller.select_spell(0)
	var escape := InputEventKey.new()
	escape.physical_keycode = KEY_ESCAPE
	escape.pressed = true
	controller.get_viewport().push_input(escape)
	assert_eq(controller.input_state, BattleController.State.IDLE)


func test_the_active_unit_is_marked() -> void:
	var controller := _controller("0p 0 0 0e", [_fighter("P0", 200)], [_fighter("E0", 100)])
	assert_true(await _wait_for(controller, [BattleController.State.IDLE]))
	assert_true(controller.units_view.view(0).is_active(), "P0's turn")
	assert_false(controller.units_view.view(1).is_active())
	controller.end_turn()
	assert_true(await _wait_for(controller, [BattleController.State.ENEMY_TURN]))
	assert_true(controller.units_view.view(1).is_active(), "E0's turn")
	assert_false(controller.units_view.view(0).is_active())


func test_aiming_shows_cells_hidden_from_sight_faded() -> void:
	var bolt := BattleFixtures.damage_spell(3, 1, 4, 5, AreaShape.Kind.SINGLE, 0, true)
	var caster := BattleFixtures.unit("P0", 200)
	caster.spells = [bolt] as Array[SpellData]
	var controller := _controller("0p 0 # 0 0e", [caster], [_fighter("E0", 100)])
	assert_true(await _wait_for(controller, [BattleController.State.IDLE]))
	controller.select_spell(0)
	assert_eq(controller.board_view.highlighted_count(BoardView.Highlight.RANGE), 1)
	assert_eq(controller.board_view.highlighted_count(BoardView.Highlight.RANGE_BLOCKED), 2)
	controller.click_cell(Vector2i(4, 0))
	assert_eq(controller.input_state, BattleController.State.TARGETING, "a blocked cell can't be aimed at")


func test_hovering_another_unit_inspects_it() -> void:
	var controller := _controller("0p 0 0 0e", [_fighter("P0", 200)], [_fighter("E0", 100)])
	assert_true(await _wait_for(controller, [BattleController.State.IDLE]))
	var panel := controller.hud.get_node("%InspectCard") as Control
	controller._hovered_cell = Vector2i(3, 0)
	controller._update_hover()
	assert_true(panel.visible, "the enemy is shown")
	controller._hovered_cell = Vector2i(0, 0)
	controller._update_hover()
	assert_false(panel.visible, "not the unit that's acting")
	controller._hovered_cell = Vector2i(1, 0)
	controller._update_hover()
	assert_false(panel.visible, "empty cell")


func test_the_hud_never_runs_ahead_of_the_animations() -> void:
	# P0 ends its turn; E0 dies to its poison at its turn start; E1 plays next.
	var controller := _controller("0p 0 0e 0e", [_fighter("P0", 200)], [_fighter("E0", 100, 2), _fighter("E1", 90)])
	assert_true(await _wait_for(controller, [BattleController.State.IDLE]))
	controller.battle.state.units[1].add_status(BattleFixtures.status("Poison", 2, 3), 0)
	var panel_after_first_event := {}
	controller.event_player.event_played.connect(func(event: BattleEvents.Event) -> void:
		if panel_after_first_event.is_empty():
			panel_after_first_event["name"] = (controller.hud.get_node("%ActiveCard/Rows/Header/NameLabel") as Label).text)
	controller.end_turn()
	assert_true(await _wait_for(controller, [BattleController.State.ENEMY_TURN, BattleController.State.IDLE]))
	assert_eq(panel_after_first_event.get("name"), "P0", "still P0 while its turn end plays")
	assert_eq((controller.hud.get_node("%ActiveCard/Rows/Header/NameLabel") as Label).text, "E1 Lv 1", "E1 once the playback is over")
	var chips := controller.hud.get_node("%TurnTimeline/Chips").get_child_count()
	assert_eq(chips, 2, "E0 left the turn order")
	controller._hovered_cell = Vector2i(3, 0)
	controller._update_hover()
	assert_false((controller.hud.get_node("%InspectCard") as Control).visible, "E1 is acting, no inspect")


func test_the_inspect_panel_stays_while_the_mouse_is_on_it() -> void:
	var controller := _controller("0p 0 0 0e", [_fighter("P0", 200)], [_fighter("E0", 100)])
	assert_true(await _wait_for(controller, [BattleController.State.IDLE]))
	controller._hovered_cell = Vector2i(3, 0)
	controller._update_hover()
	var panel := controller.hud.get_node("%InspectCard") as Control
	var inside := controller.hud.get_node("%InspectCard/Rows/Header") as Control
	assert_eq(controller._hover_cell(inside, Vector2.ZERO), Vector2i(3, 0), "sticks over the panel")
	assert_eq(controller._hover_cell(controller.hud.get_node("%EndTurnButton"), Vector2.ZERO), BoardView.NO_CELL,
			"other HUD controls clear the hover")
	assert_true(panel.visible)


func test_a_battle_opens_on_placement_and_ready_starts_it() -> void:
	var controller := _controller("0p 0p 0p 0p\n0  0  0  0\n0  0  0  0\n0  0  0  0\n0  0  0e 0",
			[_fighter("A", 200), _fighter("B", 190)] as Array[UnitData], [_fighter("E", 100)] as Array[UnitData], false)
	assert_eq(controller.input_state, BattleController.State.PLACING)
	assert_false(controller.battle.state.started)
	assert_eq(controller.board_view.highlighted_count(BoardView.Highlight.ZONE), 4, "the zone is shown")
	var end_turn := controller.hud.get_node("%EndTurnButton") as Button
	assert_eq(end_turn.text, "Ready (Space)")
	assert_false(end_turn.disabled)
	var a := controller.battle.state.units[0]
	var b := controller.battle.state.units[1]
	assert_eq((controller.hud.get_node("%ActiveCard/Rows/Header/NameLabel") as Label).text, "A", "the first hero, not the first to act")
	controller.click_cell(b.cell)
	assert_eq((controller.hud.get_node("%ActiveCard/Rows/Header/NameLabel") as Label).text, "B", "the selected hero")
	controller.cancel()
	controller.click_cell(a.cell)  # Select A...
	controller.click_cell(Vector2i(3, 0))  # ...and place it.
	assert_true(await _wait_for(controller, [BattleController.State.PLACING]))
	assert_eq(a.cell, Vector2i(3, 0))
	await _tree().process_frame
	_assert_views_in_sync(controller)
	controller.click_cell(Vector2i(1, 2))  # Outside the zone, nothing selected: ignored.
	assert_eq(controller.input_state, BattleController.State.PLACING)
	end_turn.pressed.emit()
	assert_true(await _wait_for(controller, [BattleController.State.IDLE]), "the fight starts")
	assert_true(controller.battle.state.started)
	assert_eq(end_turn.text, "End turn (Space)")
	assert_eq(controller.board_view.highlighted_count(BoardView.Highlight.ZONE), 0)


func test_placement_swaps_heroes_and_cancel_deselects() -> void:
	var controller := _controller("0p 0p 0p\n0  0  0\n0  0  0\n0  0  0\n0  0e 0",
			[_fighter("A", 200), _fighter("B", 190)] as Array[UnitData], [_fighter("E", 100)] as Array[UnitData], false)
	var a := controller.battle.state.units[0]
	var b := controller.battle.state.units[1]
	var a_cell := a.cell
	var b_cell := b.cell
	controller.click_cell(a_cell)
	controller.cancel()
	controller.click_cell(b_cell)  # Nothing selected any more: selects B, moves nothing.
	assert_eq([a.cell, b.cell], [a_cell, b_cell])
	controller.click_cell(b_cell)  # B again: deselects.
	controller.click_cell(a_cell)  # Selects A...
	controller.click_cell(b_cell)  # ...then B's cell: they swap.
	assert_true(await _wait_for(controller, [BattleController.State.PLACING]))
	assert_eq([a.cell, b.cell], [b_cell, a_cell], "swapped")


func _inspect_card(controller: BattleController) -> Control:
	return controller.hud.get_node("%InspectCard") as Control


func test_clicking_a_unit_pins_its_card_until_the_close_button_or_esc() -> void:
	var controller := _controller("0p 0 0 0e", [_fighter("P0", 200)], [_fighter("E0", 100)])
	assert_true(await _wait_for(controller, [BattleController.State.IDLE]))
	var card := _inspect_card(controller)
	controller.click_cell(Vector2i(3, 0))
	assert_true(card.visible, "pinned")
	assert_true((card.get_node("Rows/Header/CloseButton") as Button).visible, "with its ✕")
	controller._hovered_cell = Vector2i(0, 0)  # The mouse leaves the unit (and rests on the active one).
	controller._update_hover()
	assert_true(card.visible, "it stays")
	controller.click_cell(Vector2i(3, 0))
	assert_true(card.visible, "clicking the pinned unit again does nothing")
	(card.get_node("Rows/Header/CloseButton") as Button).pressed.emit()
	assert_false(card.visible, "✕ unpins")
	controller.click_cell(Vector2i(3, 0))
	assert_true(card.visible)
	controller.cancel()
	assert_false(card.visible, "Esc unpins")


func test_esc_stops_aiming_before_it_unpins() -> void:
	var controller := _controller("0p 0 0 0e", [_fighter("P0", 200)], [_fighter("E0", 100)])
	assert_true(await _wait_for(controller, [BattleController.State.IDLE]))
	controller.click_cell(Vector2i(3, 0))
	controller.select_spell(0)
	controller.cancel()
	assert_eq(controller.input_state, BattleController.State.IDLE, "aim stopped")
	assert_true(_inspect_card(controller).visible, "still pinned")
	controller.cancel()
	assert_false(_inspect_card(controller).visible)


func test_clicking_another_unit_moves_the_pin_and_a_click_still_casts() -> void:
	var controller := _controller("0p 0e 0e 0", [_fighter("P0", 200)], [_fighter("E0", 100), _fighter("E1", 90)])
	assert_true(await _wait_for(controller, [BattleController.State.IDLE]))
	var name_path := "Rows/Header/NameLabel"
	controller.click_cell(Vector2i(2, 0))
	assert_eq((_inspect_card(controller).get_node(name_path) as Label).text, "E1 Lv 1")
	controller.select_spell(0)
	var hp_before := controller.battle.state.units[1].hp
	controller.click_cell(Vector2i(1, 0))
	assert_eq((_inspect_card(controller).get_node(name_path) as Label).text, "E0 Lv 1", "the pin moved")
	assert_true(await _wait_for(controller, [BattleController.State.IDLE]))
	assert_true(controller.battle.state.units[1].hp < hp_before, "the same click cast the spell")


func test_a_pinned_unit_that_dies_unpins() -> void:
	var controller := _controller("0p 0 0e", [_fighter("P0", 200)], [_fighter("E0", 1)])
	assert_true(await _wait_for(controller, [BattleController.State.IDLE]))
	controller.click_cell(Vector2i(2, 0))
	assert_true(_inspect_card(controller).visible)
	controller._hud_model.apply(BattleEvents.UnitDied.new(1))
	controller._update_inspected()
	assert_false(_inspect_card(controller).visible, "a fallen unit's card goes away")


func test_heroes_levels_show_in_the_cards() -> void:
	var controller := _controller("0p 0 0 0e", [_fighter("P0", 200)], [_fighter("E0", 100)])
	assert_true(await _wait_for(controller, [BattleController.State.IDLE]))
	controller.player_levels = [7]
	controller._refresh_hud()
	assert_eq((controller.hud.get_node("%ActiveCard/Rows/Header/NameLabel") as Label).text, "P0 · Lv 7")


func test_a_turn_order_chip_hovers_its_unit_and_a_click_focuses_the_camera() -> void:
	var controller := _controller("0p 0 0 0e", [_fighter("P0", 200)], [_fighter("E0", 100)])
	assert_true(await _wait_for(controller, [BattleController.State.IDLE]))
	controller.hud.chip_hovered.emit(1)
	assert_eq(controller._hover_cell(controller.hud.get_node("%TurnTimeline"), Vector2.ZERO), Vector2i(3, 0), "the unit's cell counts as hovered")
	controller.hud.chip_unhovered.emit()
	assert_eq(controller._hover_cell(controller.hud.get_node("%TurnTimeline"), Vector2.ZERO), BoardView.NO_CELL)
	controller.hud.chip_pressed.emit(1)
	assert_eq(controller.camera_rig.position, controller.board_view.cell_to_world(Vector2i(3, 0)))


func test_esc_closes_the_order_overlay_first() -> void:
	var controller := _controller("0p 0 0 0e", [_fighter("P0", 200)], [_fighter("E0", 100)])
	assert_true(await _wait_for(controller, [BattleController.State.IDLE]))
	controller.click_cell(Vector2i(3, 0))
	(controller.hud.get_node("%TurnTimeline/OrderButton") as Button).pressed.emit()
	var overlay := controller.hud.get_node("%OrderOverlay") as Control
	assert_true(overlay.visible)
	controller.cancel()
	assert_false(overlay.visible)
	assert_true(_inspect_card(controller).visible, "the pin waits for the next Esc")


func test_aiming_at_a_unit_previews_its_damage_and_leaving_clears_it() -> void:
	var controller := _controller("0p 0e 0 0", [_fighter("P0", 200)], [_fighter("E0", 100)])
	assert_true(await _wait_for(controller, [BattleController.State.IDLE]))
	var enemy_view := controller.units_view.view(1)
	controller._hovered_cell = Vector2i(1, 0)
	controller._update_hover()
	assert_false(enemy_view.has_preview(), "not aiming: no preview")
	controller.select_spell(0)
	controller._hovered_cell = Vector2i(1, 0)
	controller._update_hover()
	assert_true(enemy_view.has_preview(), "aiming at the enemy")
	assert_eq(enemy_view.preview_text(), "5", "the fighter's 5 damage")
	controller._hovered_cell = Vector2i(2, 0)
	controller._update_hover()
	assert_false(enemy_view.has_preview(), "the mouse moved off")
	controller._hovered_cell = Vector2i(1, 0)
	controller._update_hover()
	controller.cancel()
	assert_false(enemy_view.has_preview(), "aiming stopped")


func test_hovering_a_reachable_cell_labels_the_path_cost_with_its_climbs() -> void:
	var controller := _controller("0p 1 0 0e", [_fighter("P0", 200)], [_fighter("E0", 100)])
	assert_true(await _wait_for(controller, [BattleController.State.IDLE]))
	controller._hovered_cell = Vector2i(2, 0)
	controller._update_hover()
	assert_eq(controller.board_view.path_cost_texts(), ["3 MP", "+1"] as Array[String], "2 steps + 1 climb")
	controller._hovered_cell = Vector2i(3, 0)  # The enemy's cell: not reachable.
	controller._update_hover()
	assert_eq(controller.board_view.path_cost_texts().size(), 0)
	controller._hovered_cell = Vector2i(2, 0)
	controller._update_hover()
	controller.select_spell(0)
	assert_eq(controller.board_view.path_cost_texts().size(), 0, "aiming clears it")


func test_the_prompt_line_follows_the_step() -> void:
	var controller := _controller("0p 0p 0 0e", [_fighter("A", 200), _fighter("B", 190)] as Array[UnitData],
			[_fighter("E", 100)] as Array[UnitData], false)
	var prompt := controller.hud.get_node("%PromptLabel") as Label
	assert_true(prompt.visible)
	assert_true(prompt.text.begins_with("Place your heroes"), prompt.text)
	controller.click_cell(controller.battle.state.units[0].cell)
	assert_true(prompt.text.contains("place A"), prompt.text)
	controller.cancel()
	controller.end_turn()
	assert_true(await _wait_for(controller, [BattleController.State.IDLE]))
	assert_true(prompt.text.begins_with("Move to a blue cell"), prompt.text)
	controller.select_spell(0)
	assert_true(prompt.text.contains("Choose a target for Hit"), prompt.text)
	controller.cancel()
	controller.end_turn()
	assert_true(await _wait_for(controller, [BattleController.State.ENEMY_TURN, BattleController.State.IDLE]))
	if controller.input_state == BattleController.State.ENEMY_TURN:
		assert_true(prompt.text.ends_with("is acting..."), prompt.text)


func test_end_turn_pulses_only_when_nothing_is_left_to_do() -> void:
	var boxed := _fighter("P0", 200)
	boxed.mp = 0
	boxed.ap = 2  # The 3 AP spell is out of reach.
	var controller := _controller("0p 0 0 0e", [boxed], [_fighter("E0", 100)])
	assert_true(await _wait_for(controller, [BattleController.State.IDLE]))
	assert_true(controller.hud.is_end_turn_pulsing(), "no MP, no affordable spell")
	assert_true((controller.hud.get_node("%PromptLabel") as Label).text.begins_with("Nothing left"))
	var normal := _controller("0p 0 0 0e", [_fighter("P0", 200)], [_fighter("E0", 100)])
	assert_true(await _wait_for(normal, [BattleController.State.IDLE]))
	assert_false(normal.hud.is_end_turn_pulsing(), "it can still move")
