class_name UnitModel
extends Node3D
## A character model from an asset pack, behind one animation contract. The model's own
## AnimationPlayer is found by type; the animations the game needs are asked for by a logical
## name (Idle, Walk, Attack, Cast, Hit, Death, Victory, Defeat) and resolved to whatever the
## model calls them: each part of a name between "|" (Blender's "Armature|Idle", or a mangled
## export's "Armature|Armature|Idle|Armature|Id") is compared against candidates, so models
## from different packs work, and a missing animation just
## does nothing (the caller falls back to a tween). Also re-colors the skin material and
## flashes the model (hit feedback). Adding a hero or enemy is a model file plus data.

## Logical name → candidate animation names, in order of preference.
const ANIMATIONS := {
	&"Idle": ["Idle", "Flying_Idle"],
	&"Walk": ["Walk", "Run", "Fast_Flying"],
	&"Attack": ["SwordSlash", "Sword", "Punch", "Attack"],
	&"Cast": ["Shoot_OneHanded", "SwordSlash", "Sword", "Punch", "Attack"],
	&"Hit": ["RecieveHit", "HitRecieve", "HitReact", "Hit"],
	&"Death": ["Death"],
	&"Victory": ["Victory"],
	&"Defeat": ["Defeat"],
}
## Animations that loop.
const LOOPING: Array[StringName] = [&"Idle", &"Walk"]
const SKIN_MATERIAL := "Skin"
const BLEND := 0.1

var _player: AnimationPlayer
var _resolved: Dictionary[StringName, String] = {}
var _meshes: Array[MeshInstance3D] = []
var _overlay: StandardMaterial3D
var _flash_tween: Tween
## Borrowed animations already added to the player: "scene path|name" → its name there.
var _borrowed: Dictionary[String, String] = {}
## Bumped by every clip; a trimmed clip's timer that finds it changed gives up.
var _clip_serial := 0


## Instances `scene` under this node at `model_scale` and starts its Idle. `skin_color` with
## alpha 0 leaves the pack's skin alone.
func setup(scene: PackedScene, model_scale: float, skin_color: Color) -> void:
	var model := scene.instantiate() as Node3D
	add_child(model)
	scale = Vector3.ONE * model_scale
	var players := model.find_children("*", "AnimationPlayer", true, false)
	_player = players[0] as AnimationPlayer if not players.is_empty() else null
	for mesh in model.find_children("*", "MeshInstance3D", true, false):
		_meshes.append(mesh as MeshInstance3D)
	if skin_color.a > 0.0:
		_apply_skin(skin_color)
	if _player != null:
		for logical in ANIMATIONS:
			var real := _resolve(logical)
			if not real.is_empty():
				_resolved[logical] = real
				_player.get_animation(real).loop_mode = Animation.LOOP_LINEAR if logical in LOOPING else Animation.LOOP_NONE
		_player.animation_finished.connect(_on_animation_finished)
	play(&"Idle")


## Swaps the model's part named `replaces` for `item` (see UnitData.held_item): the item is
## added beside it, so it follows the same bone, with the part's transform, `item_scale` and
## `rotation_degrees` on top. A missing part is reported and nothing changes.
func hold(item: PackedScene, replaces: String, item_scale: float, rotation_degrees: Vector3) -> void:
	var part := find_child(replaces, true, false) as Node3D
	if item == null or part == null:
		push_error("UnitModel: no part named '%s' to replace" % replaces)
		return
	part.hide()
	var held := item.instantiate() as Node3D
	held.name = "HeldItem"
	held.transform = part.transform * Transform3D(Basis.from_euler(rotation_degrees * PI / 180.0).scaled(Vector3.ONE * item_scale), Vector3.ZERO)
	part.get_parent().add_child(held)
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
		push_warning("UnitModel: the animation \"%s\" of %s doesn't fit this skeleton (%d of %d tracks have no bone here)" % [
				animation_name, source.resource_path, missing, found.get_track_count()])
		return ""
	found.loop_mode = Animation.LOOP_NONE
	var library_name := "borrowed_%d" % _player.get_animation_library_list().size()
	var library := AnimationLibrary.new()
	library.add_animation(&"clip", found)
	_player.add_animation_library(library_name, library)
	_borrowed[key] = "%s/clip" % library_name
	return _borrowed[key]


## How many of the animation's tracks point at a node or bone this model doesn't have.
func _missing_tracks(animation: Animation) -> int:
	var root := _player.get_node_or_null(_player.root_node)
	var missing := 0
	for track in animation.get_track_count():
		var path := animation.track_get_path(track)
		var node := root.get_node_or_null(NodePath(path.get_concatenated_names())) if root != null else null
		if node == null:
			missing += 1
		elif node is Skeleton3D and path.get_subname_count() > 0 and (node as Skeleton3D).find_bone(path.get_subname(0)) == -1:
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


## Gives each mesh its own copy of the geometry with the "Skin" material in `color` (the
## imported meshes and materials are shared by every instance of the same model). A copied
## mesh (a few hundred KB per unit) rather than a surface override: freeing an instance that
## holds an override material logs an engine error in the headless dummy renderer, which the
## test runner counts as a failure.
func _apply_skin(color: Color) -> void:
	for mesh in _meshes:
		if mesh.mesh == null:
			continue
		var own_mesh := mesh.mesh.duplicate() as Mesh
		var changed := false
		for surface in own_mesh.get_surface_count():
			var material := own_mesh.surface_get_material(surface) as BaseMaterial3D
			if material != null and material.resource_name == SKIN_MATERIAL:
				var own := material.duplicate() as BaseMaterial3D
				own.albedo_color = color
				own_mesh.surface_set_material(surface, own)
				changed = true
		if changed:
			mesh.mesh = own_mesh
