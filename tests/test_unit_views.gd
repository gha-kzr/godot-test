extends TestCase
## Unit views and event playback, awaited for real on the live scene tree. Time runs
## faster so tweens finish quickly.

const TIME_SCALE := 20.0


class Stage:
	var root := Node3D.new()
	var board := BoardView.new()
	var units := UnitsView.new()
	var player := EventPlayer.new()
	var battle: Battle

	func _init(battle_to_show: Battle) -> void:
		battle = battle_to_show
		root.add_child(board)
		root.add_child(units)
		root.add_child(player)
		(Engine.get_main_loop() as SceneTree).root.add_child(root)
		board.build(battle.state.grid)
		units.build(battle.state, board)
		player.setup(units, board)

	func free_nodes() -> void:
		root.free()


func _fighter(unit_name: String, initiative: int, max_hp := 20) -> UnitData:
	var data := BattleFixtures.unit(unit_name, initiative, 3, 6, max_hp)
	data.spells = [BattleFixtures.damage_spell()] as Array[SpellData]
	data.color = Color.CORNFLOWER_BLUE
	return data


func _stage(layout := "0p 1 0 0e", enemy_hp := 20) -> Stage:
	Engine.time_scale = TIME_SCALE
	var battle := Battle.new(BattleFixtures.state_with(layout, [_fighter("P0", 200)], [_fighter("E0", 100, enemy_hp)]))
	battle.start()
	return Stage.new(battle)


func _done(stage: Stage) -> void:
	stage.free_nodes()
	Engine.time_scale = 1.0


func _assert_in_sync(stage: Stage) -> void:
	for unit in stage.battle.state.units:
		var view := stage.units.view(unit.id)
		assert_eq(view.visible, unit.is_alive(), "unit %d visibility" % unit.id)
		assert_eq(view.hp_text(), "%d/%d" % [unit.hp, unit.data.max_hp], "unit %d HP label" % unit.id)
		if unit.is_alive():
			assert_true(view.position.is_equal_approx(stage.board.cell_to_world(unit.cell)), "unit %d position" % unit.id)


func test_views_start_on_their_units_cells() -> void:
	var stage := _stage()
	_assert_in_sync(stage)
	assert_eq(stage.units.view(0).name, "Unit0")
	_done(stage)


func test_move_climbs_before_crossing_and_crosses_before_dropping() -> void:
	var stage := _stage()  # Cells (0,0) level 0, (1,0) level 1, (2,0) level 0.
	Engine.time_scale = 1.0  # Real speed, so frames sample the middle of each step.
	var view := stage.units.view(0)
	var level := stage.board.board_theme.level_height
	# Lambdas capture locals by value; a Dictionary is shared by reference.
	var probe := {"moving": true, "crossing_samples": 0}
	var watch := func() -> void:
		while probe.moving:
			var x := view.position.x
			if (x > 0.05 and x < 0.95) or (x > 1.05 and x < 1.95):
				probe.crossing_samples += 1
				assert_true(is_equal_approx(view.position.y, level),
						"crossing at level 1 (x %.2f, y %.2f)" % [x, view.position.y])
			await (Engine.get_main_loop() as SceneTree).process_frame
	watch.call()
	await view.play_move([Vector2i(1, 0), Vector2i(2, 0)] as Array[Vector2i])
	probe.moving = false
	assert_true(probe.crossing_samples > 0, "sampled the crossings")
	assert_true(view.position.is_equal_approx(stage.board.cell_to_world(Vector2i(2, 0))), "on the last cell")
	_done(stage)


func test_hit_updates_the_label_and_floats_a_number() -> void:
	var stage := _stage()
	var view := stage.units.view(1)
	await view.play_hit(5, 15)
	assert_eq(view.hp_text(), "15/20")
	assert_true(view.has_node("FloatingNumber"), "a floating number drifts up")
	_done(stage)


func test_death_hides_the_unit() -> void:
	var stage := _stage()
	var view := stage.units.view(1)
	await view.play_death()
	assert_false(view.visible)
	_done(stage)


func test_event_player_plays_a_battle_in_order_and_ends_in_sync() -> void:
	var stage := _stage("0p 1 0 0e", 5)
	var played: Array[BattleEvents.Event] = []
	stage.player.event_played.connect(func(event: BattleEvents.Event) -> void: played.append(event))
	var events: Array[BattleEvents.Event] = []
	for action: BattleActions.Action in [BattleActions.Move.new(0, Vector2i(2, 0)), BattleActions.CastSpell.new(0, 0, Vector2i(3, 0))]:
		var result := stage.battle.perform(action)
		assert_true(result.ok(), result.error)
		events.append_array(result.events)
	await stage.player.play(events)
	assert_eq(played, events, "every event, in order")
	assert_false(stage.player.is_playing)
	assert_eq(stage.board.highlighted_count(BoardView.Highlight.AREA), 0, "area flash cleared")
	_assert_in_sync(stage)
	_done(stage)


func test_event_player_rejects_overlapping_playback() -> void:
	var stage := _stage()
	var result := stage.battle.perform(BattleActions.Move.new(0, Vector2i(1, 0)))
	stage.player.play(result.events)  # Not awaited: still playing.
	expect_error("already playing")
	await stage.player.play(result.events)
	assert_true(stage.player.is_playing, "the first playback is still running")
	while stage.player.is_playing:
		await (Engine.get_main_loop() as SceneTree).process_frame
	_done(stage)


func test_unknown_unit_view_is_an_error() -> void:
	var stage := _stage()
	expect_error("no view for unit 7")
	assert_eq(stage.units.view(7), null)
	_done(stage)


func test_sync_snaps_views_back_to_the_state() -> void:
	var stage := _stage()
	var view := stage.units.view(1)
	await view.play_death()
	var unit := stage.battle.state.units[1]
	unit.cell = Vector2i(2, 0)
	unit.hp = 12
	stage.units.sync(stage.battle.state)  # The unit is alive in the state (e.g. after an undo).
	assert_true(view.visible, "visible again")
	assert_eq(view.hp_text(), "12/20")
	assert_eq(view.picked_cell(), Vector2i(2, 0), "clickable on its cell")
	assert_true(view.position.is_equal_approx(stage.board.cell_to_world(Vector2i(2, 0))))
	assert_eq((view.get_node("Body") as Node3D).scale, Vector3.ONE, "death squash undone")
	unit.hp = 0
	stage.units.sync(stage.battle.state)
	assert_false(view.visible)
	assert_eq(view.picked_cell(), BoardView.NO_CELL)
	_done(stage)


func test_stop_abandons_playback_even_if_a_view_is_freed() -> void:
	var stage := _stage()
	var result := stage.battle.perform(BattleActions.Move.new(0, Vector2i(2, 0)))
	var finished := {"value": false}
	var playback := func() -> void:
		await stage.player.play(result.events)
		finished.value = true
	playback.call()
	await (Engine.get_main_loop() as SceneTree).process_frame
	stage.units.build(stage.battle.state, stage.board)  # Frees the walking view mid-tween.
	stage.player.stop()
	assert_false(stage.player.is_playing, "ready to play again")
	await stage.player.play([] as Array[BattleEvents.Event])
	assert_false(stage.player.is_playing)
	assert_false(finished.value, "the abandoned playback never reports completion")
	_done(stage)


# --- Statuses ---

func test_status_events_play_and_tags_follow() -> void:
	var stage := _stage()
	var view := stage.units.view(1)
	var poison := BattleFixtures.status("Poison", 3, 2)
	await view.play_status_applied(poison, 3)
	assert_eq(view.status_tag_texts(), ["P3"] as Array[String])
	assert_true(view.has_node("FloatingNumber"), "the status name floats up")
	var guard := BattleFixtures.status("Guard", 2, 0, [BattleFixtures.modifier(StatModifier.Stat.MP, 1)] as Array[StatModifier], true)
	await view.play_status_applied(guard, 2)
	assert_eq(view.status_tag_texts(), ["P3", "G2"] as Array[String], "in status order")
	await view.play_status_applied(poison, 3)
	assert_eq(view.status_tag_texts(), ["P3", "G2"] as Array[String], "a refresh updates in place")
	await view.play_status_ticked(poison)
	await view.play_status_expired(poison)
	await (Engine.get_main_loop() as SceneTree).process_frame
	assert_eq(view.status_tag_texts(), ["G2"] as Array[String])
	_done(stage)


func test_sync_rebuilds_status_tags_from_the_state() -> void:
	var stage := _stage()
	var unit := stage.battle.state.units[1]
	var poison := BattleFixtures.status("Poison", 3, 2)
	unit.add_status(poison, 0)
	unit.statuses[0].turns_left = 1
	stage.units.sync(stage.battle.state)
	assert_eq(stage.units.view(1).status_tag_texts(), ["P1"] as Array[String], "turns left from the state")
	unit.statuses.clear()
	stage.units.sync(stage.battle.state)
	await (Engine.get_main_loop() as SceneTree).process_frame
	assert_eq(stage.units.view(1).status_tag_texts(), [] as Array[String])
	_done(stage)


func test_event_player_plays_status_turns_end_to_end() -> void:
	var stage := _stage("0p 0 0 0e")
	var poison := BattleFixtures.status("Poison", 1, 3)
	var spell := BattleFixtures.effect_spell([BattleFixtures.apply_status(poison)] as Array[EffectData], 3, 1, 3)
	stage.battle.state.units[0].data.spells = [spell] as Array[SpellData]
	var events: Array[BattleEvents.Event] = []
	for action: BattleActions.Action in [BattleActions.CastSpell.new(0, 0, Vector2i(3, 0)), BattleActions.EndTurn.new(0),
			BattleActions.EndTurn.new(1)]:
		var result := stage.battle.perform(action)
		assert_true(result.ok(), result.error)
		events.append_array(result.events)
	var played: Array[BattleEvents.Event] = []
	var tags_seen: Array = []
	stage.player.event_played.connect(func(event: BattleEvents.Event) -> void:
		played.append(event)
		if event is BattleEvents.StatusApplied or event is BattleEvents.StatusExpired:
			tags_seen.append(stage.units.view(1).status_tag_texts()))
	await stage.player.play(events)
	assert_eq(played, events, "applied, ticked, hit, expired: all played in order")
	assert_eq(tags_seen, [["P1"], []], "the player itself updates the tags")
	stage.units.sync(stage.battle.state)
	await (Engine.get_main_loop() as SceneTree).process_frame
	assert_eq(stage.units.view(1).status_tag_texts(), [] as Array[String], "expired")
	_assert_in_sync(stage)
	_done(stage)


func test_zero_changes_float_no_number() -> void:
	var stage := _stage()
	var view := stage.units.view(1)
	await view.play_heal(0, 20)
	assert_false(view.has_node("FloatingNumber"), "no +0")
	await view.play_hit(0, 20)
	assert_false(view.has_node("FloatingNumber"), "no -0")
	_done(stage)
