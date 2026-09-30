class_name UnitModel
extends Node3D
## A character model from an asset pack, behind one animation contract. The model's own
## AnimationPlayer is found by type; the animations the game needs are asked for by a logical
## name (Idle, Walk, Attack, Cast, Hit, Death, Victory, Defeat) and resolved to whatever the
## model calls them: the part of a name after a "|" (Blender's "Armature|Idle") is compared
## against candidates, so models from different packs work, and a missing animation just
## does nothing (the caller falls back to a tween). Also re-colors the skin material and
## flashes the model (hit feedback). Adding a hero or enemy is a model file plus data.

## Logical name → candidate animation names, in order of preference.
const ANIMATIONS := {
	&"Idle": ["Idle"],
	&"Walk": ["Walk", "Run"],
	&"Attack": ["SwordSlash", "Punch"],
	&"Cast": ["Shoot_OneHanded", "SwordSlash"],
	&"Hit": ["RecieveHit", "HitRecieve", "Hit"],
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
	var real := _resolved[logical]
	var again := _player.is_playing() and _player.current_animation == real
	_player.play(real, BLEND)
	if again and logical not in LOOPING:
		_player.seek(0.0, true)  # Playing the animation already playing does nothing: restart an action.
	return _player.get_animation(real).length


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
			if animation == candidate or animation.ends_with("|" + candidate):
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
