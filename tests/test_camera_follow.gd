extends TestCase
## The camera easing after a unit that walks off screen, and leaving the camera alone for a
## walk that stays in view.

const RIG_SCENE := preload("res://scenes/battle/camera_rig.tscn")
const TIME_SCALE := 10.0


class Stage:
	var root := Node3D.new()
	var board := BoardView.new()
	var units := UnitsView.new()
	var player := EventPlayer.new()
	var rig: CameraRig
	var battle: Battle

	func _init(battle_to_show: Battle) -> void:
		battle = battle_to_show
		rig = RIG_SCENE.instantiate() as CameraRig
		root.add_child(board)
		root.add_child(units)
		root.add_child(player)
		root.add_child(rig)
		(Engine.get_main_loop() as SceneTree).root.add_child(root)
		board.build(battle.state.grid)
		units.build(battle.state, board)
		player.setup(units, board, rig)
		rig.camera.size = 4.0  # Zoomed in: a long row doesn't fit.
		rig.target_size = 4.0
		rig.focus(board.cell_to_world(Vector2i(0, 0)))

	func free_nodes() -> void:
		root.free()


func _stage() -> Stage:
	Engine.time_scale = TIME_SCALE
	var hero := BattleFixtures.unit("P0", 200, 3, 6, 20)
	var enemy := BattleFixtures.unit("E0", 100, 3, 6, 20)
	var battle := Battle.new(BattleFixtures.state_with("0p 0 0 0 0 0 0 0 0 0 0 0 0e", [hero], [enemy]))
	battle.start()
	return Stage.new(battle)


func _path(from: int, to: int) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for x in range(from + 1, to + 1):
		cells.append(Vector2i(x, 0))
	return cells


func _tree() -> SceneTree:
	return Engine.get_main_loop() as SceneTree


func _done(stage: Stage) -> void:
	stage.free_nodes()
	Engine.time_scale = 1.0


func test_a_walk_off_screen_is_followed_and_the_camera_settles_on_the_unit() -> void:
	var stage := _stage()
	var view := stage.units.view(0)
	var start := stage.rig.position
	var moved := BattleEvents.UnitMoved.new(0, _path(0, 8), 8)
	stage.player.play([moved] as Array[BattleEvents.Event])  # Not awaited: the test watches it run.
	var followed := false
	for i in 900:
		followed = followed or stage.rig.is_following()
		if not stage.player.is_playing and i > 3:
			break
		await _tree().process_frame
	assert_true(followed, "the camera followed the walking unit")
	assert_false(stage.rig.is_following(), "and let go at the end")
	for i in 300:
		if stage.rig.position.is_equal_approx(stage.rig.clamp_point(view.position)):
			break
		await _tree().process_frame
	assert_true(stage.rig.position.distance_to(stage.rig.clamp_point(view.position)) < 0.05, "settled on the unit: %s vs %s" % [stage.rig.position, view.position])
	assert_true(stage.rig.position.distance_to(start) > 3.0, "it moved a long way")
	_done(stage)


func test_a_short_walk_in_view_leaves_the_camera_still() -> void:
	var stage := _stage()
	var start := stage.rig.position
	stage.player.play([BattleEvents.UnitMoved.new(0, _path(0, 1), 1)] as Array[BattleEvents.Event])
	var ever_followed := false
	for i in 600:
		ever_followed = ever_followed or stage.rig.is_following()
		if not stage.player.is_playing and i > 3:
			break
		await _tree().process_frame
	assert_false(ever_followed, "no follow for a walk that stays comfortably on screen")
	assert_eq(stage.rig.position, start, "the camera didn't move")
	_done(stage)


func test_panning_ends_a_follow_at_once() -> void:
	var stage := _stage()
	stage.rig.follow(stage.units.view(0))
	assert_true(stage.rig.is_following())
	stage.rig.pan_by_view(Vector2(1, 0))
	assert_false(stage.rig.is_following(), "the player's pan takes over")
	stage.rig.follow(stage.units.view(0))
	stage.rig.focus_on(Vector3(2, 0, 0))
	assert_false(stage.rig.is_following(), "so does an explicit focus")
	_done(stage)


func test_follow_eases_toward_a_moving_node_and_a_freed_node_ends_it() -> void:
	var stage := _stage()
	var node := Node3D.new()
	stage.root.add_child(node)
	node.position = Vector3(6, 0, 0)
	stage.rig.bounds = Rect2()
	stage.rig.follow(node)
	for i in 300:
		await _tree().process_frame
	assert_true(stage.rig.position.distance_to(node.position) < 0.1, "caught up with the node")
	node.free()
	await _tree().process_frame
	await _tree().process_frame
	assert_false(stage.rig.is_following(), "the node is gone: the follow ends")
	_done(stage)


func test_is_on_screen_judges_the_projection_with_a_margin() -> void:
	var stage := _stage()
	assert_true(stage.rig.is_on_screen([stage.rig.position] as Array[Vector3]), "the focus point is on screen")
	assert_false(stage.rig.is_on_screen([stage.board.cell_to_world(Vector2i(12, 0))] as Array[Vector3]), "a far cell is not")
	assert_false(stage.rig.is_on_screen([stage.rig.position, stage.board.cell_to_world(Vector2i(12, 0))] as Array[Vector3]), "all points must be")
	_done(stage)


func test_a_pan_during_a_followed_walk_is_not_undone_when_it_ends() -> void:
	var stage := _stage()
	stage.rig.bounds = Rect2()
	var moved := BattleEvents.UnitMoved.new(0, _path(0, 8), 8)
	stage.player.play([moved] as Array[BattleEvents.Event])
	for i in 200:
		if stage.rig.is_following():
			break
		await _tree().process_frame
	assert_true(stage.rig.is_following(), "following")
	stage.rig.pan_by_view(Vector2(0, 3))  # The player takes over.
	var panned_to := stage.rig.position
	for i in 900:
		if not stage.player.is_playing and i > 3:
			break
		await _tree().process_frame
	for i in 60:
		await _tree().process_frame
	assert_true(stage.rig.position.distance_to(panned_to) < 0.01, "the camera stayed where the player put it: %s vs %s" % [stage.rig.position, panned_to])
	_done(stage)
