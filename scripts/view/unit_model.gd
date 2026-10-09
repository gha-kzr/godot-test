class_name UnitModel
extends Node3D
## A unit's model (a hand-built scene, see ModelKit), behind one animation contract. The model's
## own AnimationPlayer is found by type; the animations the game needs are asked for by a
## logical name (Idle, Walk, Attack, Cast, Shoot, Hit, Death, Victory, Defeat) and resolved to whatever
## the model calls them: each part of a name between "|" (an imported "Armature|Idle") is
## compared against candidates, so a scene from another source works too, and a missing
## animation just does nothing (the caller falls back to a tween). Also flashes the model (hit
## feedback). Adding a hero or enemy is a model scene plus data.

## Logical name → candidate animation names, in order of preference.
const ANIMATIONS := {
	&"Idle": ["Idle", "Flying_Idle"],
	&"Walk": ["Walk", "Run", "Fast_Flying"],
	&"Attack": ["SwordSlash", "Sword", "Weapon", "Punch", "Attack"],
	&"Cast": ["Cast", "Shoot_OneHanded", "SwordSlash", "Sword", "Weapon", "Punch", "Attack"],
	&"Shoot": ["Shoot", "Cast", "Attack"],
	&"Hit": ["RecieveHit", "HitRecieve", "HitReact", "Idle_HitReact_Left", "Hit"],
	&"Death": ["Death"],
	&"Victory": ["Victory"],
	&"Defeat": ["Defeat"],
}
## Animations that loop.
const LOOPING: Array[StringName] = [&"Idle", &"Walk"]
const BLEND := 0.1
## How a hero in stealth looks to its own team: this opaque (of 1), a little towards this colour.
const GHOST_ALPHA := 0.45
const GHOST_TINT := Color(0.7, 0.85, 1.0)

var _player: AnimationPlayer
var _resolved: Dictionary[StringName, String] = {}
var _meshes: Array[MeshInstance3D] = []
var _overlay: StandardMaterial3D
var _flash_tween: Tween
## Whether the model is drawn see-through (see set_ghost), and the surface overrides it replaced: mesh → one per surface.
var _ghost := false
var _ghost_saved: Dictionary[MeshInstance3D, Array] = {}
## Borrowed animations already added to the player: "scene path|name" → its name there.
var _borrowed: Dictionary[String, String] = {}
## Bumped by every clip; a trimmed clip's timer that finds it changed gives up.
var _clip_serial := 0


## Instances `scene` under this node at `model_scale` and starts its Idle.
func setup(scene: PackedScene, model_scale: float) -> void:
	var model := scene.instantiate() as Node3D
	add_child(model)
	scale = Vector3.ONE * model_scale
	var players := model.find_children("*", "AnimationPlayer", true, false)
	_player = players[0] as AnimationPlayer if not players.is_empty() else null
	for mesh in model.find_children("*", "MeshInstance3D", true, false):
		_meshes.append(mesh as MeshInstance3D)
	if _player != null:
		for logical in ANIMATIONS:
			var real := _resolve(logical)
			if not real.is_empty():
				_resolved[logical] = real
				_player.get_animation(real).loop_mode = Animation.LOOP_LINEAR if logical in LOOPING else Animation.LOOP_NONE
		_player.animation_finished.connect(_on_animation_finished)
	play(&"Idle")


## Gives the model `item` to hold (see UnitData.held_item): in place of its part named
## `replaces` (hidden; the item is added beside it, so it follows the same bone, with the
## part's transform), or else on the joint `bone`; then `item_scale`, `rotation_degrees` and
## `offset` on top. A missing part or joint is reported and nothing changes.
func hold(item: PackedScene, replaces: String, item_scale: float, rotation_degrees: Vector3,
		bone := "", offset := Vector3.ZERO) -> void:
	if item == null:
		return
	var place := Transform3D(Basis.from_euler(rotation_degrees * PI / 180.0).scaled(Vector3.ONE * item_scale), offset)
	var parent: Node3D
	var base := Transform3D.IDENTITY
	if not replaces.is_empty():
		var part := find_child(replaces, true, false) as Node3D
		if part == null:
			push_error("UnitModel: no part named '%s' to replace" % replaces)
			return
		part.hide()
		parent = part.get_parent() as Node3D
		base = part.transform
	else:
		parent = find_child(bone.validate_node_name(), true, false) as Node3D  # "Hand.R" is the node Hand_R.
		if parent == null:
			push_error("UnitModel: no joint named '%s' to hold an item" % bone)
			return
	var held := item.instantiate() as Node3D
	held.name = "HeldItem"
	held.transform = base * place
	parent.add_child(held)
	for mesh in held.find_children("*", "MeshInstance3D", true, false):
		_meshes.append(mesh as MeshInstance3D)  # It flashes with the body.


## Back to a clean standing model: no flash, no held Death or Walk pose (a revived or re-synced
## unit).
func reset() -> void:
	if _flash_tween != null:
		_flash_tween.kill()
	for mesh in _meshes:
		mesh.material_overlay = null
	if _player != null and _resolved.has(&"Idle"):
		_player.play(_resolved[&"Idle"], 0.0)
		_player.seek(0.0, true)


func has_animation(logical: StringName) -> bool:
	return _resolved.has(logical)


## Plays a logical animation; returns its length in seconds (0 when the model has none).
func play(logical: StringName) -> float:
	if _player == null or not _resolved.has(logical):
		return 0.0
	_clip_serial += 1  # A cut clip's end timer must not cut this one short.
	var real := _resolved[logical]
	var again := _player.is_playing() and _player.current_animation == real
	_player.play(real, BLEND)
	if again and logical not in LOOPING:
		_player.seek(0.0, true)  # Playing the animation already playing does nothing: restart an action.
	return _player.get_animation(real).length


## Plays a segment of an animation and returns how long it plays (0 when nothing did).
## `source` null: this model's own animation for the logical name `logical`. Else the animation
## named `animation_name` (the first one when empty) of the model file `source`, borrowed when
## its skeleton fits this one. The segment runs from `start` to `end` seconds (end <= 0: to
## the animation's end) at `speed`; a cut one hands back to Idle at its end.
func play_clip(logical: StringName, source: PackedScene = null, animation_name := "", start := 0.0, end := 0.0, speed := 1.0) -> float:
	if _player == null:
		return 0.0
	var real := ""
	if source == null:
		real = _resolved.get(logical, "")
	else:
		real = _borrow(source, animation_name)
	if real.is_empty():
		return 0.0
	var length := _player.get_animation(real).length
	var from := clampf(start, 0.0, length)
	var to := length if end <= 0.0 else clampf(end, from, length)
	var rate := maxf(speed, 0.01)
	_clip_serial += 1
	_player.play(real, BLEND, rate)
	_player.seek(from, true)  # Also restarts an action played twice in a row.
	if to < length - 0.001:
		var serial := _clip_serial
		create_tween().tween_interval((to - from) / rate).finished.connect(func() -> void:
			if serial == _clip_serial:
				play(&"Idle"))
	return (to - from) / rate


## Adds an animation of another model file to this model's player (once) and returns its
## name there, or "" when the file has no such animation or its skeleton doesn't fit (logged).
func _borrow(source: PackedScene, animation_name: String) -> String:
	var key := "%s|%s" % [source.resource_path, animation_name]
	if _borrowed.has(key):
		return _borrowed[key]  # "" for one that was refused: not tried (and logged) again.
	_borrowed[key] = ""
	var found: Animation
	var instance := source.instantiate()
	var players := instance.find_children("*", "AnimationPlayer", true, false)
	if not players.is_empty():
		var other := players[0] as AnimationPlayer
		for candidate in other.get_animation_list():
			if candidate == "RESET":
				continue
			if animation_name.is_empty() or candidate == animation_name or candidate.ends_with("|" + animation_name):
				found = other.get_animation(candidate).duplicate() as Animation
				break
	instance.free()
	if found == null:
		push_warning("UnitModel: %s has no animation \"%s\"" % [source.resource_path, animation_name])
		return ""
	var missing := _missing_tracks(found)
	if found.get_track_count() == 0 or missing > found.get_track_count() / 4:
		push_warning("UnitModel: the animation \"%s\" of %s doesn't fit this model (%d of %d tracks have no joint here)" % [
				animation_name, source.resource_path, missing, found.get_track_count()])
		return ""
	found.loop_mode = Animation.LOOP_NONE
	var library_name := "borrowed_%d" % _player.get_animation_library_list().size()
	var library := AnimationLibrary.new()
	library.add_animation(&"clip", found)
	_player.add_animation_library(library_name, library)
	_borrowed[key] = "%s/clip" % library_name
	return _borrowed[key]


## How many of the animation's tracks point at a node this model doesn't have.
func _missing_tracks(animation: Animation) -> int:
	var root := _player.get_node_or_null(_player.root_node)
	var missing := 0
	for track in animation.get_track_count():
		var path := animation.track_get_path(track)
		var node := root.get_node_or_null(NodePath(path.get_concatenated_names())) if root != null else null
		if node == null:
			missing += 1
	return missing


## Tints the whole model with `color` for `duration` (a hit), fading back.
func flash(color: Color, duration: float) -> void:
	if _meshes.is_empty():
		return
	if _overlay == null:
		_overlay = StandardMaterial3D.new()
		_overlay.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_overlay.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_overlay.albedo_color = Color(color, 0.65)
	for mesh in _meshes:
		mesh.material_overlay = _overlay
	if _flash_tween != null:
		_flash_tween.kill()
	_flash_tween = create_tween()
	_flash_tween.tween_property(_overlay, "albedo_color:a", 0.0, duration)
	_flash_tween.tween_callback(func() -> void:
		for mesh in _meshes:
			mesh.material_overlay = null)


## Draws the model see-through (a hero in stealth, as its own team sees it) or opaque again: every mesh gets a copy of
## its material with some transparency and a faint cool tint. (A depth pre-pass keeps the parts of one model from
## showing through each other.) The models set one material on each mesh (`material_override`); a mesh that has only
## surface materials is handled too.
func set_ghost(on: bool) -> void:
	if on == _ghost:
		return
	_ghost = on
	var made: Dictionary[Material, Material] = {}
	for mesh in _meshes:
		if on:
			var saved: Array = [mesh.material_override]
			var whole := mesh.material_override as BaseMaterial3D
			if whole != null:
				mesh.material_override = _ghost_copy(whole, made)
			elif mesh.mesh != null:
				for surface in mesh.mesh.get_surface_count():
					saved.append(mesh.get_surface_override_material(surface))
					var base := mesh.get_active_material(surface) as BaseMaterial3D
					if base != null:
						mesh.set_surface_override_material(surface, _ghost_copy(base, made))
			_ghost_saved[mesh] = saved
		else:
			var saved: Array = _ghost_saved.get(mesh, [null])
			mesh.material_override = saved[0]
			for surface in range(1, saved.size()):
				mesh.set_surface_override_material(surface - 1, saved[surface])
	if not on:
		_ghost_saved.clear()


func _ghost_copy(base: BaseMaterial3D, made: Dictionary[Material, Material]) -> Material:
	if not made.has(base):
		var copy := base.duplicate() as BaseMaterial3D
		copy.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_DEPTH_PRE_PASS
		copy.albedo_color = Color(base.albedo_color.lerp(GHOST_TINT, 0.2), GHOST_ALPHA)
		made[base] = copy
	return made[base]


func is_ghost() -> bool:
	return _ghost


## An action that ends (an attack, a hit, a cheer) drops back to Idle on its own; a death stays.
func _on_animation_finished(animation: StringName) -> void:
	if not _resolved.has(&"Death") or animation != _resolved[&"Death"]:
		play(&"Idle")


func _resolve(logical: StringName) -> String:
	for candidate: String in ANIMATIONS[logical]:
		for animation in _player.get_animation_list():
			if candidate in animation.split("|"):
				return animation
	return ""
