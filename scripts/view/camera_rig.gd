class_name CameraRig
extends Node3D
## Orbit camera for the board. The rig sits on the focus point (the board center at first) and
## turns in 90° steps (tweened); the orthographic camera looks down at it and zooms by size. A
## toggle switches to a near-overhead view where terrain hides almost nothing.
##
## The focus point moves by focus_on() (a smooth slide), by the arrow keys (held) and by
## dragging: a left-button press that moves more than `drag_threshold` pixels grabs the board
## (a middle-button press grabs at once). A shorter press is a click, which the controller acts
## on at release unless `dragged` is set. The focus point stays inside the bounds (the board
## plus a margin), and pans follow the screen, so they stay right after rotating.

signal overhead_changed(enabled: bool)

## Above ~35.3°, a one-level step in front of a cell no longer hides its center
## (at level height 0.5, looking along a diagonal).
@export_range(10.0, 89.0) var pitch_degrees := 40.0
## Not quite 90°, so heights still read.
@export_range(10.0, 89.0) var overhead_pitch_degrees := 75.0
## Seen from above the board looks taller on screen, so the overhead view zooms out this much.
@export_range(1.0, 2.0) var overhead_zoom_factor := 1.35
## Yaw at step 0. 45° shows the board as a diamond, Disgaea-style.
@export var base_yaw_degrees := 45.0
@export var distance := 30.0
@export var default_size := 12.0
@export var min_size := 6.0
@export var max_size := 24.0
@export var zoom_step := 1.5
@export var tween_duration := 0.25
## Shifts the view up (in world units at the screen) so the board clears the turn-order
## bar at the top; the HUD at the bottom is lower.
@export var vertical_offset := 0.3
## Arrow-key panning speed, in view heights per second.
@export var pan_speed := 0.9
## Pixels a left press may move and still be a click.
@export var drag_threshold := 10.0
## How far past the board the focus point may go, in cells.
@export var bounds_margin := 1.0

## Quarter turns from the base yaw. Not wrapped, so a tween never spins the long way.
var step := 0
var target_size := 0.0
var overhead := false
## Whether the press in progress (or the last one) turned into a drag: the controller skips
## the click at release then.
var dragged := false
## False while a full-screen panel is open: the arrow keys belong to the menus then.
var pan_enabled := true
## The area (x, z in world units) the focus point stays in; an empty rect means no limit.
var bounds := Rect2()

var _move_tween: Tween
var _press_position := Vector2.ZERO
## A left press the rig saw is still held (a press the HUD ate never starts a drag).
var _left_down := false
var _rotate_tween: Tween
var _zoom_tween: Tween
var _pitch_tween: Tween
var _current_pitch := 0.0

@onready var camera: Camera3D = $Camera3D


func _ready() -> void:
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.far = distance * 3.0
	camera.v_offset = vertical_offset
	_apply_pitch(target_pitch())
	target_size = default_size
	camera.size = _view_size()
	rotation.y = target_yaw()


func _process(delta: float) -> void:
	var keys := Input.get_vector(&"camera_pan_left", &"camera_pan_right", &"camera_pan_up", &"camera_pan_down")
	if keys != Vector2.ZERO and pan_enabled:
		pan_by_view(Vector2(keys.x, -keys.y) * pan_speed * camera.size * delta)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var button := event as InputEventMouseButton
		if button.button_index == MOUSE_BUTTON_LEFT:
			_left_down = button.pressed
		if button.pressed and button.button_index == MOUSE_BUTTON_LEFT:
			_press_position = button.position
			dragged = false
		elif button.pressed and button.button_index == MOUSE_BUTTON_MIDDLE:
			dragged = true
		if button.button_index == MOUSE_BUTTON_LEFT or button.button_index == MOUSE_BUTTON_MIDDLE:
			return  # Not handled: the controller acts on the left release.
	elif event is InputEventMouseMotion:
		# The motion's own button mask, not remembered presses: a release another node ate can't stick.
		var motion := event as InputEventMouseMotion
		var left := _left_down and motion.button_mask & MOUSE_BUTTON_MASK_LEFT != 0
		_left_down = _left_down and motion.button_mask & MOUSE_BUTTON_MASK_LEFT != 0  # Known up: forget the press.
		var middle := motion.button_mask & MOUSE_BUTTON_MASK_MIDDLE != 0
		if middle or (left and motion.position.distance_to(_press_position) > drag_threshold):
			dragged = true
		if dragged and (left or middle):
			pan_by_view(Vector2(-motion.relative.x, motion.relative.y) * _units_per_pixel())
			get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed(&"camera_rotate_left"):
		rotate_steps(-1)
	elif event.is_action_pressed(&"camera_rotate_right"):
		rotate_steps(1)
	elif event.is_action_pressed(&"camera_toggle_view"):
		set_overhead(not overhead)
	elif event.is_action_pressed(&"camera_zoom_in"):
		zoom_by(-zoom_step)
	elif event.is_action_pressed(&"camera_zoom_out"):
		zoom_by(zoom_step)
	else:
		return
	get_viewport().set_input_as_handled()


## Puts the focus point on `point` at once (clamped to the bounds).
func focus(point: Vector3) -> void:
	if _move_tween != null:
		_move_tween.kill()
	position = clamp_point(point)


## Slides the focus point to `point` (clamped to the bounds).
func focus_on(point: Vector3, animate := true) -> void:
	if not animate or not is_inside_tree():
		focus(point)
		return
	if _move_tween != null:
		_move_tween.kill()
	_move_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_move_tween.tween_property(self, "position", clamp_point(point), tween_duration)


## Sets the area (x, z world coordinates of the cell centers) the focus point may roam:
## the board plus `bounds_margin` cells.
func set_bounds(cell_centers: Rect2) -> void:
	bounds = cell_centers.grow(bounds_margin)


func clamp_point(point: Vector3) -> Vector3:
	if not bounds.has_area():
		return point
	return Vector3(clampf(point.x, bounds.position.x, bounds.end.x), point.y, clampf(point.z, bounds.position.y, bounds.end.y))


## Moves the focus point by `view` (x right, y up, in world units at the screen plane).
## Ground distance along the view's up axis is longer by 1 / sin(pitch).
func pan_by_view(view: Vector2) -> void:
	if _move_tween != null:
		_move_tween.kill()  # The player takes over from a slide.
	var right := Vector3(camera.global_basis.x.x, 0.0, camera.global_basis.x.z).normalized()
	var forward := Vector3(-camera.global_basis.z.x, 0.0, -camera.global_basis.z.z).normalized()
	var ground := right * view.x + forward * view.y / maxf(sin(deg_to_rad(_current_pitch)), 0.1)
	position = clamp_point(position + ground)


## World units at the screen plane per screen pixel.
func _units_per_pixel() -> float:
	return camera.size / maxf(get_viewport().get_visible_rect().size.y, 1.0)


func target_yaw() -> float:
	return deg_to_rad(base_yaw_degrees + 90.0 * step)


## Turns (without animation) to the quarter step whose camera side best faces
## `direction` (horizontal, from the board center), e.g. toward the player's spawns.
func face_toward(direction: Vector3) -> void:
	var best_step := step
	var best_dot := -INF
	for candidate in range(step, step + 4):
		var yaw := deg_to_rad(base_yaw_degrees + 90.0 * candidate)
		var dot := Vector2(sin(yaw), cos(yaw)).dot(Vector2(direction.x, direction.z))
		if dot > best_dot:
			best_dot = dot
			best_step = candidate
	rotate_steps(best_step - step, false)


func target_pitch() -> float:
	return overhead_pitch_degrees if overhead else pitch_degrees


## Positive steps orbit the camera counter-clockwise seen from above, so the board
## appears to turn clockwise.
func rotate_steps(steps: int, animate := true) -> void:
	step += steps
	if _rotate_tween != null:
		_rotate_tween.kill()
	if not animate:
		rotation.y = target_yaw()
		return
	_rotate_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_rotate_tween.tween_property(self, "rotation:y", target_yaw(), tween_duration)


## Switches between the normal and the near-overhead view.
func set_overhead(enabled: bool, animate := true) -> void:
	overhead = enabled
	overhead_changed.emit(enabled)
	if _pitch_tween != null:
		_pitch_tween.kill()
	if _zoom_tween != null:
		_zoom_tween.kill()
	if not animate:
		_apply_pitch(target_pitch())
		camera.size = _view_size()
		return
	_pitch_tween = create_tween().set_parallel().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_pitch_tween.tween_method(_apply_pitch, _current_pitch, target_pitch(), tween_duration)
	_pitch_tween.tween_property(camera, "size", _view_size(), tween_duration)


## Negative zooms in. Clamped to [min_size, max_size].
func zoom_by(amount: float) -> void:
	target_size = clampf(target_size + amount, min_size, max_size)
	if _zoom_tween != null:
		_zoom_tween.kill()
	_zoom_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_zoom_tween.tween_property(camera, "size", _view_size(), tween_duration)


## Orthographic size for the current zoom and view.
func _view_size() -> float:
	return target_size * (overhead_zoom_factor if overhead else 1.0)


## Places the camera on its orbit at `degrees` below the horizon, aimed at the rig.
func _apply_pitch(degrees: float) -> void:
	_current_pitch = degrees
	var pitch := deg_to_rad(degrees)
	camera.position = Vector3(0.0, sin(pitch), cos(pitch)) * distance
	camera.rotation = Vector3(-pitch, 0.0, 0.0)
