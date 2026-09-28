extends TestCase
## The battle scene end to end: turn loop, player commands, enemy turns, result, restart.
## Time runs fast; waits are bounded by frames and the runner's per-test timeout.

const BATTLE_SCENE := preload("res://scenes/battle/battle.tscn")
const TIME_SCALE := 30.0
const MAX_WAIT_FRAMES := 3000


func _tree() -> SceneTree:
	return Engine.get_main_loop() as SceneTree


## The slice battle (enemy Archer acts first), or a small custom one.
func _controller(layout := "", players: Array[UnitData] = [], enemies: Array[UnitData] = []) -> BattleController:
	Engine.time_scale = TIME_SCALE
	var controller := BATTLE_SCENE.instantiate() as BattleController
	controller.rng_seed = 7
	if not layout.is_empty():
		var map := MapData.new()
		map.layout = layout
		controller.map = map
		controller.players = players
		controller.enemies = enemies
	_tree().root.add_child(controller)
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
		assert_eq(view.hp_text(), "%d/%d" % [unit.hp, unit.data.max_hp], "unit %d HP" % unit.id)
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
	assert_true(await _wait_for(controller, [BattleController.State.IDLE]))


func test_a_failed_restart_keeps_the_current_battle() -> void:
	var controller := _controller("0p 0 0 0 0e", [_fighter("P0", 200)], [_fighter("E0", 100)])
	assert_true(await _wait_for(controller, [BattleController.State.IDLE]))
	var old_battle := controller.battle
	Engine.time_scale = 1.0  # A slow walk, to restart in the middle of it.
	controller.click_cell(Vector2i(3, 0))
	await _tree().process_frame
	assert_eq(controller.input_state, BattleController.State.ANIMATING, "mid-walk")
	controller.map = null
	expect_error("no map set")
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
