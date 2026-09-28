extends TestCase
## Board and camera views, built headless. Picking is in test_picking.gd.

const LAYOUT := """
	0p 1 #
	2  . 0e
"""


func _board() -> BoardView:
	var map := MapData.new()
	map.layout = LAYOUT
	var board := BoardView.new()
	board.build(map.parse().grid)
	return board


func _cell_bodies(board: BoardView) -> Array[StaticBody3D]:
	var bodies: Array[StaticBody3D] = []
	for child in board.get_node("Cells").get_children():
		if child is StaticBody3D:
			bodies.append(child)
	return bodies


func test_one_tagged_collider_per_floor_or_obstacle_cell() -> void:
	var board := _board()
	var cells: Array[Vector2i] = []
	for body in _cell_bodies(board):
		cells.append(board.cell_from_collider(body))
		assert_eq(body.collision_layer, BoardView.BOARD_LAYER, "%s on the board layer" % body.name)
	cells.sort()
	assert_eq(cells, [Vector2i(0, 0), Vector2i(0, 1), Vector2i(1, 0), Vector2i(2, 0), Vector2i(2, 1)] as Array[Vector2i],
			"every cell but the hole")
	board.free()


func test_cells_stand_at_their_height() -> void:
	var board := _board()
	var level := board.board_theme.level_height
	assert_eq(board.cell_to_world(Vector2i(0, 0)), Vector3(0, 0, 0))
	assert_eq(board.cell_to_world(Vector2i(1, 0)), Vector3(1, level, 0))
	assert_eq(board.cell_to_world(Vector2i(0, 1)), Vector3(0, 2 * level, 1))
	assert_eq(board.center(), Vector3(1.0, 0.0, 0.5))
	board.free()


func test_colliders_cover_the_column_and_the_obstacle_block() -> void:
	var board := _board()
	for body in _cell_bodies(board):
		var cell := board.cell_from_collider(body)
		var shape := (body.get_node("Collision") as CollisionShape3D)
		var top := shape.position.y + (shape.shape as BoxShape3D).size.y / 2.0
		var expected := board.cell_to_world(cell).y
		if cell == Vector2i(2, 0):
			expected += BoardView.OBSTACLE_SIZE.y
		assert_true(is_equal_approx(top, expected), "%s collider top %f, expected %f" % [cell, top, expected])
	board.free()


func test_non_cell_colliders_pick_nothing() -> void:
	var board := _board()
	var stray := StaticBody3D.new()
	assert_eq(board.cell_from_collider(stray), BoardView.NO_CELL)
	assert_eq(board.cell_from_collider(null), BoardView.NO_CELL)
	stray.free()
	board.free()


func test_highlights_replace_and_clear_per_kind() -> void:
	var board := _board()
	board.show_highlight(BoardView.Highlight.REACH, [Vector2i(0, 0), Vector2i(1, 0)] as Array[Vector2i])
	board.show_highlight(BoardView.Highlight.AREA, [Vector2i(2, 1)] as Array[Vector2i])
	assert_eq(board.highlighted_count(BoardView.Highlight.REACH), 2)
	board.show_highlight(BoardView.Highlight.REACH, [Vector2i(0, 1)] as Array[Vector2i])
	assert_eq(board.highlighted_count(BoardView.Highlight.REACH), 1, "replaced, not added")
	assert_eq(board.highlighted_count(BoardView.Highlight.AREA), 1, "other kinds untouched")
	board.clear_highlight(BoardView.Highlight.REACH)
	assert_eq(board.highlighted_count(BoardView.Highlight.REACH), 0)
	board.clear_highlights()
	assert_eq(board.highlighted_count(BoardView.Highlight.AREA), 0)
	board.free()


func test_rebuilding_replaces_the_old_board() -> void:
	var board := _board()
	board.show_highlight(BoardView.Highlight.PATH, [Vector2i(0, 0)] as Array[Vector2i])
	var map := MapData.new()
	map.layout = "0p 0e"
	board.build(map.parse().grid)
	assert_eq(_cell_bodies(board).size(), 2)
	assert_eq(board.highlighted_count(BoardView.Highlight.PATH), 0)
	board.free()


# --- Camera ---

func _rig() -> CameraRig:
	var rig := (load("res://scenes/battle/camera_rig.tscn") as PackedScene).instantiate() as CameraRig
	(Engine.get_main_loop() as SceneTree).root.add_child(rig)  # Runs _ready.
	return rig


func test_camera_turns_in_quarter_steps_without_wrapping() -> void:
	var rig := _rig()
	assert_true(is_equal_approx(rig.rotation.y, deg_to_rad(45.0)), "starts on the diamond view")
	rig.rotate_steps(1)
	assert_true(is_equal_approx(rig.target_yaw(), deg_to_rad(135.0)))
	rig.rotate_steps(-1)
	rig.rotate_steps(-1)
	assert_true(is_equal_approx(rig.target_yaw(), deg_to_rad(-45.0)), "not wrapped to 315°")
	rig.free()


func test_camera_zoom_is_clamped() -> void:
	var rig := _rig()
	assert_eq(rig.camera.projection, Camera3D.PROJECTION_ORTHOGONAL)
	assert_eq(rig.camera.size, rig.default_size)
	rig.zoom_by(-100.0)
	assert_eq(rig.target_size, rig.min_size)
	rig.zoom_by(100.0)
	assert_eq(rig.target_size, rig.max_size)
	rig.free()


func _assert_aims_at_pivot(rig: CameraRig, pitch_degrees: float) -> void:
	var forward := -rig.camera.transform.basis.z
	assert_true(forward.is_equal_approx(-rig.camera.position.normalized()), "aims at the pivot")
	assert_true(is_equal_approx(rad_to_deg(asin(-forward.y)), pitch_degrees),
			"pitched %f, expected %f" % [rad_to_deg(asin(-forward.y)), pitch_degrees])


func test_camera_looks_down_at_the_rig_at_its_pitch() -> void:
	var rig := _rig()
	_assert_aims_at_pivot(rig, rig.pitch_degrees)
	rig.free()


func test_camera_toggles_the_overhead_view() -> void:
	var rig := _rig()
	Engine.time_scale = 20.0
	rig.set_overhead(true)
	assert_eq(rig.target_pitch(), rig.overhead_pitch_degrees)
	while not is_equal_approx(rad_to_deg(asin(-(-rig.camera.transform.basis.z).y)), rig.overhead_pitch_degrees):
		await (Engine.get_main_loop() as SceneTree).process_frame
	_assert_aims_at_pivot(rig, rig.overhead_pitch_degrees)
	assert_true(is_equal_approx(rig.camera.size, rig.default_size * rig.overhead_zoom_factor), "zoomed out overhead")
	rig.set_overhead(false, false)
	_assert_aims_at_pivot(rig, rig.pitch_degrees)
	assert_eq(rig.camera.size, rig.default_size)
	rig.free()
