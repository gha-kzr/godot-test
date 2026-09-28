class_name UnitView
extends Node3D
## One unit on the board: a placeholder capsule (or UnitData.model_scene), a team ring,
## an HP label and a pick collider that clicks through to the unit's cell (see BoardView).
## Every play_* method returns once its animation is over, so callers can await them one
## after another.

const PLAYER_RING_COLOR := Color(0.3, 0.6, 1.0)
const ENEMY_RING_COLOR := Color(1.0, 0.3, 0.25)
const DAMAGE_COLOR := Color(1.0, 0.35, 0.3)
const HEAL_COLOR := Color(0.4, 1.0, 0.45)
const STEP_DURATION := 0.18
const CAST_DURATION := 0.3
const HIT_DURATION := 0.3
const DEATH_DURATION := 0.45
const FLOAT_DURATION := 0.8
## How far toward its target a caster lunges.
const LUNGE_DISTANCE := 0.3
## The active unit's ring pulses between these scales.
const ACTIVE_PULSE_SCALE := 1.25
const ACTIVE_PULSE_DURATION := 0.5

var unit_id := -1
var _board: BoardView
var _max_hp := 1
var _material: StandardMaterial3D  ## Placeholder only; models keep their own look.
var _pulse_tween: Tween

@onready var _body: Node3D = $Body
@onready var _placeholder: MeshInstance3D = $Body/Placeholder
@onready var _ring: MeshInstance3D = $Ring
@onready var _pick_body: StaticBody3D = $PickBody
@onready var _hp_label: Label3D = $HpLabel


## One-time setup (model, colors), then sync() to the unit's current state.
## Call after the view is in the tree (it uses @onready nodes).
func setup(unit: UnitState, board: BoardView) -> void:
	if not is_node_ready():
		push_error("UnitView.setup: add the view to the tree first")
		return
	unit_id = unit.id
	_board = board
	_max_hp = unit.data.max_hp
	name = "Unit%d" % unit.id
	if unit.data.model_scene != null:
		_placeholder.queue_free()
		_placeholder = null
		_body.add_child(unit.data.model_scene.instantiate())
	else:
		_material = StandardMaterial3D.new()
		_material.albedo_color = unit.data.color
		_placeholder.material_override = _material
	var ring_material := StandardMaterial3D.new()
	ring_material.albedo_color = PLAYER_RING_COLOR if unit.team == UnitState.Team.PLAYER else ENEMY_RING_COLOR
	ring_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_ring.material_override = ring_material
	sync(unit)


## Snaps the view to the unit's state: cell, HP, alive or not. Called after every
## playback, so the views can never drift from the rules (and undo can reuse it).
func sync(unit: UnitState) -> void:
	position = _board.cell_to_world(unit.cell)
	_pick_body.set_meta(BoardView.CELL_META, unit.cell)
	_set_hp(unit.hp)
	var alive := unit.is_alive()
	visible = alive
	_hp_label.visible = alive
	_pick_body.collision_layer = BoardView.UNITS_LAYER if alive else 0
	if alive:  # Undo a death squash (e.g. after undo or a desync).
		_body.scale = Vector3.ONE
		_ring.scale = Vector3.ONE


## Walks the path cell by cell. Climbs go up then across, drops go across then down.
func play_move(path: Array[Vector2i]) -> void:
	for cell in path:
		var target := _board.cell_to_world(cell)
		_face(target)
		var tween := create_tween()
		if target.y > position.y:
			tween.tween_property(self, "position:y", target.y, STEP_DURATION * 0.5)
		tween.tween_property(self, "position", Vector3(target.x, maxf(target.y, position.y), target.z), STEP_DURATION)
		if target.y < position.y:
			tween.tween_property(self, "position:y", target.y, STEP_DURATION * 0.5)
		await tween.finished
		position = target
		_pick_body.set_meta(BoardView.CELL_META, cell)


## A short lunge toward the target cell (a hop when casting on its own cell).
func play_cast(target_cell: Vector2i) -> void:
	var target := _board.cell_to_world(target_cell)
	var offset := Vector3(target.x - position.x, 0.0, target.z - position.z)
	var start := position
	var tween := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	if offset.is_zero_approx():
		tween.tween_property(self, "position:y", start.y + LUNGE_DISTANCE, CAST_DURATION * 0.5)
	else:
		_face(target)
		tween.tween_property(self, "position", start + offset.normalized() * LUNGE_DISTANCE, CAST_DURATION * 0.5)
	tween.tween_property(self, "position", start, CAST_DURATION * 0.5)
	await tween.finished


func play_hit(amount: int, hp_after: int) -> void:
	await _play_hp_change("-%d" % amount, DAMAGE_COLOR, hp_after)


func play_heal(amount: int, hp_after: int) -> void:
	await _play_hp_change("+%d" % amount, HEAL_COLOR, hp_after)


func play_death() -> void:
	set_active(false)
	_hp_label.hide()
	_pick_body.collision_layer = 0  # Hidden nodes still collide; dead units can't be clicked.
	var tween := create_tween().set_parallel().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tween.tween_property(_body, "scale", Vector3(1.2, 0.05, 1.2), DEATH_DURATION)
	tween.tween_property(_ring, "scale", Vector3.ZERO, DEATH_DURATION)
	await tween.finished
	hide()


## Pulses the team ring while it's this unit's turn.
func set_active(active: bool) -> void:
	if _pulse_tween != null:
		_pulse_tween.kill()
		_pulse_tween = null
	_ring.scale = Vector3.ONE
	if active and visible:
		_pulse_tween = create_tween().set_loops().set_trans(Tween.TRANS_SINE)
		_pulse_tween.tween_property(_ring, "scale", Vector3.ONE * ACTIVE_PULSE_SCALE, ACTIVE_PULSE_DURATION)
		_pulse_tween.tween_property(_ring, "scale", Vector3.ONE, ACTIVE_PULSE_DURATION)


func is_active() -> bool:
	return _pulse_tween != null


func hp_text() -> String:
	return _hp_label.text


## The cell a click on this unit picks, or NO_CELL once it can't be clicked.
func picked_cell() -> Vector2i:
	if _pick_body.collision_layer == 0:
		return BoardView.NO_CELL
	return _pick_body.get_meta(BoardView.CELL_META)


## Shows the change as a floating number (not awaited, it drifts on its own) and a flash
## of the placeholder in the number's color.
func _play_hp_change(text: String, color: Color, hp_after: int) -> void:
	_set_hp(hp_after)
	_spawn_floating_number(text, color)
	var tween := create_tween()
	if _material != null:
		var base := _material.albedo_color
		tween.tween_property(_material, "albedo_color", color, HIT_DURATION * 0.3)
		tween.tween_property(_material, "albedo_color", base, HIT_DURATION * 0.7)
	else:
		tween.tween_interval(HIT_DURATION)
	await tween.finished


func _spawn_floating_number(text: String, color: Color) -> void:
	var label := _hp_label.duplicate() as Label3D
	label.name = "FloatingNumber"
	label.text = text
	label.modulate = color
	label.show()
	add_child(label)
	var tween := label.create_tween().set_parallel()
	tween.tween_property(label, "position:y", label.position.y + 0.8, FLOAT_DURATION)
	tween.tween_property(label, "modulate:a", 0.0, FLOAT_DURATION).set_delay(FLOAT_DURATION * 0.4)
	tween.chain().tween_callback(label.queue_free)


func _set_hp(hp: int) -> void:
	_hp_label.text = "%d/%d" % [hp, _max_hp]


func _face(target: Vector3) -> void:
	var direction := Vector2(target.x - position.x, target.z - position.z)
	if not direction.is_zero_approx():
		_body.rotation.y = atan2(direction.x, direction.y)
