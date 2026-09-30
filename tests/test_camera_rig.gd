extends TestCase
## The camera rig: smooth focus, pan limits, panning by the screen (keys and drag).

const RIG_SCENE := preload("res://scenes/battle/camera_rig.tscn")


func _rig() -> CameraRig:
	var rig := RIG_SCENE.instantiate() as CameraRig
	(Engine.get_main_loop() as SceneTree).root.add_child(rig)
	rig.set_bounds(Rect2(Vector2.ZERO, Vector2(6, 4)))  # Cells 0..6 by 0..4.
	return rig


func _right(rig: CameraRig) -> Vector3:
	return Vector3(rig.camera.global_basis.x.x, 0.0, rig.camera.global_basis.x.z).normalized()


func test_the_focus_point_stays_within_the_board_and_a_margin() -> void:
	var rig := _rig()
	rig.focus(Vector3(100, 0, -100))
	assert_eq(rig.position, Vector3(7, 0, -1), "one cell of margin past the board")
	rig.focus(Vector3(3, 0, 2))
	assert_eq(rig.position, Vector3(3, 0, 2), "inside: untouched")
	rig.free()


func test_no_bounds_no_limit() -> void:
	var rig := _rig()
	rig.bounds = Rect2()
	rig.focus(Vector3(100, 0, 100))
	assert_eq(rig.position, Vector3(100, 0, 100))
	rig.free()


func test_focus_on_slides_and_arrives_clamped() -> void:
	Engine.time_scale = 20.0
	var rig := _rig()
	rig.focus_on(Vector3(40, 0, 2))
	assert_ne(rig.position, Vector3(7, 0, 2), "not there at once")
	for i in 600:
		if rig.position.is_equal_approx(Vector3(7, 0, 2)):
			break
		await (Engine.get_main_loop() as SceneTree).process_frame
	assert_eq(rig.position, Vector3(7, 0, 2), "arrives, clamped to the margin")
	rig.free()


func test_focus_on_without_animation_is_immediate() -> void:
	var rig := _rig()
	rig.focus_on(Vector3(2, 0, 3), false)
	assert_eq(rig.position, Vector3(2, 0, 3))
	rig.free()


func test_a_view_pan_moves_along_the_screen_and_the_ground_is_longer_upwards() -> void:
	var rig := _rig()
	rig.bounds = Rect2()
	rig.focus(Vector3(3, 0, 2))
	rig.pan_by_view(Vector2(1, 0))
	var moved := rig.position - Vector3(3, 0, 2)
	assert_true(is_equal_approx(moved.length(), 1.0) and moved.normalized().is_equal_approx(_right(rig)), "right is one unit to the screen's right")
	rig.focus(Vector3(3, 0, 2))
	rig.pan_by_view(Vector2(0, 1))
	var up := (rig.position - Vector3(3, 0, 2)).length()
	assert_true(up > 1.0 and is_equal_approx(up, 1.0 / sin(deg_to_rad(rig.pitch_degrees))), "up covers more ground: 1 / sin(pitch)")
	rig.free()


func test_a_drag_grabs_the_board_and_a_short_press_stays_a_click() -> void:
	var rig := _rig()
	rig.bounds = Rect2()
	rig.focus(Vector3(3, 0, 2))
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = Vector2(300, 300)
	rig._unhandled_input(press)
	assert_false(rig.dragged)
	var small := InputEventMouseMotion.new()
	small.position = Vector2(305, 300)
	small.relative = Vector2(5, 0)
	small.button_mask = MOUSE_BUTTON_MASK_LEFT
	rig._unhandled_input(small)
	assert_false(rig.dragged, "under the threshold: still a click")
	assert_eq(rig.position, Vector3(3, 0, 2), "and nothing moved")
	var big := InputEventMouseMotion.new()
	big.position = Vector2(340, 300)
	big.relative = Vector2(40, 0)
	big.button_mask = MOUSE_BUTTON_MASK_LEFT
	rig._unhandled_input(big)
	assert_true(rig.dragged)
	assert_true((rig.position - Vector3(3, 0, 2)).dot(_right(rig)) < 0.0, "dragging right moves the camera left: the board follows the cursor")
	var next := InputEventMouseButton.new()
	next.button_index = MOUSE_BUTTON_LEFT
	next.pressed = true
	next.position = Vector2(10, 10)
	rig._unhandled_input(next)
	assert_false(rig.dragged, "a new press starts clean")
	rig.free()


func test_a_middle_drag_pans_at_once() -> void:
	var rig := _rig()
	rig.bounds = Rect2()
	rig.focus(Vector3(3, 0, 2))
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_MIDDLE
	press.pressed = true
	rig._unhandled_input(press)
	var motion := InputEventMouseMotion.new()
	motion.relative = Vector2(0, 3)
	motion.button_mask = MOUSE_BUTTON_MASK_MIDDLE
	rig._unhandled_input(motion)
	assert_ne(rig.position, Vector3(3, 0, 2))
	rig.free()


func test_a_stale_drag_cant_pan_without_a_button_held() -> void:
	var rig := _rig()
	rig.bounds = Rect2()
	rig.focus(Vector3(3, 0, 2))
	rig.dragged = true
	var motion := InputEventMouseMotion.new()
	motion.relative = Vector2(50, 50)
	rig._unhandled_input(motion)  # No button in the mask: the release was eaten elsewhere.
	assert_eq(rig.position, Vector3(3, 0, 2))
	rig.free()


func test_a_press_the_rig_never_saw_cant_start_a_drag() -> void:
	var rig := _rig()
	rig.bounds = Rect2()
	rig.focus(Vector3(3, 0, 2))
	var motion := InputEventMouseMotion.new()  # A left button held from a HUD press: no press reached the rig.
	motion.position = Vector2(900, 500)
	motion.relative = Vector2(20, 0)
	motion.button_mask = MOUSE_BUTTON_MASK_LEFT
	rig._unhandled_input(motion)
	assert_false(rig.dragged)
	assert_eq(rig.position, Vector3(3, 0, 2))
	rig.free()


func test_a_seen_press_forgets_itself_once_the_button_is_known_up() -> void:
	var rig := _rig()
	rig.bounds = Rect2()
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = Vector2(100, 100)
	rig._unhandled_input(press)  # Its release is eaten by another node.
	var free_motion := InputEventMouseMotion.new()  # The mouse moves on, nothing held.
	free_motion.position = Vector2(400, 400)
	rig._unhandled_input(free_motion)
	var held := InputEventMouseMotion.new()  # A later press the HUD ate, held over the board.
	held.position = Vector2(700, 400)
	held.relative = Vector2(30, 0)
	held.button_mask = MOUSE_BUTTON_MASK_LEFT
	rig._unhandled_input(held)
	assert_false(rig.dragged, "the old press can't start this drag")
	rig.free()


func test_arrow_keys_pan_only_while_enabled() -> void:
	var rig := _rig()
	rig.bounds = Rect2()
	rig.focus(Vector3(3, 0, 2))
	Input.action_press(&"camera_pan_right")
	rig._process(0.1)
	var moved := rig.position
	assert_ne(moved, Vector3(3, 0, 2), "panned")
	rig.pan_enabled = false
	rig._process(0.1)
	Input.action_release(&"camera_pan_right")
	assert_eq(rig.position, moved, "a panel is open: the arrows belong to the menus")
	rig.free()
