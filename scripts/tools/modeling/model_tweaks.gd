class_name ModelTweaks
extends Resource
## The hand-made polish of one model (`assets/models/<name>.tweaks.tres`), re-applied each time
## the recipe is rebuilt: part and joint tweaks by name path, pose overrides by clip, and a
## `renames` table (old path -> new path) for when a recipe renames or moves a node. A tweak whose
## node is gone is an *orphan*: reported, never dropped from the file.

@export var nodes: Array[NodeTweak] = []
@export var pose_overrides: Array[PoseOverride] = []
@export var renames: Dictionary[String, String] = {}


## The tweak for `path` (after renames), or null.
func tweak_for(path: String) -> NodeTweak:
	for tweak in nodes:
		if resolve(tweak.path) == resolve(path):
			return tweak
	return null


## The tweak for `path`, made empty if there was none (the workshop edits through this).
func tweak_or_new(path: String) -> NodeTweak:
	var tweak := tweak_for(path)
	if tweak == null:
		tweak = NodeTweak.new()
		tweak.path = path
		nodes.append(tweak)
	return tweak


func resolve(path: String) -> String:
	return renames.get(path, path)


## Applies the node tweaks to `kit`'s nodes; returns descriptions of the tweaks whose node (or joint) is missing.
func apply(kit: ModelKit) -> PackedStringArray:
	var orphans: PackedStringArray = []
	for tweak in nodes:
		var node := kit.root.get_node_or_null(resolve(tweak.path)) as Node3D
		if node == null:
			orphans.append(tweak.path)
		else:
			tweak.apply_to(node, kit)
	for override in pose_overrides:
		if not kit.joints.has(override.joint):
			orphans.append("%s@%s: %s" % [override.clip, override.time, override.joint])
	return orphans


## The clip's poses (`[time, {key: Vector3}]`, as RigAnimator takes them) with the overrides for
## `clip_name` applied; the input is not changed. A loop's override at its start or end applies to
## both. With `joints`, an override of any other joint is left out (apply() reports it).
func override_poses(clip_name: String, length: float, loop: bool, poses: Array, joints: Array = []) -> Array:
	var result: Array = []
	for pose: Array in poses:
		var copy := pose.duplicate()  # Keeps the optional "arrive" value.
		copy[1] = (pose[1] as Dictionary).duplicate()
		result.append(copy)
	for override in pose_overrides:
		if override.clip != clip_name or (not joints.is_empty() and override.joint not in joints):
			continue
		var times: Array[float] = [override.time]
		if loop and (absf(override.time) < PoseOverride.SAME_TIME or absf(override.time - length) < PoseOverride.SAME_TIME):
			times = [0.0, length]
		for time in times:
			_set_at(result, time, override.key(), override.value)
	return result


## Sets `key` at `time` in the (sorted) pose list; a new pose first takes every key's value
## interpolated between its neighbors.
static func _set_at(poses: Array, time: float, key: String, value: Vector3) -> void:
	for pose: Array in poses:
		if absf(pose[0] - time) < PoseOverride.SAME_TIME:
			pose[1][key] = value
			return
	var keys: Dictionary[String, bool] = {key: true}
	for pose: Array in poses:
		for existing: String in pose[1]:
			keys[existing] = true
	var inserted := {}
	for existing: String in keys:
		inserted[existing] = _sample(poses, time, existing)
	inserted[key] = value
	poses.append([time, inserted])
	poses.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])


## A key's value at `time`, linear between the poses around it (zero before the first / after the last).
static func _sample(poses: Array, time: float, key: String) -> Vector3:
	var before_time := 0.0
	var before_value := Vector3.ZERO
	for pose: Array in poses:
		var value: Vector3 = pose[1].get(key, Vector3.ZERO)
		if pose[0] >= time:
			var span: float = pose[0] - before_time
			return before_value if span <= 0.0 else before_value.lerp(value, (time - before_time) / span)
		before_time = pose[0]
		before_value = value
	return before_value
