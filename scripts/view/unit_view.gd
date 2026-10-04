class_name UnitView
extends Node3D
## One unit on the board: a placeholder capsule (or UnitData.model_scene), a team ring,
## an HP label, a row of status icons (each with its turns left) and a pick collider that
## clicks through to the unit's cell (see BoardView).
## Every play_* method returns once its animation is over, so callers can await them one
## after another.

## One step of a walk was taken (for footsteps).
signal stepped

const PLAYER_RING_COLOR := Color(0.3, 0.6, 1.0)
const ENEMY_RING_COLOR := Color(1.0, 0.3, 0.25)
const DAMAGE_COLOR := Color(1.0, 0.35, 0.3)
const HEAL_COLOR := Color(0.4, 1.0, 0.45)
const STEP_DURATION := 0.18
## Moved by a spell: each half of a blink, a whole leap, and how high a leap rises.
const BLINK_DURATION := 0.14
const LEAP_DURATION := 0.4
const LEAP_HEIGHT := 1.2
const CAST_DURATION := 0.3
const HIT_DURATION := 0.3
const DEATH_DURATION := 0.45
const FLOAT_DURATION := 0.8
## How much higher each extra floating text of one action starts (instant speed).
const FLOAT_STACK_STEP := 0.3
## How far toward its target a caster lunges.
const LUNGE_DISTANCE := 0.3
## How far above a cell's top a projectile aims (about a unit's chest).
const PROJECTILE_HEIGHT := 0.8
## The active unit's ring pulses between these scales.
const ACTIVE_PULSE_SCALE := 1.25
const ACTIVE_PULSE_DURATION := 0.5
## Status icons: world size and spacing, and the beats of their animations.
const STATUS_ICON_SIZE := 0.46
const STATUS_TAG_SPACING := 0.62
const STATUS_TAG_PIXEL_SIZE := 0.009
## The placeholder capsule's height, and how far above a unit's head its HP label, status
## icons and damage preview float (they follow the model's height and the elite / boss scale).
const PLACEHOLDER_HEIGHT := 0.9
const HP_LABEL_ABOVE := 0.35
const STATUS_ROW_ABOVE := 1.0
const PREVIEW_ABOVE := 1.6
## A dying model gets this long to fall before it shrinks away (seconds). Other actions don't
## hold the event queue at all: an animation plays out on its own (the model returns to Idle
## when it ends, or the next action replaces it), so the turn isn't slowed and the player can
## act at once.
const MODEL_DEATH_TIME := 0.5
const MODEL_DEATH_SHRINK := 0.25
## Damage preview badge: number size relative to the HP label, and the world size and
## spacing of its skull and status icons.
const SKULL_ICON := preload("res://ui/icons/skull.svg")
const PREVIEW_FONT_SCALE := 1.4
const PREVIEW_ICON_SIZE := 0.42
const PREVIEW_ICON_SPACING := 0.5
const STATUS_APPLIED_DURATION := 0.35
const STATUS_TICK_DURATION := 0.25
const STATUS_EXPIRED_DURATION := 0.3

var unit_id := -1
var _board: BoardView
var _max_hp := 1
var _material: StandardMaterial3D  ## Placeholder only; models keep their own look.
var _pulse_tween: Tween
var _visual_scale := 1.0
## One tag per status, in status order (the tick order): a Node3D with an "Icon" Sprite3D
## and a "Turns" Label3D.
var _status_tags: Dictionary[StatusData, Node3D] = {}
## The damage preview badge (see show_preview), or null.
var _preview: Node3D
## The pack model, or null for the placeholder capsule.
var _model: UnitModel
## How tall the unit stands before the elite / boss scale (the model's or the capsule's).
var _head_height := PLACEHOLDER_HEIGHT
## Status → its looping effect on the unit.
var _auras: Dictionary[StatusData, Node3D] = {}
## Where the damage preview floats (above the head, set by _layout_anchors).
var _preview_y := PLACEHOLDER_HEIGHT + PREVIEW_ABOVE

@onready var _body: Node3D = $Body
@onready var _placeholder: MeshInstance3D = $Body/Placeholder
@onready var _ring: MeshInstance3D = $Ring
@onready var _pick_body: StaticBody3D = $PickBody
@onready var _hp_label: Label3D = $HpLabel
## Turned to face the camera every frame, so the tags stay in a horizontal row on screen.
@onready var _status_row: Node3D = $StatusRow


## One-time setup (model, colors), then sync() to the unit's current state.
## Call after the view is in the tree (it uses @onready nodes).
func setup(unit: UnitState, board: BoardView) -> void:
	if not is_node_ready():
		push_error("UnitView.setup: add the view to the tree first")
		return
	set_process(false)  # Until it has status tags.
	unit_id = unit.id
	_board = board
	_visual_scale = unit.visual_scale
	_max_hp = unit.max_hp()
	name = "Unit%d" % unit.id
	if unit.data.model_scene != null:
		_placeholder.queue_free()
		_placeholder = null
		_model = UnitModel.new()
		_body.add_child(_model)
		_model.setup(unit.data.model_scene, unit.data.model_scale, unit.data.skin_color)
		if unit.data.held_item != null:
			_model.hold(unit.data.held_item, unit.data.held_item_replaces, unit.data.held_item_scale,
					unit.data.held_item_rotation, unit.data.held_item_bone, unit.data.held_item_offset)
	else:
		_material = StandardMaterial3D.new()
		_material.albedo_color = unit.data.color
		_placeholder.material_override = _material
	var ring_material := StandardMaterial3D.new()
	ring_material.albedo_color = PLAYER_RING_COLOR if unit.team == UnitState.Team.PLAYER else ENEMY_RING_COLOR
	ring_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_ring.material_override = ring_material
	_head_height = unit.data.model_height if _model != null else PLACEHOLDER_HEIGHT
	_layout_anchors(_head_height)
	sync(unit)


## Puts the HP label, status icons, damage preview and click target around a unit `height`
## tall (scaled by the elite / boss visual scale).
func _layout_anchors(height: float) -> void:
	var head := height * _visual_scale
	_hp_label.position.y = head + HP_LABEL_ABOVE
	_status_row.position.y = head + STATUS_ROW_ABOVE
	_preview_y = head + PREVIEW_ABOVE
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.3 * _visual_scale
	capsule.height = maxf(head, capsule.radius * 2.0 + 0.01)
	var collision := _pick_body.get_node("Collision") as CollisionShape3D
	collision.shape = capsule
	collision.position.y = head / 2.0


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
		_body.scale = Vector3.ONE * _visual_scale
		_ring.scale = Vector3.ONE * _visual_scale
		if _model != null:
			_model.reset()
	# Keep the tags (and their auras) of statuses still carried: they would blink out and in.
	var carried: Array[StatusData] = []
	for status in unit.statuses:
		carried.append(status.data)
	for status: StatusData in _status_tags.keys():
		if status not in carried:
			_remove_status_tag(status)
	for status in unit.statuses:
		_set_status_tag(status.data, status.turns_left)


## Walks the path cell by cell. Climbs go up then across, drops go across then down.
func play_move(path: Array[Vector2i]) -> void:
	_play_model(&"Walk")
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
		stepped.emit()
	_play_model(&"Idle")


## Moved by a spell: a blink (teleport), a leap in an arc (jump, retreat), a quick dash
## (charge) or a slide without walking (push, pull).
func play_displaced(path: Array[Vector2i], kind: MoveEffect.Kind) -> void:
	if path.is_empty():
		return
	var end := _board.cell_to_world(path.back())
	match kind:
		MoveEffect.Kind.TELEPORT:
			var tween := create_tween().set_trans(Tween.TRANS_QUAD)
			tween.tween_property(_body, "scale", Vector3(0.05, 1.6, 0.05) * _visual_scale, BLINK_DURATION)
			tween.tween_callback(func() -> void: position = end)
			tween.tween_property(_body, "scale", Vector3.ONE * _visual_scale, BLINK_DURATION)
			await tween.finished
		MoveEffect.Kind.JUMP, MoveEffect.Kind.RETREAT:
			if kind == MoveEffect.Kind.JUMP:
				_face(end)
			var start := position
			var top := maxf(start.y, end.y) + LEAP_HEIGHT
			var tween := create_tween()
			tween.tween_method(func(t: float) -> void:
				var flat := start.lerp(end, t)
				position = Vector3(flat.x, lerpf(lerpf(start.y, top, t), lerpf(top, end.y, t), t), flat.z),
				0.0, 1.0, LEAP_DURATION)
			await tween.finished
		_:
			var charge := kind == MoveEffect.Kind.CHARGE
			if charge:
				_play_model(&"Walk")
			for cell in path:
				var target := _board.cell_to_world(cell)
				if charge:
					_face(target)
				var tween := create_tween()
				tween.tween_property(self, "position", target, STEP_DURATION * (0.4 if charge else 0.5))
				await tween.finished
			if charge:
				_play_model(&"Idle")
	position = end
	_pick_body.set_meta(BoardView.CELL_META, path.back())


## Before the battle: a quick hop to another start cell.
func play_place(cell: Vector2i) -> void:
	var target := _board.cell_to_world(cell)
	var top := maxf(target.y, position.y) + 0.6
	var tween := create_tween()
	tween.tween_property(self, "position", Vector3(position.x, top, position.z), STEP_DURATION * 0.5)
	tween.tween_property(self, "position", Vector3(target.x, top, target.z), STEP_DURATION)
	tween.tween_property(self, "position:y", target.y, STEP_DURATION * 0.5)
	await tween.finished
	position = target
	_pick_body.set_meta(BoardView.CELL_META, cell)


## A short lunge toward the target cell (a hop when casting on its own cell).
func play_cast(target_cell: Vector2i, spell: SpellData = null) -> void:
	_play_cast_animation(spell)
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
	if amount > 0:
		_play_model(&"Hit")  # Plays on while the queue moves on; Idle follows by itself.
	await _play_hp_change("-%d" % amount, DAMAGE_COLOR, hp_after)


## The cheer of the winning side on the result screen (nothing for a model without the clip).
func play_victory() -> void:
	_play_model(&"Victory")


func play_heal(amount: int, hp_after: int) -> void:
	await _play_hp_change("+%d" % amount, HEAL_COLOR, hp_after)


## Adds (or refreshes) the status tag and floats the status name.
func play_status_applied(status: StatusData, turns_left: int) -> void:
	_set_status_tag(status, turns_left)
	_spawn_floating_number(status.display_name, status.color)
	await create_tween().tween_interval(STATUS_APPLIED_DURATION).finished


## Pulses the tag; the tick's damage or heal numbers come with the events that follow.
func play_status_ticked(status: StatusData) -> void:
	var tag: Node3D = _status_tags.get(status)
	if tag == null:
		await create_tween().tween_interval(STATUS_TICK_DURATION).finished
		return
	var tween := create_tween()
	tween.tween_property(tag, "scale", Vector3.ONE * 1.5, STATUS_TICK_DURATION * 0.5)
	tween.tween_property(tag, "scale", Vector3.ONE, STATUS_TICK_DURATION * 0.5)
	await tween.finished


## Fades the tag out and removes it.
func play_status_expired(status: StatusData) -> void:
	var tag: Node3D = _status_tags.get(status)
	if tag == null:
		return
	var tween := create_tween().set_parallel()
	tween.tween_property(tag.get_node("Icon"), "modulate:a", 0.0, STATUS_EXPIRED_DURATION)
	tween.tween_property(tag.get_node("Turns"), "modulate:a", 0.0, STATUS_EXPIRED_DURATION)
	await tween.finished
	_remove_status_tag(status)


## Shows what a cast would do to this unit: the damage / heal range, a skull when it can
## kill, and the statuses it would apply. Replaces any previous badge.
func show_preview(entry: DamagePreview.Entry) -> void:
	clear_preview()
	_preview = Node3D.new()
	_preview.name = "Preview"
	_preview.position = Vector3(0.0, _preview_y, 0.0)
	var amount := Label3D.new()
	amount.name = "Amount"
	amount.text = entry.amount_text()
	amount.modulate = DAMAGE_COLOR if entry.max_damage > 0 else (HEAL_COLOR if entry.max_heal > 0 else Color.WHITE)
	amount.font_size = int(_hp_label.font_size * PREVIEW_FONT_SCALE)
	amount.outline_size = _hp_label.outline_size
	amount.pixel_size = STATUS_TAG_PIXEL_SIZE
	amount.no_depth_test = true
	amount.render_priority = 3
	amount.position = Vector3(0.0, 0.3, 0.0)
	_preview.add_child(amount)
	var icons: Array[Sprite3D] = []
	if entry.can_kill:
		icons.append(_preview_icon(SKULL_ICON, Color.WHITE, "Skull"))
	for status in entry.statuses:
		icons.append(_preview_icon(status.display_icon(), status.color, "Status"))
	for i in icons.size():
		icons[i].position = Vector3((i - (icons.size() - 1) / 2.0) * PREVIEW_ICON_SPACING, -0.15, 0.0)
		_preview.add_child(icons[i])
	add_child(_preview)
	set_process(true)


func clear_preview() -> void:
	if _preview != null:
		remove_child(_preview)
		_preview.queue_free()
		_preview = null
		set_process(not _status_tags.is_empty())


func has_preview() -> bool:
	return _preview != null


## The badge's amount text ("" without a badge).
func preview_text() -> String:
	return (_preview.get_node("Amount") as Label3D).text if _preview != null else ""


## How many skull and status icons the badge shows.
func preview_icon_count() -> int:
	return _preview.get_child_count() - 1 if _preview != null else 0


func _preview_icon(texture: Texture2D, color: Color, icon_name: String) -> Sprite3D:
	var icon := Sprite3D.new()
	icon.name = icon_name
	icon.texture = texture
	icon.modulate = color
	icon.pixel_size = PREVIEW_ICON_SIZE / maxf(texture.get_width(), 1.0)
	icon.no_depth_test = true
	icon.render_priority = 3
	return icon


## The turns shown next to each status icon, in order, e.g. ["3", "1"].
func status_turns_texts() -> Array[String]:
	var texts: Array[String] = []
	for status in _status_tags:
		texts.append((_status_tags[status].get_node("Turns") as Label3D).text)
	return texts


## The icon textures shown, in order.
func status_icon_textures() -> Array[Texture2D]:
	var textures: Array[Texture2D] = []
	for status in _status_tags:
		textures.append((_status_tags[status].get_node("Icon") as Sprite3D).texture)
	return textures


func play_death() -> void:
	set_active(false)
	_hp_label.hide()
	_pick_body.collision_layer = 0  # Hidden nodes still collide; dead units can't be clicked.
	var length := _play_model(&"Death")
	if length > 0.0:
		await create_tween().tween_interval(minf(length, MODEL_DEATH_TIME)).finished
	var tween := create_tween().set_parallel().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	var shrink := MODEL_DEATH_SHRINK if length > 0.0 else DEATH_DURATION
	tween.tween_property(_body, "scale", Vector3(1.2, 0.05, 1.2), shrink)
	tween.tween_property(_ring, "scale", Vector3.ZERO, shrink)
	await tween.finished
	hide()


## Pulses the team ring while it's this unit's turn.
func set_active(active: bool) -> void:
	if _pulse_tween != null:
		_pulse_tween.kill()
		_pulse_tween = null
	_ring.scale = Vector3.ONE * _visual_scale
	if active and visible:
		_pulse_tween = create_tween().set_loops().set_trans(Tween.TRANS_SINE)
		_pulse_tween.tween_property(_ring, "scale", Vector3.ONE * ACTIVE_PULSE_SCALE * _visual_scale, ACTIVE_PULSE_DURATION)
		_pulse_tween.tween_property(_ring, "scale", Vector3.ONE * _visual_scale, ACTIVE_PULSE_DURATION)


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
	if text.substr(1) == "0":
		return  # Nothing happened (a heal at full HP, damage fully resisted): no "+0".
	_spawn_floating_number(text, color)
	var tween := create_tween()
	if _material != null:
		var base := _material.albedo_color
		tween.tween_property(_material, "albedo_color", color, HIT_DURATION * 0.3)
		tween.tween_property(_material, "albedo_color", base, HIT_DURATION * 0.7)
	else:
		if _model != null:
			_model.flash(color, HIT_DURATION)
		tween.tween_interval(HIT_DURATION)
	await tween.finished


## A text floating up from the unit without any other animation (the instant battle speed);
## `stack` > 0 starts it higher, above the ones already floating from the same action.
func float_text(text: String, color: Color, stack := 0) -> void:
	_spawn_floating_number(text, color, stack * FLOAT_STACK_STEP)


func _spawn_floating_number(text: String, color: Color, lift := 0.0) -> void:
	var label := _hp_label.duplicate() as Label3D
	label.name = "FloatingNumber"
	label.text = text
	label.modulate = color
	label.position.y += lift
	label.show()
	add_child(label, true)  # Readable names (FloatingNumber2…) when several float at once.
	var tween := label.create_tween().set_parallel()
	tween.tween_property(label, "position:y", label.position.y + 0.8, FLOAT_DURATION)
	tween.tween_property(label, "modulate:a", 0.0, FLOAT_DURATION).set_delay(FLOAT_DURATION * 0.4)
	tween.chain().tween_callback(label.queue_free)


## Keeps the tag row and the preview badge facing the camera; runs only while there are any.
func _process(_delta: float) -> void:
	var camera := get_viewport().get_camera_3d()
	if camera != null:
		_status_row.global_basis = camera.global_basis
		if _preview != null:
			_preview.global_basis = camera.global_basis


func _set_status_tag(status: StatusData, turns_left: int) -> void:
	var tag: Node3D = _status_tags.get(status)
	if tag == null:
		tag = Node3D.new()
		tag.name = "Tag"
		var icon := Sprite3D.new()
		icon.name = "Icon"
		icon.texture = status.display_icon()
		# World-sized (unlike the HP label), so the spacing between icons holds at any zoom.
		icon.pixel_size = STATUS_ICON_SIZE / maxf(icon.texture.get_width(), 1.0)
		icon.no_depth_test = true
		icon.render_priority = 1
		icon.modulate = status.color
		tag.add_child(icon)
		var turns := Label3D.new()
		turns.name = "Turns"
		turns.no_depth_test = true
		turns.pixel_size = STATUS_TAG_PIXEL_SIZE
		turns.font_size = _hp_label.font_size
		turns.outline_size = _hp_label.outline_size
		turns.render_priority = 2
		turns.position = Vector3(STATUS_ICON_SIZE * 0.35, -STATUS_ICON_SIZE * 0.4, 0.0)
		tag.add_child(turns)
		_status_row.add_child(tag)
		_status_tags[status] = tag
		_add_aura(status)
	(tag.get_node("Turns") as Label3D).text = str(turns_left)
	_layout_status_tags()
	set_process(true)


func _remove_status_tag(status: StatusData) -> void:
	var tag: Node3D = _status_tags.get(status)
	if tag == null:
		return
	_status_tags.erase(status)
	tag.queue_free()
	if _auras.has(status):
		_auras[status].queue_free()
		_auras.erase(status)
	_layout_status_tags()
	set_process(not _status_tags.is_empty() or _preview != null)


func _clear_status_tags() -> void:
	for status in _status_tags.keys():
		_remove_status_tag(status)


## The status's looping effect on the unit, while it carries the status (none when it has no aura).
func _add_aura(status: StatusData) -> void:
	if status.aura_effect == null or _auras.has(status):
		return
	var aura := status.aura_effect.instantiate() as Node3D
	if aura == null:
		return
	aura.position.y = _head_height * _visual_scale * 0.5
	aura.scale = Vector3.ONE * _visual_scale
	add_child(aura)
	_auras[status] = aura


func aura_count() -> int:
	return _auras.size()


## Centers the tags in a row along the row node's local X.
func _layout_status_tags() -> void:
	var index := 0
	var count := _status_tags.size()
	for status in _status_tags:
		_status_tags[status].position = Vector3((index - (count - 1) / 2.0) * STATUS_TAG_SPACING, 0.0, 0.0)
		index += 1


## Plays a logical animation on the model; returns its length (0 for a placeholder or a model
## without it).
func _play_model(logical: StringName) -> float:
	return _model.play(logical) if _model != null else 0.0


## The spell's animation: its own cut (and borrowed) clip when it sets one, else the caster's
## logical animation whole. A borrowed clip that doesn't fit falls back to the logical one.
func _play_cast_animation(spell: SpellData) -> void:
	if _model == null:
		return
	var logical := _cast_animation(spell)
	var custom := spell != null and (spell.animation_scene != null or spell.animation_start > 0.0
			or spell.animation_end > 0.0 or not is_equal_approx(spell.animation_speed, 1.0))
	if custom and _model.play_clip(logical, spell.animation_scene, spell.animation_name,
			spell.animation_start, spell.animation_end, spell.animation_speed) > 0.0:
		return
	_model.play(logical)


func max_hp() -> int:
	return _max_hp


## Where effects start on this unit: its chest, in world space.
func chest_position() -> Vector3:
	return global_position + Vector3(0.0, _head_height * _visual_scale * 0.6, 0.0)


## Attack for a melee damage spell, Cast otherwise, unless the spell names its own animation.
func _cast_animation(spell: SpellData) -> StringName:
	if spell == null:
		return &"Attack"
	if not spell.cast_animation.is_empty():
		return spell.cast_animation
	var damages := spell.effects.any(func(effect: EffectData) -> bool: return effect is DamageEffect)
	return &"Attack" if damages and spell.max_range <= 1 else &"Cast"  # A buff or a heal is not a sword swing.


## Plays an effect scene on the unit (at chest height, scaled with the unit); it frees itself.
## A null scene does nothing.
func spawn_fx(scene: PackedScene, tint := Color.WHITE) -> void:
	if scene == null:
		return
	var effect := scene.instantiate() as Node3D
	if effect is Fx and tint != Color.WHITE:
		(effect as Fx).set_tint(tint)
	effect.position.y = _head_height * _visual_scale * 0.6
	effect.scale = Vector3.ONE * _visual_scale
	add_child(effect)


## Turns toward a board cell (the model faces where it is going or what it targets).
func face_cell(cell: Vector2i) -> void:
	_face(_board.cell_to_world(cell))


func has_model() -> bool:
	return _model != null


func model() -> UnitModel:
	return _model


func _set_hp(hp: int) -> void:
	_hp_label.text = "%d/%d" % [hp, _max_hp]


func _face(target: Vector3) -> void:
	var direction := Vector2(target.x - position.x, target.z - position.z)
	if not direction.is_zero_approx():
		_body.rotation.y = atan2(direction.x, direction.y)
