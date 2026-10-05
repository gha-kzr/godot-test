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
		assert_eq(view.hp_text(), "%d/%d" % [unit.hp, unit.max_hp()], "unit %d HP label" % unit.id)
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
	var level := stage.board.active_theme().level_height
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
	poison.icon = load("res://ui/icons/fireball.svg") as Texture2D
	await view.play_status_applied(poison, 3)
	assert_eq(view.status_turns_texts(), ["3"] as Array[String])
	assert_true(view.has_node("FloatingNumber"), "the status name floats up")
	assert_eq(view.status_icon_textures(), [poison.icon] as Array[Texture2D], "an icon, not a text tag")
	var guard := BattleFixtures.status("Guard", 2, 0, [BattleFixtures.modifier(StatModifier.Stat.MP, 1)] as Array[StatModifier], true)
	await view.play_status_applied(guard, 2)
	assert_eq(view.status_turns_texts(), ["3", "2"] as Array[String], "in status order")
	await view.play_status_applied(poison, 3)
	assert_eq(view.status_turns_texts(), ["3", "2"] as Array[String], "a refresh updates in place")
	await view.play_status_ticked(poison)
	await view.play_status_expired(poison)
	await (Engine.get_main_loop() as SceneTree).process_frame
	assert_eq(view.status_turns_texts(), ["2"] as Array[String])
	_done(stage)


func test_sync_rebuilds_status_tags_from_the_state() -> void:
	var stage := _stage()
	var unit := stage.battle.state.units[1]
	var poison := BattleFixtures.status("Poison", 3, 2)
	unit.add_status(poison, 0)
	unit.statuses[0].turns_left = 1
	stage.units.sync(stage.battle.state)
	assert_eq(stage.units.view(1).status_turns_texts(), ["1"] as Array[String], "turns left from the state")
	unit.statuses.clear()
	stage.units.sync(stage.battle.state)
	await (Engine.get_main_loop() as SceneTree).process_frame
	assert_eq(stage.units.view(1).status_turns_texts(), [] as Array[String])
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
			tags_seen.append(stage.units.view(1).status_turns_texts()))
	await stage.player.play(events)
	assert_eq(played, events, "applied, ticked, hit, expired: all played in order")
	assert_eq(tags_seen, [["1"], []], "the player itself updates the tags")
	stage.units.sync(stage.battle.state)
	await (Engine.get_main_loop() as SceneTree).process_frame
	assert_eq(stage.units.view(1).status_turns_texts(), [] as Array[String], "expired")
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


func test_preview_badge_shows_amount_skull_and_status_icons() -> void:
	var stage := _stage()
	var view := stage.units.view(1)
	var entry := DamagePreview.Entry.new()
	entry.unit_id = 1
	entry.min_damage = 8
	entry.max_damage = 11
	entry.can_kill = true
	entry.statuses = [BattleFixtures.status("Poison", 3, 2)] as Array[StatusData]
	stage.units.show_previews([entry] as Array[DamagePreview.Entry])
	assert_true(view.has_preview())
	assert_eq(view.preview_text(), "8-11")
	assert_eq(view.preview_icon_count(), 2, "a skull and a status")
	assert_false(stage.units.view(0).has_preview(), "only the listed units")
	stage.units.show_previews([] as Array[DamagePreview.Entry])
	assert_false(view.has_preview(), "replaced")
	stage.units.show_previews([entry] as Array[DamagePreview.Entry])
	stage.units.clear_previews()
	assert_false(view.has_preview())
	_done(stage)


# --- Models ---

const KNIGHT_MODEL := preload("res://assets/models/knight.tscn")


func _model_unit(unit_name: String, initiative: int, height := 1.4) -> UnitData:
	var data := BattleFixtures.unit(unit_name, initiative, 3, 6, 20)
	data.spells = [BattleFixtures.damage_spell()] as Array[SpellData]
	data.model_scene = KNIGHT_MODEL
	data.model_scale = 1.0
	data.model_height = height
	return data


func _model_stage(layout := "0p 0 0 0e", enemy_scale := 1.0) -> Stage:
	Engine.time_scale = TIME_SCALE
	var state := BattleFixtures.state_with(layout, [_model_unit("P0", 200)], [_model_unit("E0", 100, 1.4)])
	state.units[1].visual_scale = enemy_scale
	var battle := Battle.new(state)
	battle.start()
	return Stage.new(battle)


func _animation_of(view: UnitView) -> String:
	return (view.model().find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer).current_animation


func test_a_unit_with_a_model_replaces_the_capsule_and_starts_idle() -> void:
	var stage := _model_stage()
	var view := stage.units.view(0)
	assert_true(view.has_model())
	var capsule := view.get_node("Body").find_child("Placeholder", true, false)
	assert_true(capsule == null or capsule.is_queued_for_deletion(), "the capsule is on its way out")
	assert_true(_animation_of(view) == "Idle", _animation_of(view))
	_done(stage)


func test_labels_icons_preview_and_click_target_follow_the_model_height_and_scale() -> void:
	var stage := _model_stage("0p 0 0 0e", 1.5)
	var hero := stage.units.view(0)
	var boss := stage.units.view(1)
	assert_true(is_equal_approx(hero.get_node("HpLabel").position.y, 1.4 + UnitView.HP_LABEL_ABOVE))
	assert_true(is_equal_approx(hero.get_node("StatusRow").position.y, 1.4 + UnitView.STATUS_ROW_ABOVE))
	assert_true(is_equal_approx(boss.get_node("HpLabel").position.y, 1.4 * 1.5 + UnitView.HP_LABEL_ABOVE), "scaled with the boss")
	assert_true(is_equal_approx(boss.get_node("StatusRow").position.y, 1.4 * 1.5 + UnitView.STATUS_ROW_ABOVE))
	var shape := (boss.get_node("PickBody/Collision") as CollisionShape3D).shape as CapsuleShape3D
	assert_true(is_equal_approx(shape.height, 1.4 * 1.5) and is_equal_approx(shape.radius, 0.3 * 1.5), "the click target grows too")
	var entry := DamagePreview.Entry.new()
	entry.max_damage = 5
	boss.show_preview(entry)
	assert_true(is_equal_approx(boss.get_node("Preview").position.y, 1.4 * 1.5 + UnitView.PREVIEW_ABOVE), "and the damage preview")
	_done(stage)


func test_a_placeholder_keeps_its_old_anchors() -> void:
	var stage := _stage()
	var view := stage.units.view(0)
	assert_false(view.has_model())
	assert_true(is_equal_approx(view.get_node("HpLabel").position.y, 1.25), "0.9 + 0.35, as before")
	_done(stage)


func test_melee_spells_attack_ranged_ones_cast_and_a_spell_can_name_its_animation() -> void:
	var stage := _model_stage()
	var view := stage.units.view(0)
	assert_eq(view._cast_animation(BattleFixtures.damage_spell(3, 1, 1)), &"Attack")
	assert_eq(view._cast_animation(BattleFixtures.damage_spell(3, 1, 4)), &"Cast")
	assert_eq(view._cast_animation(null), &"Attack")
	var special := BattleFixtures.damage_spell(3, 1, 4)
	special.cast_animation = &"Victory"
	assert_eq(view._cast_animation(special), &"Victory")
	_done(stage)


func test_walking_hitting_casting_and_dying_play_their_animations() -> void:
	var stage := _model_stage("0p 0 0 0e")
	var view := stage.units.view(0)
	var wait := func(seconds: float) -> void:
		await (Engine.get_main_loop() as SceneTree).create_timer(seconds).timeout
	(func() -> void: await view.play_move([Vector2i(1, 0)] as Array[Vector2i])).call()  # Runs until its first await.
	assert_true(_animation_of(view) == "Walk", "walking: %s" % _animation_of(view))
	await wait.call(2.0)
	assert_true(_animation_of(view) == "Idle", "idle again")
	(func() -> void: await view.play_cast(Vector2i(2, 0), BattleFixtures.damage_spell(3, 1, 1))).call()
	assert_true(_animation_of(view) == "Attack", "a melee spell slashes: %s" % _animation_of(view))
	await wait.call(2.0)
	var victim := stage.units.view(1)
	(func() -> void: await victim.play_hit(3, 10)).call()
	assert_true(_animation_of(victim) == "Hit", "hit: %s" % _animation_of(victim))
	await wait.call(2.0)
	assert_true(_animation_of(victim) == "Idle", "back to idle when it survives")
	(func() -> void: await victim.play_death()).call()
	assert_true(_animation_of(victim) == "Death", "death: %s" % _animation_of(victim))
	await wait.call(3.0)
	assert_false(victim.visible)
	_done(stage)


func test_units_start_facing_the_nearest_enemy() -> void:
	var stage := _model_stage("0p 0 0 0e")
	# The hero at (0, 0) looks along +x toward the enemy at (3, 0): a yaw of a quarter turn.
	assert_true(is_equal_approx(stage.units.view(0).get_node("Body").rotation.y, PI / 2.0), "hero faces +x")
	assert_true(is_equal_approx(stage.units.view(1).get_node("Body").rotation.y, -PI / 2.0), "enemy faces -x")
	_done(stage)


func test_the_shipped_roster_has_models() -> void:
	for unit_name in ["knight", "mage", "ranger", "brute", "skeleton_archer", "ghoul", "ghost"]:
		var data := load("res://data/units/%s.tres" % unit_name) as UnitData
		assert_true(data.model_scene != null, "%s has a model" % unit_name)
		assert_true(data.model_scale > 0.0 and data.model_height > 0.0, "%s has a scale and a height" % unit_name)


func test_a_synced_dead_then_alive_unit_stands_again() -> void:
	var stage := _model_stage("0p 0 0 0e")
	var victim := stage.units.view(1)
	(func() -> void: await victim.play_death()).call()
	await (Engine.get_main_loop() as SceneTree).create_timer(3.0).timeout
	assert_false(victim.visible)
	stage.units.sync(stage.battle.state)  # The state says it is alive (a desync or an undo).
	assert_true(victim.visible)
	assert_true(_animation_of(victim) == "Idle", "not left in the Death pose: %s" % _animation_of(victim))
	_done(stage)


func test_a_hit_that_did_no_damage_plays_no_hit_animation() -> void:
	var stage := _model_stage("0p 0 0 0e")
	var victim := stage.units.view(1)
	victim.model().play(&"Walk")  # Mid-walk, say: a hit that does nothing must not touch its animation.
	(func() -> void: await victim.play_hit(0, 20)).call()
	await (Engine.get_main_loop() as SceneTree).create_timer(0.8).timeout
	assert_true(_animation_of(victim) == "Walk", "untouched: %s" % _animation_of(victim))
	await (Engine.get_main_loop() as SceneTree).create_timer(1.0).timeout
	_done(stage)


func test_casting_and_hitting_dont_hold_the_queue_for_the_whole_animation() -> void:
	var stage := _model_stage("0p 0 0 0e")
	var hero := stage.units.view(0)
	await hero.play_cast(Vector2i(1, 0), BattleFixtures.damage_spell(3, 1, 1))
	assert_true(_animation_of(hero) == "Attack", "the queue moved on while the slash goes on: %s" % _animation_of(hero))
	var victim := stage.units.view(1)
	await victim.play_hit(3, 10)
	assert_true(_animation_of(victim) == "Hit", "same for the flinch: %s" % _animation_of(victim))
	_done(stage)


func test_a_buff_or_a_heal_is_cast_not_swung() -> void:
	var stage := _model_stage("0p 0 0 0e")
	var view := stage.units.view(0)
	var heal := HealEffect.new()
	var mend := BattleFixtures.effect_spell([heal] as Array[EffectData], 3, 0, 1)
	assert_eq(view._cast_animation(mend), &"Cast", "a heal of range 1 isn't a sword swing")
	assert_eq(view._cast_animation(BattleFixtures.damage_spell(3, 1, 1)), &"Attack", "a melee damage spell still is")
	_done(stage)


func test_every_displacement_ends_on_its_cell_at_full_size() -> void:
	var stage := _stage("0p 0 0 0 0 0\n0 0 0 0 0 0e")
	var view := stage.units.view(0)
	for kind: MoveEffect.Kind in MoveEffect.Kind.values():
		var cell := Vector2i(1 + kind % 4, kind / 4)
		await view.play_displaced([cell] as Array[Vector2i], kind)
		assert_true(view.position.is_equal_approx(stage.board.cell_to_world(cell)), "%s: on its cell" % MoveEffect.Kind.keys()[kind])
		assert_eq(view.picked_cell(), cell, "%s: picked there" % MoveEffect.Kind.keys()[kind])
	assert_true(view.get_node("Body").scale.is_equal_approx(Vector3.ONE), "a blink grows back")
	_done(stage)


func test_the_event_player_plays_a_displacement() -> void:
	var stage := _stage("0p 0 0 0e")
	var displaced := BattleEvents.UnitDisplaced.new(0, Vector2i(0, 0), [Vector2i(1, 0), Vector2i(2, 0)] as Array[Vector2i], MoveEffect.Kind.PUSH)
	stage.battle.state.units[0].cell = Vector2i(2, 0)
	await stage.player.play([displaced] as Array[BattleEvents.Event])
	_assert_in_sync(stage)
	_done(stage)


func test_a_charge_dashes_then_swings_and_ends_in_sync() -> void:
	var stage := _stage("0p 0 0 0e")
	var charge := load("res://data/spells/charge.tres") as SpellData
	stage.battle.state.units[0].data.spells = [charge] as Array[SpellData]
	var result := stage.battle.perform(BattleActions.CastSpell.new(0, 0, Vector2i(3, 0)))
	assert_true(result.ok(), result.error)
	await stage.player.play(result.events)
	_assert_in_sync(stage)
	_done(stage)
