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
	var level := board.active_theme().level_height
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
			expected += board.grid.obstacle_levels(cell) * board.active_theme().level_height
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


# --- Editor preview ---

func test_the_preview_map_is_not_built_at_runtime() -> void:
	var board := BoardView.new()
	board.preview_map = load("res://data/maps/slice.tres")
	(Engine.get_main_loop() as SceneTree).root.add_child(board)
	assert_eq(board.grid, null, "at runtime the battle builds the board, not the preview")
	board.show_preview()
	assert_eq(board.grid.size, Vector2i(10, 10), "show_preview draws it (what the editor does)")
	board.free()


func test_map_edits_emit_changed() -> void:
	var map := MapData.new()
	var seen := {"count": 0}
	map.changed.connect(func() -> void: seen.count += 1)
	map.layout = "0p 0e"
	assert_eq(seen.count, 1)


func test_preview_cells_are_never_saved_into_the_scene() -> void:
	var root := Node3D.new()
	var board := BoardView.new()
	root.add_child(board)
	board.owner = root
	board.preview_map = load("res://data/maps/slice.tres")
	board.show_preview()
	assert_true(board.get_node("Cells").get_child_count() > 0)
	var packed := PackedScene.new()
	packed.pack(root)
	var copy := packed.instantiate()
	assert_eq((copy.get_child(0) as BoardView).get_node("Cells").get_child_count(), 0, "no generated cells in the file")
	assert_eq((copy.get_child(0) as BoardView).board_theme, null, "no default theme written into the scene")
	copy.free()
	root.free()


func test_the_drawn_obstacle_is_the_rules_cube() -> void:
	var board := _board()
	var cell := Vector2i(2, 0)
	var block := board.find_child("Obstacle", true, false) as MeshInstance3D
	var size := (block.mesh as BoxMesh).size
	var theme := board.active_theme()
	assert_true(is_equal_approx(size.y, board.grid.obstacle_levels(cell) * theme.level_height), "as tall as the rules say")
	assert_true(is_equal_approx(size.x, BoardView.CELL_SIZE * theme.block_fill), "a full cell wide, like the terrain blocks")
	assert_true(is_equal_approx(size.y, 1.0), "two half-cell levels: a cube of one cell")
	board.free()


# --- Look: toon terrain and fitted obstacle models ---

const STONE := preload("res://data/board/stone.tres")


func _themed_board(theme: BoardTheme, layout := "0p # # #\n0 # 0 0e") -> BoardView:
	var map := MapData.new()
	map.layout = layout
	var board := BoardView.new()
	board.board_theme = theme
	board.build(map.parse().grid)
	return board


func _column_material(board: BoardView) -> StandardMaterial3D:
	var column := board.find_child("Column", true, false) as MeshInstance3D
	return column.material_override as StandardMaterial3D


func test_the_terrain_is_toon_shaded_with_a_speckle_by_default() -> void:
	var board := _board()
	var material := _column_material(board)
	assert_eq(material.diffuse_mode, BaseMaterial3D.DIFFUSE_TOON)
	assert_eq(material.specular_mode, BaseMaterial3D.SPECULAR_DISABLED)
	assert_true(material.albedo_texture != null, "a subtle texture")
	assert_eq(material.texture_filter, BaseMaterial3D.TEXTURE_FILTER_NEAREST)
	board.free()


func test_the_look_can_be_switched_off_in_the_theme() -> void:
	var flat := BoardTheme.new()
	flat.toon = false
	flat.noise_strength = 0.0
	var board := _themed_board(flat)
	var material := _column_material(board)
	assert_eq(material.diffuse_mode, BaseMaterial3D.DIFFUSE_BURLEY, "the default shading")
	assert_true(material.albedo_texture == null, "no speckle")
	board.free()


func test_highlights_stay_flat_and_untextured() -> void:
	var board := _board()
	board.show_highlight(BoardView.Highlight.REACH, [Vector2i(0, 0)] as Array[Vector2i])
	var overlay := board.get_node("Highlights/Reach").get_child(0) as MeshInstance3D
	var material := overlay.material_override as StandardMaterial3D
	assert_eq(material.shading_mode, BaseMaterial3D.SHADING_MODE_UNSHADED)
	assert_true(material.albedo_texture == null)
	board.free()


func test_obstacle_models_fill_the_cube_exactly_and_stand_on_the_cell() -> void:
	var board := _themed_board(STONE)
	var theme := board.active_theme()
	var expected_height := board.grid.obstacle_levels(Vector2i(1, 0)) * theme.level_height
	var expected_width := BoardView.CELL_SIZE * theme.block_fill
	var checked := 0
	for obstacle in board.find_children("Obstacle", "Node3D", true, false):
		var wrapper := obstacle as Node3D
		var bounds := BoardView.model_bounds(wrapper.get_child(0) as Node3D)
		var size := bounds.size * wrapper.scale
		assert_true(is_equal_approx(size.x, expected_width) and is_equal_approx(size.z, expected_width), "a cell wide and deep: %s" % size)
		assert_true(is_equal_approx(size.y, expected_height), "as tall as the cube the rules block with: %f" % size.y)
		var bottom := wrapper.position.y + bounds.position.y * wrapper.scale.y  # The bounds already include the model's offset.
		var cell_top := board.cell_to_world(board.cell_from_collider(wrapper.get_parent())).y
		assert_true(is_equal_approx(bottom, cell_top), "standing on the cell's top")
		checked += 1
	assert_eq(checked, 4, "every obstacle cell got a model")
	board.free()


func test_obstacle_variants_are_picked_by_cell_and_the_theme_has_more_than_one() -> void:
	assert_true(STONE.obstacle_scenes.size() >= 3, "a few rocks for variety")
	var board := _themed_board(STONE)
	var used: Dictionary[String, bool] = {}
	for obstacle in board.find_children("Obstacle", "Node3D", true, false):
		used[(obstacle.get_child(0) as Node3D).scene_file_path] = true
	assert_true(used.size() >= 2, "different cells show different rocks: %s" % [used.keys()])
	board.free()


func test_the_battle_scene_uses_the_stone_theme_and_a_theme_without_models_keeps_the_cubes() -> void:
	var battle := load("res://scenes/battle/battle.tscn") as PackedScene
	var node := battle.instantiate()
	assert_eq((node.get_node("BoardView") as BoardView).board_theme, STONE)
	node.free()
	var board := _board()  # The default theme has no obstacle models.
	var block := board.find_child("Obstacle", true, false) as MeshInstance3D
	assert_true(block != null and block.mesh is BoxMesh, "a plain cube")
	board.free()


func test_a_model_whose_root_is_off_the_origin_still_stands_centered_on_the_cell() -> void:
	var root := Node3D.new()
	root.position = Vector3(2.0, 3.0, 1.0)  # A pack with an offset root.
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.5, 0.2, 0.4)
	mesh.mesh = box
	root.add_child(mesh)
	mesh.owner = root
	var scene := PackedScene.new()
	scene.pack(root)
	root.free()
	var board := _board()
	var fitted := board._fitted_model(scene, 1.5, 0.96, 1.0)
	var bounds := BoardView.model_bounds(fitted.get_child(0) as Node3D)
	assert_true(is_equal_approx(fitted.position.y + bounds.position.y * fitted.scale.y, 1.5), "its bottom on the cell's top")
	assert_true(is_equal_approx(bounds.get_center().x * fitted.scale.x, 0.0) and is_equal_approx(bounds.get_center().z * fitted.scale.z, 0.0), "centered")
	assert_true(is_equal_approx(bounds.size.y * fitted.scale.y, 1.0), "as tall as asked")
	fitted.free()
	board.free()


func test_the_speckle_texture_is_shared_between_terrain_colors() -> void:
	var board := _board()
	var a := board._material(Color(0.2, 0.4, 0.2), false)
	var b := board._material(Color(0.5, 0.3, 0.2), false)
	assert_true(a.albedo_texture == b.albedo_texture and a.albedo_texture != null, "one texture, not one per color")
	board.free()
