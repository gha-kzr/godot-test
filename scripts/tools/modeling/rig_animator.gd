class_name RigAnimator
extends RefCounted
## Turns pose lists into the animation clips of a ModelKit model. A clip is a list of poses, each
## `[time, {joint: rotation_degrees}]` or `[time, {...}, arrive]`, where `arrive` (SNAP, SETTLE or a
## number) shapes how motion gets to that pose; a joint missing from a pose is at rest (so every clip
## ends and starts clean and no joint stays stuck in the previous clip's pose). In a pose dict a
## key "Joint" is a rotation in degrees (Vector3, added to the joint's rest rotation) and
## "Joint:p" a position offset in meters (added to its rest position). All the joints any clip of
## the animator names are animated in every clip.

## How motion arrives at a pose (the optional third value of a pose): Godot's key transition,
## 1 is linear, above 1 starts slow and accelerates (a strike landing), below 1 starts fast and
## settles (a recovery, a wind-up). A clip's last rest pose settles by default.
const SNAP := 2.2
const SETTLE := 0.5

var _kit: ModelKit
var _clips: Array[Dictionary] = []


func _init(kit: ModelKit) -> void:
	_kit = kit


## Adds a clip. `loop`: the first and last poses must match (the caller gives both). `hold`:
## the clip ends in its last pose (a death); otherwise a rest pose is appended at `length`
## unless the last pose is already there. `cubic`: smooth interpolation (loops) instead of linear.
func clip(clip_name: String, length: float, poses: Array, loop := false, hold := false) -> void:
	_clips.append({"name": clip_name, "length": length, "poses": poses, "loop": loop, "hold": hold})


## Adds the AnimationPlayer with every clip to the model and returns it.
func build() -> AnimationPlayer:
	_kit.apply_tweaks()  # The rest poses are final from here on.
	_apply_pose_overrides()
	var names: Dictionary[String, bool] = {}  # "Joint" or "Joint:p" -> true
	for clip_data in _clips:
		for pose: Array in clip_data["poses"]:
			for key: String in pose[1]:
				names[key] = true
				var joint_name := key.trim_suffix(":p")
				if not _kit.joints.has(joint_name):
					push_error("RigAnimator: clip '%s' names the unknown joint '%s'" % [clip_data["name"], joint_name])
	var library := AnimationLibrary.new()
	for clip_data in _clips:
		library.add_animation(clip_data["name"], _make(clip_data, names.keys()))
	var player := AnimationPlayer.new()
	player.name = "AnimationPlayer"
	_kit.root.add_child(player)
	player.add_animation_library("", library)
	return player


## The model's pose overrides, put into the clips; an override of a clip the animator doesn't have is an orphan.
func _apply_pose_overrides() -> void:
	var tweaks := _kit.tweaks
	if tweaks == null:
		return
	var clip_names: Array = _clips.map(func(c: Dictionary) -> String: return c["name"])
	for override in tweaks.pose_overrides:
		if override.clip not in clip_names:
			_kit.orphans.append("%s@%s: %s (no such clip)" % [override.clip, override.time, override.joint])
	for clip_data in _clips:
		clip_data["poses"] = tweaks.override_poses(clip_data["name"], clip_data["length"], clip_data["loop"], clip_data["poses"], _kit.joints.keys())


func _make(clip_data: Dictionary, keys: Array) -> Animation:
	var animation := Animation.new()
	var length: float = clip_data["length"]
	animation.length = length
	animation.loop_mode = Animation.LOOP_LINEAR if clip_data["loop"] else Animation.LOOP_NONE
	var poses: Array = (clip_data["poses"] as Array).duplicate()
	if not clip_data["hold"] and not clip_data["loop"] and not is_equal_approx((poses.back() as Array)[0], length):
		poses.append([length, {}, SETTLE])
	if not is_zero_approx((poses[0] as Array)[0]):
		poses.push_front([0.0, {}])
	var interpolation := Animation.INTERPOLATION_CUBIC if clip_data["loop"] else Animation.INTERPOLATION_LINEAR
	for key: String in keys:
		var is_position := key.ends_with(":p")
		var joint := _kit.joints[key.trim_suffix(":p")]
		var track := animation.add_track(Animation.TYPE_VALUE)
		animation.track_set_path(track, NodePath("%s:%s" % [_kit.root.get_path_to(joint), "position" if is_position else "rotation"]))
		animation.track_set_interpolation_type(track, interpolation)
		animation.value_track_set_update_mode(track, Animation.UPDATE_CONTINUOUS)
		for index in poses.size():
			var pose: Array = poses[index]
			var delta: Vector3 = pose[1].get(key, Vector3.ZERO)
			var value: Vector3
			if is_position:
				value = joint.position + delta
			else:
				value = joint.rotation + delta * (PI / 180.0)
			# The key's transition shapes the segment to the next pose: that pose's "arrive" value.
			var arrive := 1.0
			if not clip_data["loop"] and index + 1 < poses.size() and (poses[index + 1] as Array).size() > 2:
				arrive = poses[index + 1][2]
			animation.track_insert_key(track, pose[0], value, arrive)
	return animation
