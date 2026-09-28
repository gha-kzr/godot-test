class_name CameraRig
extends Node3D
## Orbit camera for the board. The rig sits on the board center and turns in 90° steps
## (tweened); the orthographic camera looks down at it and zooms by size. A toggle switches
## to a near-overhead view where terrain hides almost nothing.

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

## Quarter turns from the base yaw. Not wrapped, so a tween never spins the long way.
var step := 0
var target_size := 0.0
var overhead := false

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


func _unhandled_input(event: InputEvent) -> void:
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


func focus(point: Vector3) -> void:
	position = point


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
