extends TestCase
## Hand-made polish kept next to a recipe: node tweaks, pose overrides, renames and orphans.


## A small model: Rig > Hips > (Head > Helmet, Arm.L > Sleeve).
func _kit(tweaks: ModelTweaks = null) -> ModelKit:
	ModelKit.tweaks_for_build = tweaks
	var k := ModelKit.new("Test")
	ModelKit.tweaks_for_build = null
	var rig := k.joint(null, "Rig")
	var hips := k.joint(rig, "Hips", Vector3(0, 0.4, 0))
	var head := k.joint(hips, "Head", Vector3(0, 0.5, 0))
	k.part(head, "Helmet", ModelKit.blob(Vector3(0.2, 0.2, 0.2)), Color(0.5, 0.5, 0.5), Vector3(0, 0.2, 0))
	var arm := k.joint(hips, "Arm.L", Vector3(0.3, 0.4, 0), Vector3(0, 0, 10))
	k.part(arm, "Sleeve", ModelKit.box(Vector3(0.1, 0.3, 0.1)), Color(0.2, 0.4, 0.8))
	return k


func _tweak(path: String) -> NodeTweak:
	var tweak := NodeTweak.new()
	tweak.path = path
	return tweak


func _tweaks_with(tweak: NodeTweak) -> ModelTweaks:
	var tweaks := ModelTweaks.new()
	tweaks.nodes.append(tweak)
	return tweaks


func test_a_part_tweak_moves_turns_scales_and_hides() -> void:
	var tweak := _tweak("Rig/Hips/Head/Helmet")
	tweak.position_offset = Vector3(0, 0.05, 0.1)
	tweak.rotation_offset = Vector3(10, 0, 0)
	tweak.scale_factor = Vector3(1.2, 1.0, 1.0)
	var kit := _kit(_tweaks_with(tweak))
	kit.apply_tweaks()
	var helmet := kit.root.get_node("Rig/Hips/Head/Helmet") as MeshInstance3D
	assert_eq(helmet.position, Vector3(0, 0.25, 0.1))
	assert_eq(snappedf(helmet.rotation_degrees.x, 0.001), 10.0)
	assert_eq(helmet.scale, Vector3(1.2, 1.0, 1.0))
	assert_true(helmet.visible)
	tweak.hidden = true
	var other := _kit(_tweaks_with(tweak))
	other.apply_tweaks()
	assert_false((other.root.get_node("Rig/Hips/Head/Helmet") as Node3D).visible)
	kit.root.free()
	other.root.free()


func test_a_recolor_swaps_the_material_and_keeps_the_emissive_unless_set() -> void:
	var tweak := _tweak("Rig/Hips/Head/Helmet")
	tweak.recolor = true
	tweak.color = Color(1, 0, 0)
	var kit := _kit(_tweaks_with(tweak))
	kit.apply_tweaks()
	var helmet := kit.root.get_node("Rig/Hips/Head/Helmet") as MeshInstance3D
	var expected := Color(ModelKit.ALBEDO_FACTOR, 0, 0)
	assert_eq((helmet.material_override as StandardMaterial3D).albedo_color.r, expected.r)
	assert_eq(kit.look_of(helmet)["color"], Color(1, 0, 0))
	var glow := _tweak("Rig/Hips/Head/Helmet")
	glow.emissive = 0.5
	var lit := _kit(_tweaks_with(glow))
	lit.apply_tweaks()
	var material := (lit.root.get_node("Rig/Hips/Head/Helmet") as MeshInstance3D).material_override as StandardMaterial3D
	assert_true(material.emission_enabled, "a glow")
	assert_eq(lit.look_of(lit.root.get_node("Rig/Hips/Head/Helmet") as MeshInstance3D)["color"], Color(0.5, 0.5, 0.5), "the color stays")
	kit.root.free()
	lit.root.free()


func test_tweaks_apply_once() -> void:
	var tweak := _tweak("Rig/Hips/Head")
	tweak.position_offset = Vector3(0, 0.1, 0)
	var kit := _kit(_tweaks_with(tweak))
	kit.apply_tweaks()
	kit.apply_tweaks()
	assert_eq(kit.joints["Head"].position, Vector3(0, 0.6, 0))
	kit.root.free()


func test_a_missing_node_is_an_orphan_kept_in_the_file_and_a_rename_finds_it() -> void:
	var tweak := _tweak("Rig/Hips/Head/Hat")
	tweak.position_offset = Vector3(0, 0.1, 0)
	var tweaks := _tweaks_with(tweak)
	var kit := _kit(tweaks)
	kit.apply_tweaks()
	assert_eq(kit.orphans, PackedStringArray(["Rig/Hips/Head/Hat"]))
	assert_eq(tweaks.nodes.size(), 1, "kept")
	tweaks.renames["Rig/Hips/Head/Hat"] = "Rig/Hips/Head/Helmet"
	var renamed := _kit(tweaks)
	renamed.apply_tweaks()
	assert_true(renamed.orphans.is_empty())
	assert_eq((renamed.root.get_node("Rig/Hips/Head/Helmet") as Node3D).position, Vector3(0, 0.3, 0))
	kit.root.free()
	renamed.root.free()


func _animation(kit: ModelKit, tweaks_clip := "Swing") -> Animation:
	var animator := RigAnimator.new(kit)
	animator.clip("Swing", 1.0, [[0.0, {}], [0.5, {"Arm.L": Vector3(-90, 0, 0)}], [1.0, {}]])
	var player := animator.build()
	return player.get_animation(tweaks_clip)


func _arm_values(animation: Animation) -> Array:
	var track := animation.find_track(NodePath("Rig/Hips/Arm_L:rotation"), Animation.TYPE_VALUE)
	var values: Array = []
	for key in animation.track_get_key_count(track):
		values.append([animation.track_get_key_time(track, key), animation.track_get_key_value(track, key)])
	return values


func test_a_joint_rest_tweak_carries_the_clips() -> void:
	var tweak := _tweak("Rig/Hips/Arm_L")
	tweak.rotation_offset = Vector3(0, 0, 5)
	var kit := _kit(_tweaks_with(tweak))
	var values := _arm_values(_animation(kit))
	assert_eq(snappedf(rad_to_deg((values[0][1] as Vector3).z), 0.01), 15.0, "rest 10 + 5")
	assert_eq(snappedf(rad_to_deg((values[1][1] as Vector3).z), 0.01), 15.0, "mid key keeps it")
	assert_eq(snappedf(rad_to_deg((values[1][1] as Vector3).x), 0.01), -90.0)
	kit.root.free()


func test_a_pose_override_replaces_a_value_at_an_existing_time() -> void:
	var tweaks := ModelTweaks.new()
	var override := PoseOverride.new()
	override.clip = "Swing"
	override.time = 0.5
	override.joint = "Arm.L"
	override.value = Vector3(-120, 0, 0)
	tweaks.pose_overrides.append(override)
	var kit := _kit(tweaks)
	var values := _arm_values(_animation(kit))
	assert_eq(values.size(), 3, "no new pose")
	assert_eq(snappedf(rad_to_deg((values[1][1] as Vector3).x), 0.01), -120.0)
	kit.root.free()


func test_a_pose_override_at_a_new_time_keeps_the_other_joints_where_the_clip_has_them() -> void:
	var poses := [[0.0, {"Head": Vector3(0, 0, 0)}], [1.0, {"Head": Vector3(40, 0, 0)}]]
	var tweaks := ModelTweaks.new()
	var override := PoseOverride.new()
	override.clip = "Nod"
	override.time = 0.5
	override.joint = "Arm.L"
	override.value = Vector3(-30, 0, 0)
	tweaks.pose_overrides.append(override)
	var result := tweaks.override_poses("Nod", 1.0, false, poses)
	assert_eq(result.size(), 3)
	assert_eq(result[1][0], 0.5)
	assert_eq(result[1][1]["Head"], Vector3(20, 0, 0), "interpolated")
	assert_eq(result[1][1]["Arm.L"], Vector3(-30, 0, 0))
	assert_eq(poses.size(), 2, "the input is untouched")


func test_a_loop_override_at_the_start_applies_to_the_end_too() -> void:
	var poses := [[0.0, {}], [0.5, {"Head": Vector3(10, 0, 0)}], [1.0, {}]]
	var tweaks := ModelTweaks.new()
	var override := PoseOverride.new()
	override.clip = "Idle"
	override.time = 0.0
	override.joint = "Head"
	override.value = Vector3(3, 0, 0)
	tweaks.pose_overrides.append(override)
	var result := tweaks.override_poses("Idle", 1.0, true, poses)
	assert_eq(result[0][1]["Head"], Vector3(3, 0, 0))
	assert_eq(result[2][1]["Head"], Vector3(3, 0, 0), "the loop still closes")


func test_overrides_for_a_missing_joint_or_clip_are_orphans() -> void:
	var tweaks := ModelTweaks.new()
	for pair in [["Swing", "Tail"], ["Dance", "Head"]]:
		var override := PoseOverride.new()
		override.clip = pair[0]
		override.joint = pair[1]
		tweaks.pose_overrides.append(override)
	var kit := _kit(tweaks)
	_animation(kit)
	assert_eq(kit.orphans.size(), 2)
	kit.root.free()


func test_every_committed_tweaks_file_still_fits_its_recipe() -> void:
	assert_true(DirAccess.dir_exists_absolute("res://assets/models"))
	for file in DirAccess.get_files_at("res://assets/models"):
		if not file.ends_with(".tweaks.tres"):
			continue
		var model_name := file.trim_suffix(".tweaks.tres")
		var tweaks := load("res://assets/models/" + file) as ModelTweaks
		assert_true(tweaks != null, "%s loads" % file)
		var recipe := load("res://scripts/tools/modeling/recipes/%s.gd" % model_name) as GDScript
		assert_true(recipe != null, "%s has a recipe" % file)
		if tweaks == null or recipe == null:
			continue
		ModelKit.tweaks_for_build = tweaks
		var kit: ModelKit = recipe.call("build")
		ModelKit.tweaks_for_build = null
		kit.apply_tweaks()
		assert_eq(kit.orphans, PackedStringArray(), "%s: tweaks without a node" % file)
		kit.root.free()
