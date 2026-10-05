class_name WorkshopSession
extends RefCounted
## The model workshop's state and rules, without any UI: the model built from its recipe with a
## draft of its tweaks, edits (each one undoable), the pose overrides, and saving. The workshop
## scene shows `kit` and calls these; it rebuilds its view on `rebuilt`.

## The model was built again (after an edit, an undo or a reload): `kit` is a new model.
signal rebuilt

var model_name := ""
var tweaks := ModelTweaks.new()
var kit: ModelKit
## Show the recipe as it is, without the tweaks (to compare).
var show_original := false:
	set(value):
		show_original = value
		rebuild()
var dirty := false
## Each joint's rest position / rotation (radians) in the built model, tweaks included: what the
## clips are offsets from.
var rests: Dictionary[String, Dictionary] = {}

var _undo: Array[ModelTweaks] = []
var _redo: Array[ModelTweaks] = []

const MAX_UNDO := 100


## Opens a model: its tweaks file as the draft. False when the recipe doesn't load.
func open(name_: String) -> bool:
	model_name = name_
	tweaks = ModelBuilder.load_tweaks(name_)
	_undo.clear()
	_redo.clear()
	dirty = false
	return rebuild(true)


## Builds the model again from the draft (`fresh`: the recipe is read from disk again).
func rebuild(fresh := false) -> bool:
	if model_name.is_empty():
		return false
	var built := ModelBuilder.build_kit(model_name, null if show_original else tweaks, fresh)
	if built == null:
		return false
	if kit != null:
		kit.root.free()
	kit = built
	rests.clear()
	for joint_name in kit.joints:
		var node := kit.joints[joint_name]
		rests[joint_name] = {"position": node.position, "rotation": node.rotation}
	rebuilt.emit()
	return true


## The name paths of every part and joint (`Rig/Hips/Head`), parents first.
func node_paths() -> PackedStringArray:
	var paths: PackedStringArray = []
	_collect(kit.root, "", paths)
	return paths


func _collect(node: Node, prefix: String, into: PackedStringArray) -> void:
	for child in node.get_children():
		if child is Node3D:
			var path := prefix + String(child.name)
			into.append(path)
			_collect(child, path + "/", into)


func orphans() -> PackedStringArray:
	return kit.orphans if kit != null else PackedStringArray()


# --- Node tweaks ---------------------------------------------------------------------------

## The tweak on a node (a copy of nothing: null when it has none).
func node_tweak(path: String) -> NodeTweak:
	return tweaks.tweak_for(path)


## Sets one field of a node's tweak (NodeTweak's names: position_offset, rotation_offset,
## scale_factor, recolor, color, emissive, hidden). `checkpoint`: false while a slider is dragged
## (the drag's start took it).
func set_node_field(path: String, field: String, value: Variant, checkpoint := true) -> void:
	if checkpoint:
		remember()
	tweaks.tweak_or_new(path).set(field, value)
	dirty = true
	rebuild()


## Drops a node's tweak.
func reset_node(path: String) -> void:
	var tweak := tweaks.tweak_for(path)
	if tweak == null:
		return
	remember()
	tweaks.nodes.erase(tweak)
	dirty = true
	rebuild()


# --- Pose overrides ------------------------------------------------------------------------

func overrides_of(clip: String) -> Array[PoseOverride]:
	var found: Array[PoseOverride] = []
	for override in tweaks.pose_overrides:
		if override.clip == clip:
			found.append(override)
	found.sort_custom(func(a: PoseOverride, b: PoseOverride) -> bool: return a.time < b.time)
	return found


func _find_override(clip: String, time: float, joint: String, is_position: bool) -> PoseOverride:
	for override in tweaks.pose_overrides:
		if override.clip == clip and override.joint == joint and override.is_position == is_position \
				and absf(override.time - time) < PoseOverride.SAME_TIME:
			return override
	return null


## Makes `joint` be at `value` at `time` of `clip` (a rotation in degrees, or a position offset).
func set_pose(clip: String, time: float, joint: String, is_position: bool, value: Vector3, checkpoint := true) -> void:
	if checkpoint:
		remember()
	var override := _find_override(clip, time, joint, is_position)
	if override == null:
		override = PoseOverride.new()
		override.clip = clip
		override.time = time
		override.joint = joint
		override.is_position = is_position
		tweaks.pose_overrides.append(override)
	override.value = value
	dirty = true
	rebuild()


func remove_pose(clip: String, time: float, joint: String, is_position: bool) -> void:
	var override := _find_override(clip, time, joint, is_position)
	if override == null:
		return
	remember()
	tweaks.pose_overrides.erase(override)
	dirty = true
	rebuild()


# --- Renames -------------------------------------------------------------------------------

## An orphan tweak (a path the recipe no longer builds) follows `new_path` from now on.
func map_orphan(old_path: String, new_path: String) -> void:
	remember()
	tweaks.renames[old_path] = new_path
	dirty = true
	rebuild()


# --- Undo ----------------------------------------------------------------------------------

## Remembers the draft before an edit (called by the edits; a slider drag calls it once at its start).
func remember() -> void:
	_undo.append(tweaks.duplicate(true) as ModelTweaks)
	if _undo.size() > MAX_UNDO:
		_undo.pop_front()
	_redo.clear()


func can_undo() -> bool:
	return not _undo.is_empty()


func can_redo() -> bool:
	return not _redo.is_empty()


func undo() -> void:
	if _undo.is_empty():
		return
	_redo.append(tweaks)
	tweaks = _undo.pop_back()
	dirty = true
	rebuild()


func redo() -> void:
	if _redo.is_empty():
		return
	_undo.append(tweaks)
	tweaks = _redo.pop_back()
	dirty = true
	rebuild()


# --- Saving --------------------------------------------------------------------------------

## Writes the tweaks file and rebuilds the model's scene with it.
func save() -> Error:
	var error := ModelBuilder.save_tweaks(model_name, tweaks)
	if error != OK:
		return error
	var built := ModelBuilder.build_kit(model_name, tweaks)
	if built == null:
		return ERR_CANT_CREATE
	error = ModelBuilder.save_scene(model_name, built)
	built.root.free()
	if error == OK:
		dirty = false
	return error
