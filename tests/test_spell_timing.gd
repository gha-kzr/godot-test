extends TestCase
## Per-spell cast timing: cut and borrowed animations, the delay before the effects land and
## projectiles.

const KNIGHT := preload("res://assets/quaternius/characters/Knight_Male.fbx")
const WIZARD := preload("res://assets/quaternius/characters/Wizard.fbx")
const BARREL := preload("res://assets/quaternius/dungeon/Barrel.fbx")
const TIME_SCALE := 10.0


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


func _tree() -> SceneTree:
	return Engine.get_main_loop() as SceneTree


func _model(scene: PackedScene) -> UnitModel:
	var model := UnitModel.new()
	_tree().root.add_child(model)
	model.setup(scene, 0.5, Color(0, 0, 0, 0))
	return model


func _player_of(model: UnitModel) -> AnimationPlayer:
	return model.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer


func _spell() -> SpellData:
	return BattleFixtures.damage_spell(2, 1, 5, 3)


func test_timing_fields_are_validated() -> void:
	var spell := _spell()
	assert_eq(spell.get_validation_errors().size(), 0, "defaults are valid")
	spell.animation_end = 0.5
	spell.animation_start = 0.5
	assert_eq(spell.get_validation_errors().size(), 1, "end must come after start")
	spell.animation_end = 0.0
	spell.animation_speed = 0.0
	spell.impact_delay = -0.5
	spell.projectile = PackedScene.new()
	spell.projectile_speed = 0.0
	assert_eq(spell.get_validation_errors().size(), 3, "speed, delay and projectile speed")
	spell.animation_speed = 1.0
	spell.impact_delay = 0.0
	spell.projectile_speed = 5.0
	assert_eq(spell.get_validation_errors().size(), 0)


func test_a_clip_is_cut_and_sped_up_then_hands_back_to_idle() -> void:
	Engine.time_scale = TIME_SCALE
	var model := _model(KNIGHT)
	var full := model.play(&"Attack")
	var playing := model.play_clip(&"Attack", null, "", 0.2, 0.6, 2.0)
	assert_true(full > 0.6, "the slash is longer than the cut")
	assert_true(is_equal_approx(playing, 0.2), "0.4 s of animation at double speed is 0.2 s: %f" % playing)
	var player := _player_of(model)
	assert_true(player.current_animation_position >= 0.19, "it starts at the cut's start: %f" % player.current_animation_position)
	assert_eq(player.speed_scale, 1.0, "the player's own speed scale stays 1")
	for i in 600:
		if player.current_animation.ends_with("|Idle"):
			break
		await _tree().process_frame
	assert_true(player.current_animation.ends_with("|Idle"), "back to Idle at the cut's end: %s" % player.current_animation)
	model.free()
	Engine.time_scale = 1.0


func test_a_later_animation_is_not_cut_short_by_an_earlier_clips_timer() -> void:
	Engine.time_scale = TIME_SCALE
	var model := _model(KNIGHT)
	model.play_clip(&"Attack", null, "", 0.0, 0.3, 1.0)
	model.play(&"Death")
	for i in 120:
		await _tree().process_frame
	assert_true(_player_of(model).assigned_animation.ends_with("|Death"), "the death stays: %s" % _player_of(model).assigned_animation)
	model.free()
	Engine.time_scale = 1.0


func test_an_animation_can_be_borrowed_from_another_model_file() -> void:
	var model := _model(WIZARD)
	var length := model.play_clip(&"Attack", KNIGHT, "SwordSlash")
	assert_true(length > 0.0, "the wizard swings the knight's sword slash")
	assert_true(_player_of(model).current_animation.begins_with("borrowed_"), "it plays the borrowed clip: %s" % _player_of(model).current_animation)
	assert_eq(model.play_clip(&"Attack", KNIGHT, "SwordSlash"), length, "borrowed once, found again")
	assert_true(model.play_clip(&"Attack", KNIGHT, "") > 0.0, "an empty name takes the file's first animation")
	model.free()


func test_a_file_without_the_animation_or_a_fitting_skeleton_plays_nothing() -> void:
	var model := _model(WIZARD)
	expect_error("no animation")
	assert_eq(model.play_clip(&"Attack", KNIGHT, "NoSuchAnimation"), 0.0, "no such animation")
	expect_error("has no animation")
	assert_eq(model.play_clip(&"Attack", BARREL, ""), 0.0, "a prop with no animations")
	model.free()


func test_a_file_whose_skeleton_does_not_fit_is_refused() -> void:
	var root := Node3D.new()
	var other := AnimationPlayer.new()
	other.name = "AnimationPlayer"
	var wave := Animation.new()
	wave.length = 1.0
	for bone in ["Tail", "Wing", "Horn", "Fin"]:
		var track := wave.add_track(Animation.TYPE_POSITION_3D)
		wave.track_set_path(track, NodePath("Rig/Skeleton3D:%s" % bone))
	var library := AnimationLibrary.new()
	library.add_animation(&"Wave", wave)
	other.add_animation_library("", library)
	root.add_child(other)
	other.owner = root
	var scene := PackedScene.new()
	scene.pack(root)
	root.free()
	var model := _model(KNIGHT)
	expect_error("doesn't fit")
	assert_eq(model.play_clip(&"Attack", scene, "Wave"), 0.0, "refused: its bones aren't on the knight")
	model.free()


func test_a_spell_with_a_borrowed_clip_makes_its_caster_play_it() -> void:
	var hero := BattleFixtures.unit("P0", 200, 3, 6, 20)
	hero.model_scene = WIZARD
	hero.model_scale = 0.5
	var spell := _spell()
	spell.animation_scene = KNIGHT
	spell.animation_name = "SwordSlash"
	hero.spells = [spell] as Array[SpellData]
	var stage := Stage.new(Battle.new(BattleFixtures.state_with("0p 0 0 0e", [hero], [BattleFixtures.unit("E0", 100, 3, 6, 40)])))
	stage.battle.start()
	var view := stage.units.view(0)
	view.play_cast(Vector2i(3, 0), spell)
	assert_true(_player_of(view.model()).current_animation.begins_with("borrowed_"), "the caster plays the borrowed clip")
	var plain := _spell()
	view.play_cast(Vector2i(3, 0), plain)
	assert_false(_player_of(view.model()).current_animation.begins_with("borrowed_"), "a spell without one plays the caster's own: %s" % _player_of(view.model()).current_animation)
	stage.root.free()


func _landing_time(spell: SpellData, watch_projectile := false) -> Dictionary:
	Engine.time_scale = TIME_SCALE
	var hero := BattleFixtures.unit("P0", 200, 3, 6, 20)
	hero.spells = [spell] as Array[SpellData]
	var stage := Stage.new(Battle.new(BattleFixtures.state_with("0p 0 0 0e", [hero], [BattleFixtures.unit("E0", 100, 3, 6, 40)])))
	stage.battle.start()
	var result := stage.battle.perform(BattleActions.CastSpell.new(0, 0, Vector2i(3, 0)))
	var started := Time.get_ticks_msec()
	var landed := [-1.0]
	stage.player.event_played.connect(func(event: BattleEvents.Event) -> void:
		if event is BattleEvents.SpellCast:
			landed[0] = -2.0  # The cast phase is over: the effects come next.
		elif event is BattleEvents.DamageDealt and landed[0] == -2.0:
			landed[0] = (Time.get_ticks_msec() - started) / 1000.0 * TIME_SCALE)
	stage.player.play(result.events)
	var saw_projectile := false
	for i in 1200:
		if watch_projectile and stage.board.find_child("Bolt", true, false) != null:
			saw_projectile = true
		if not stage.player.is_playing and i > 3:
			break
		await _tree().process_frame
	var left_over := stage.board.find_child("Bolt", true, false) != null
	stage.root.free()
	Engine.time_scale = 1.0
	return {"landed": landed[0], "saw": saw_projectile, "left_over": left_over}


func test_the_effects_land_after_the_spells_impact_delay() -> void:
	var default_timing: Dictionary = await _landing_time(_spell())
	var slow := _spell()
	slow.impact_delay = 1.2
	var delayed: Dictionary = await _landing_time(slow)
	assert_true(delayed["landed"] >= 1.1, "waited for the delay: %f" % delayed["landed"])
	assert_true(default_timing["landed"] < 1.0, "the default pacing is quicker: %f" % default_timing["landed"])
	var quick := _spell()
	quick.impact_delay = 0.0
	var instant: Dictionary = await _landing_time(quick)
	assert_true(instant["landed"] >= 0.0 and instant["landed"] < default_timing["landed"], "a zero delay lands at once: %f" % instant["landed"])


func test_a_projectile_flies_to_the_target_before_the_effects_land() -> void:
	var bolt := Node3D.new()
	bolt.name = "Bolt"
	var packed := PackedScene.new()
	packed.pack(bolt)
	bolt.free()
	var spell := _spell()
	spell.impact_delay = 0.1
	spell.projectile = packed
	spell.projectile_speed = 3.0  # Three cells away: a second of flight.
	var flown: Dictionary = await _landing_time(spell, true)
	assert_true(flown["saw"], "the projectile was on the board")
	assert_false(flown["left_over"], "and gone once it landed")
	assert_true(flown["landed"] >= 0.9, "the effects waited for the flight: %f" % flown["landed"])


func test_a_refused_borrow_is_remembered_and_logged_once() -> void:
	var model := _model(WIZARD)
	expect_error("has no animation")
	assert_eq(model.play_clip(&"Attack", BARREL, ""), 0.0)
	assert_eq(model.play_clip(&"Attack", BARREL, ""), 0.0, "the second try doesn't log (the test would fail on a second error)")
	model.free()
