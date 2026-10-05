extends TestCase
## The model workshop's rules (no UI): editing a draft, undo, pose overrides, orphans, saving.

const DIR := "user://test_workshop"


func _session() -> WorkshopSession:
	DirAccess.make_dir_recursive_absolute(DIR)
	ModelBuilder.output_dir = DIR
	var session := WorkshopSession.new()
	assert_true(session.open("knight"), "the recipe loads")
	return session


func after_each_clean() -> void:
	ModelBuilder.output_dir = ModelBuilder.OUTPUT_DIR
	for file in DirAccess.get_files_at(DIR):
		DirAccess.remove_absolute("%s/%s" % [DIR, file])
	DirAccess.remove_absolute(DIR)


func _close(session: WorkshopSession) -> void:
	session.kit.root.free()


func test_an_edit_shows_in_the_rebuilt_model_and_undo_takes_it_back() -> void:
	var session := _session()
	var path := "Rig/Hips/Head/Plume"
	var before := (session.kit.root.get_node(path) as Node3D).position
	var rebuilds := {"count": 0}
	session.rebuilt.connect(func() -> void: rebuilds.count += 1)
	session.set_node_field(path, "position_offset", Vector3(0, 0.1, 0))
	assert_eq(rebuilds.count, 1)
	assert_eq((session.kit.root.get_node(path) as Node3D).position, before + Vector3(0, 0.1, 0))
	assert_true(session.dirty)
	assert_true(session.can_undo())
	session.undo()
	assert_eq((session.kit.root.get_node(path) as Node3D).position, before)
	assert_true(session.can_redo())
	session.redo()
	assert_eq((session.kit.root.get_node(path) as Node3D).position, before + Vector3(0, 0.1, 0))
	_close(session)


func test_a_slider_drag_is_one_undo_step() -> void:
	var session := _session()
	var path := "Rig/Hips/Head/Plume"
	session.remember()
	for step in 5:
		session.set_node_field(path, "scale_factor", Vector3.ONE * (1.0 + step * 0.1), false)
	session.undo()
	assert_false(session.can_undo())
	assert_true(session.node_tweak(path) == null or session.node_tweak(path).scale_factor == Vector3.ONE)
	_close(session)


func test_show_original_builds_without_the_tweaks() -> void:
	var session := _session()
	var path := "Rig/Hips/Head/Plume"
	var before := (session.kit.root.get_node(path) as Node3D).position
	session.set_node_field(path, "position_offset", Vector3(0, 0.1, 0))
	session.show_original = true
	assert_eq((session.kit.root.get_node(path) as Node3D).position, before)
	session.show_original = false
	assert_eq((session.kit.root.get_node(path) as Node3D).position, before + Vector3(0, 0.1, 0))
	_close(session)


func test_reset_drops_a_nodes_tweak() -> void:
	var session := _session()
	var path := "Rig/Hips/Head/Plume"
	session.set_node_field(path, "hidden", true)
	assert_false((session.kit.root.get_node(path) as Node3D).visible)
	session.reset_node(path)
	assert_true((session.kit.root.get_node(path) as Node3D).visible)
	assert_true(session.node_tweak(path) == null)
	_close(session)


func test_a_pose_override_changes_the_clip_and_can_be_removed() -> void:
	var session := _session()
	var player := session.kit.root.get_node("AnimationPlayer") as AnimationPlayer
	var animation := player.get_animation("Attack")
	var track := animation.find_track(NodePath("Rig/Hips/Arm_R:rotation"), Animation.TYPE_VALUE)
	var time := animation.track_get_key_time(track, 1)
	session.set_pose("Attack", time, "Arm.R", false, Vector3(-100, 0, 0))
	assert_eq(session.overrides_of("Attack").size(), 1)
	animation = (session.kit.root.get_node("AnimationPlayer") as AnimationPlayer).get_animation("Attack")
	var value: Vector3 = animation.track_get_key_value(animation.find_track(NodePath("Rig/Hips/Arm_R:rotation"), Animation.TYPE_VALUE), 1)
	var rest_x := rad_to_deg((session.rests["Arm.R"]["rotation"] as Vector3).x)
	assert_eq(snappedf(rad_to_deg(value.x) - rest_x, 0.01), -100.0, "rest + the override")
	session.set_pose("Attack", time, "Arm.R", false, Vector3(-90, 0, 0))
	assert_eq(session.overrides_of("Attack").size(), 1, "the same moment updates")
	session.remove_pose("Attack", time, "Arm.R", false)
	assert_true(session.overrides_of("Attack").is_empty())
	_close(session)


func test_an_orphan_can_be_mapped_to_a_node_that_exists() -> void:
	var session := _session()
	session.set_node_field("Rig/Hips/Head/Feather", "hidden", true)
	assert_eq(session.orphans(), PackedStringArray(["Rig/Hips/Head/Feather"]))
	session.map_orphan("Rig/Hips/Head/Feather", "Rig/Hips/Head/Plume")
	assert_true(session.orphans().is_empty())
	assert_false((session.kit.root.get_node("Rig/Hips/Head/Plume") as Node3D).visible)
	_close(session)


func test_saving_writes_the_tweaks_and_the_scene_and_reopening_finds_them() -> void:
	var session := _session()
	var path := "Rig/Hips/Head/Plume"
	session.set_node_field(path, "position_offset", Vector3(0, 0.1, 0))
	assert_eq(session.save(), OK)
	assert_false(session.dirty)
	assert_true(FileAccess.file_exists("%s/knight.tweaks.tres" % DIR))
	assert_true(FileAccess.file_exists("%s/knight.tscn" % DIR))
	var plain := ModelBuilder.build_kit("knight", null)
	var base := (plain.root.get_node(path) as Node3D).position
	plain.root.free()
	var reopened := WorkshopSession.new()
	assert_true(reopened.open("knight"))
	assert_eq((reopened.kit.root.get_node(path) as Node3D).position, base + Vector3(0, 0.1, 0))
	reopened.reset_node(path)
	assert_eq(reopened.save(), OK)
	assert_false(FileAccess.file_exists("%s/knight.tweaks.tres" % DIR), "no tweaks left, no file")
	_close(session)
	_close(reopened)
