extends TestCase
## Picking where a rock obstacle is drawn, not on the whole cube around it; and the light turning
## with the camera.

const BATTLE_SCENE := preload("res://scenes/battle/battle.tscn")


func _tree() -> SceneTree:
	return Engine.get_main_loop() as SceneTree


func _board(layout: String) -> BoardView:
	var map := MapData.new()
	map.layout = layout
	var board := BoardView.new()
	board.board_theme = load("res://data/board/stone.tres") as BoardTheme
	_tree().root.add_child(board)
	board.build(map.parse().grid)
	return board


func _ray(board: BoardView, from: Vector3, to: Vector3) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(from, to, BoardView.BOARD_LAYER | BoardView.UNITS_LAYER)
	return board.get_world_3d().direct_space_state.intersect_ray(query)


func test_a_ray_past_the_rocks_corner_reaches_the_tile_behind_it_not_the_cube() -> void:
	var board := _board("0p # 0e")
	await _tree().physics_frame
	await _tree().physics_frame
	var rock := board.cell_to_world(Vector2i(1, 0))
	var height := board.grid.obstacle_levels(Vector2i(1, 0)) * board.active_theme().level_height
	var behind := board.cell_to_world(Vector2i(2, 0)) + Vector3(0.0, 0.05, 0.0)
	var corner := rock + Vector3(0.46, height - 0.04, 0.0)  # The top edge of the cube, where the rock has tapered away.
	assert_true(_ray(board, behind, corner).is_empty(), "the cube's corner is empty air: the rock isn't drawn there")
	# Through the middle of the rock, the cell is picked (the rock itself is still solid).
	var middle := _ray(board, behind, rock + Vector3(0.0, height * 0.4, 0.0))
	assert_false(middle.is_empty(), "the rock itself picks its cell")
	assert_eq(board.cell_from_collider(middle.collider), Vector2i(1, 0))
	board.free()


func test_an_obstacle_cell_has_a_floor_box_and_a_hull_that_is_smaller_than_its_cube() -> void:
	var board := _board("0p # 0e")
	var body := board.find_child("Cell_1_0", true, false) as StaticBody3D
	assert_true(body.get_node_or_null("Collision") != null and body.get_node_or_null("ObstacleCollision") != null, "floor and rock colliders")
	var hull := (body.get_node("ObstacleCollision") as CollisionShape3D).shape as ConvexPolygonShape3D
	var points := hull.points
	assert_true(points.size() >= 4, "a real hull")
	var box := AABB(points[0], Vector3.ZERO)
	for point in points:
		box = box.expand(point)
	assert_true(box.size.x <= BoardView.CELL_SIZE + 0.06 and box.size.z <= BoardView.CELL_SIZE + 0.06, "within the cell: %s" % box.size)
	assert_true(box.size.y > 0.5, "as tall as the rock: %s" % box.size)
	board.free()


func test_the_light_turns_with_the_camera_so_shadows_fall_the_same_way_on_screen() -> void:
	var controller := BATTLE_SCENE.instantiate() as SoloBattleController
	_tree().root.add_child(controller)
	var light := controller.camera_rig.find_child("DirectionalLight3D", true, false) as DirectionalLight3D
	assert_true(light != null, "the light hangs under the camera rig")
	var rig := controller.camera_rig
	var before := rig.global_basis.inverse() * light.global_basis
	rig.rotate_steps(1, false)
	var after := rig.global_basis.inverse() * light.global_basis
	assert_true(before.is_equal_approx(after), "the light keeps its direction relative to the camera")
	controller.free()
