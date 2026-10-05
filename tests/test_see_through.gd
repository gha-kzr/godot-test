extends TestCase
## The see-through fade: an obstacle that really hides a unit from the camera fades and comes back;
## one that merely stands near it, or that hides only the mouse's cell, does not.

const CELL := Vector2i(1, 0)


func _fade_with_one_box() -> Array:
	var fade := ObstacleFade.new()
	var mesh := MeshInstance3D.new()
	mesh.mesh = BoxMesh.new()
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.5, 0.5, 0.5)
	mesh.material_override = material
	fade.register(CELL, [mesh] as Array[MeshInstance3D])
	return [fade, mesh, material]


func test_an_obstacle_in_the_way_fades_with_a_dithered_copy_and_comes_back() -> void:
	var made := _fade_with_one_box()
	var fade: ObstacleFade = made[0]
	var mesh: MeshInstance3D = made[1]
	var original: StandardMaterial3D = made[2]
	fade.fade_only([CELL] as Array[Vector2i])
	assert_eq(fade.goal_of(CELL), ObstacleFade.FADED_ALPHA)
	for i in 30:
		fade.advance(0.1)
	assert_eq(fade.alpha_of(CELL), ObstacleFade.FADED_ALPHA)
	var faded := mesh.material_override as StandardMaterial3D
	assert_true(faded != original, "a copy: the shared material is untouched")
	assert_eq(faded.transparency, ObstacleFade.transparency_mode())
	assert_true(is_equal_approx(faded.albedo_color.a, ObstacleFade.FADED_ALPHA))
	assert_eq(original.albedo_color.a, 1.0)
	fade.fade_only([] as Array[Vector2i])
	for i in 30:
		fade.advance(0.1)
	assert_eq(fade.alpha_of(CELL), 1.0)
	assert_true(mesh.material_override == original, "the original is back")
	mesh.free()
	fade.free()


func test_the_fade_is_gradual() -> void:
	var made := _fade_with_one_box()
	var fade: ObstacleFade = made[0]
	fade.fade_only([CELL] as Array[Vector2i])
	fade.advance(0.05)
	assert_true(fade.alpha_of(CELL) < 1.0 and fade.alpha_of(CELL) > ObstacleFade.FADED_ALPHA, "on its way")
	(made[1] as MeshInstance3D).free()
	fade.free()


func _board(layout: String) -> BoardView:
	var map := MapData.new()
	map.layout = layout
	var board := BoardView.new()
	(Engine.get_main_loop() as SceneTree).root.add_child(board)
	board.build(map.parse().grid)
	return board


func _settle() -> void:
	await (Engine.get_main_loop() as SceneTree).physics_frame
	await (Engine.get_main_loop() as SceneTree).physics_frame


func test_a_board_fades_a_rock_that_really_hides_a_unit() -> void:
	var board := _board("0p # 0e")  # A rock at (1, 0) between the cells (0, 0) and (2, 0).
	await _settle()
	var fade := board.obstacle_fade()
	assert_eq(fade.count(), 1)
	var behind := board.cell_to_world(Vector2i(2, 0)) + Vector3.UP * 0.15
	var eye := board.cell_to_world(Vector2i(0, 0)) + Vector3(-2.0, 1.5, 0.0)
	board.look_through(eye, [behind] as Array[Vector3])
	assert_eq(fade.goal_of(CELL), ObstacleFade.FADED_ALPHA, "the rock is on the way to the unit")
	board.look_through(board.cell_to_world(Vector2i(2, 0)) + Vector3(2.0, 1.5, 0.0), [behind] as Array[Vector3])
	assert_eq(fade.goal_of(CELL), 1.0, "seen from the other side, the rock is behind the unit")
	board.free()


func test_a_rock_beside_the_line_of_sight_stays_solid() -> void:
	var board := _board("0p # 0e\n0 0 0")
	await _settle()
	var fade := board.obstacle_fade()
	var unit_spot := board.cell_to_world(Vector2i(2, 1)) + Vector3.UP * 0.15
	var eye := board.cell_to_world(Vector2i(0, 1)) + Vector3(-2.0, 1.5, 0.0)  # Along the clear second row.
	board.look_through(eye, [unit_spot] as Array[Vector3])
	assert_eq(fade.goal_of(CELL), 1.0, "the rock stands next to the line, not on it")
	board.free()
