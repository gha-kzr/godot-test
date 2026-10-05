extends TestCase
## The workshop screen on top of the session: selecting a node builds its inspector, a slider edit
## lands in the draft, undo brings it back, a joint at a time of a clip can be given a pose.

const DIR := "user://test_workshop_scene"


func _workshop() -> ModelWorkshop:
	DirAccess.make_dir_recursive_absolute(DIR)
	ModelBuilder.output_dir = DIR
	var workshop := (load("res://scenes/tools/model_workshop.tscn") as PackedScene).instantiate() as ModelWorkshop
	(Engine.get_main_loop() as SceneTree).root.add_child(workshop)
	return workshop


func after_each_clean() -> void:
	ModelBuilder.output_dir = ModelBuilder.OUTPUT_DIR
	DirAccess.remove_absolute(DIR)


func _sliders(box: Node) -> Array[HSlider]:
	var found: Array[HSlider] = []
	for node in box.find_children("*", "HSlider", true, false):
		found.append(node as HSlider)
	return found


func test_selecting_a_part_builds_its_inspector_and_a_slider_edits_the_draft() -> void:
	var workshop := _workshop()
	workshop._open("knight")
	workshop._items["Rig/Hips/Head/Plume"].select(0)
	assert_eq(workshop._selected, "Rig/Hips/Head/Plume")
	var sliders := _sliders(workshop._node_box)
	assert_true(sliders.size() >= 10, "move, turn and scale rows")
	var before: float = workshop.session.kit.root.get_node("Rig/Hips/Head/Plume").position.y
	sliders[1].value = 0.1  # Move Y.
	assert_eq(snappedf(workshop.session.kit.root.get_node("Rig/Hips/Head/Plume").position.y - before, 0.001), 0.1)
	assert_true(workshop.session.dirty)
	workshop.session.undo()
	assert_eq(workshop.session.kit.root.get_node("Rig/Hips/Head/Plume").position.y, before)
	workshop.free()


func test_a_joint_at_a_clip_time_can_be_given_a_pose() -> void:
	var workshop := _workshop()
	workshop._open("knight")
	for index in workshop._clip_picker.item_count:
		if workshop._clip_picker.get_item_text(index) == "Attack":
			workshop._clip_picker.item_selected.emit(index)
	var clip: String = workshop._clip
	assert_eq(clip, "Attack")
	workshop._time = 0.2
	workshop._show_time()
	workshop._items["Rig/Hips/Arm_R"].select(0)
	var sliders := _sliders(workshop._pose_box)
	assert_eq(sliders.size(), 6, "rotation and position of the joint")
	sliders[0].value = 55.0
	var overrides := workshop.session.overrides_of(clip)
	assert_eq(overrides.size(), 1)
	assert_eq(overrides[0].joint, "Arm.R")
	assert_eq(overrides[0].value.x, 55.0)
	assert_eq(workshop._override_list.item_count, 0, "the list refreshes on the next pick, not during the drag")
	workshop.free()


func test_the_recipe_list_and_the_clips_are_offered() -> void:
	var workshop := _workshop()
	workshop._open("warg")
	assert_true(workshop._model_picker.item_count >= 10)
	var clips: Array[String] = []
	for index in workshop._clip_picker.item_count:
		clips.append(workshop._clip_picker.get_item_text(index))
	assert_true(clips.has("Attack") and clips.has("Idle"))
	workshop.free()
