extends TestCase
## UnitModel: one animation contract over any model, held items, hit flash.

const KNIGHT := preload("res://assets/models/knight.tscn")
const BARREL := preload("res://assets/models/rock_1.tscn")


func _model(scene: PackedScene = KNIGHT) -> UnitModel:
	var model := UnitModel.new()
	(Engine.get_main_loop() as SceneTree).root.add_child(model)
	model.setup(scene, 1.0)
	return model


## A scene with an AnimationPlayer holding `names`, as another pack might name them.
func _scene_with_animations(names: Array[String]) -> PackedScene:
	var root := Node3D.new()
	var player := AnimationPlayer.new()
	player.name = "AnimationPlayer"
	var library := AnimationLibrary.new()
	for animation_name in names:
		var animation := Animation.new()
		animation.length = 0.5
		library.add_animation(animation_name, animation)
	player.add_animation_library("", library)
	root.add_child(player)
	player.owner = root
	var scene := PackedScene.new()
	scene.pack(root)
	root.free()
	return scene


func test_a_models_animations_resolve_from_logical_names() -> void:
	var model := _model()
	for logical: StringName in [&"Idle", &"Walk", &"Attack", &"Cast", &"Hit", &"Death", &"Victory", &"Defeat"]:
		assert_true(model.has_animation(logical), "%s found" % logical)
	assert_true(model.play(&"Attack") > 0.0, "play returns the animation's length")
	model.free()


func test_another_packs_names_work_through_the_suffix_after_a_bar() -> void:
	var model := _model(_scene_with_animations(["Rig|Idle", "Rig|Run", "Hit"] as Array[String]))
	assert_true(model.has_animation(&"Idle"), "Rig|Idle")
	assert_true(model.has_animation(&"Walk"), "falls back to Run when there is no Walk")
	assert_true(model.has_animation(&"Hit"), "an exact name")
	assert_false(model.has_animation(&"Death"), "a missing animation is simply absent")
	assert_eq(model.play(&"Death"), 0.0, "and playing it does nothing")
	model.free()


func test_shoot_falls_back_to_cast_then_attack() -> void:
	var with_cast := _model(_scene_with_animations(["Idle", "Cast", "Attack"] as Array[String]))
	assert_true(with_cast.has_animation(&"Shoot"), "a model without a Shoot clip casts")
	with_cast.free()
	var attack_only := _model(_scene_with_animations(["Idle", "Attack"] as Array[String]))
	assert_true(attack_only.has_animation(&"Shoot"), "or attacks")
	attack_only.free()
	var own := _model(_scene_with_animations(["Idle", "Shoot", "Cast"] as Array[String]))
	assert_true(own.play(&"Shoot") > 0.0)
	own.free()


func test_a_model_without_animations_is_fine() -> void:
	var model := _model(BARREL)
	assert_false(model.has_animation(&"Idle"))
	assert_eq(model.play(&"Idle"), 0.0)
	model.free()


func test_idle_and_walk_loop_but_actions_do_not() -> void:
	var model := _model()
	var player := model.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	assert_eq(player.get_animation("Idle").loop_mode, Animation.LOOP_LINEAR)
	assert_eq(player.get_animation("Walk").loop_mode, Animation.LOOP_LINEAR)
	assert_eq(player.get_animation("Death").loop_mode, Animation.LOOP_NONE)
	assert_eq(player.current_animation, "Idle", "starts idle")
	model.free()


func test_flash_overlays_the_model_then_clears() -> void:
	Engine.time_scale = 20.0
	var model := _model()
	model.flash(Color.RED, 0.05)
	var mesh := model.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
	assert_true(mesh.material_overlay != null, "flashing")
	for i in 120:
		if mesh.material_overlay == null:
			break
		await (Engine.get_main_loop() as SceneTree).process_frame
	assert_true(mesh.material_overlay == null, "back to normal")
	model.free()


func test_reset_clears_the_flash_and_the_held_pose() -> void:
	var model := _model()
	model.play(&"Death")
	model.flash(Color.RED, 5.0)
	var mesh := model.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
	assert_true(mesh.material_overlay != null)
	model.reset()
	var player := model.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	assert_true(mesh.material_overlay == null, "no flash left")
	assert_eq(player.current_animation, "Idle", "standing again")
	model.free()


func test_an_action_animation_restarts_when_asked_again_and_returns_to_idle_by_itself() -> void:
	Engine.time_scale = 10.0
	var model := _model()
	var player := model.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	model.play(&"Attack")
	player.seek(0.5, true)  # Halfway through the slash.
	assert_true(player.is_playing() and player.current_animation_position > 0.4, "the slash is under way")
	model.play(&"Attack")  # A second cast, quickly.
	assert_true(player.current_animation_position < 0.2, "playing it again restarts it instead of being ignored: %f" % player.current_animation_position)
	for i in 600:
		if player.current_animation == "Idle":
			break
		await (Engine.get_main_loop() as SceneTree).process_frame
	assert_true(player.current_animation == "Idle", "an action ends back at Idle: %s" % player.current_animation)
	model.play(&"Death")
	for i in 600:
		if not player.is_playing():
			break
		await (Engine.get_main_loop() as SceneTree).process_frame
	assert_true(player.assigned_animation == "Death", "but a death stays: %s" % player.assigned_animation)
	model.free()


func test_a_mangled_export_resolves_through_any_part_between_bars() -> void:
	var model := _model(_scene_with_animations(["Arm|Arm|Arm|Idle|Arm|Idle", "Arm|Arm|Arm|Death|Arm|Dea", "Arm|Arm|Arm|Jump_Idle|Arm"] as Array[String]))
	assert_true(model.has_animation(&"Idle"), "Idle in the middle")
	assert_true(model.has_animation(&"Death"), "a truncated tail")
	model.free()


func test_every_unit_model_has_the_animations_the_game_needs() -> void:
	for file in DirAccess.get_files_at("res://data/units"):
		var data := load("res://data/units/" + file) as UnitData
		if data == null or data.model_scene == null:
			continue
		var model := _model(data.model_scene)
		for logical: StringName in [&"Idle", &"Walk", &"Attack", &"Cast", &"Hit", &"Death", &"Victory", &"Defeat"]:
			assert_true(model.has_animation(logical), "%s: %s" % [file, logical])
		model.free()


func test_a_held_item_replaces_a_part_of_the_model() -> void:
	var knight := load("res://data/units/knight.tres") as UnitData
	var model := _model(knight.model_scene)
	model.hold(knight.held_item, "Shield", 1.0, Vector3.ZERO)
	assert_false((model.find_child("Shield", true, false) as Node3D).visible, "the shield is hidden")
	var held := model.find_child("HeldItem", true, false) as Node3D
	assert_true(held != null, "the item is held")
	assert_eq(held.get_parent(), model.find_child("Shield", true, false).get_parent(), "on the same joint")
	model.free()


func test_holding_in_place_of_a_missing_part_is_reported() -> void:
	var model := _model()
	expect_error("no part named")
	model.hold(load("res://assets/models/bow.tscn"), "NoSuchPart", 1.0, Vector3.ZERO)
	assert_true(model.find_child("HeldItem", true, false) == null)
	model.free()


func test_a_held_item_can_hang_from_a_joint() -> void:
	var hero := load("res://data/units/knight.tres") as UnitData
	var model := _model(hero.model_scene)
	model.hold(hero.held_item, "", hero.held_item_scale, hero.held_item_rotation, hero.held_item_bone)
	var held := model.find_child("HeldItem", true, false) as Node3D
	assert_true(held != null, "the sword is held")
	assert_eq(held.get_parent().name, hero.held_item_bone.validate_node_name(), "it hangs from the joint")
	expect_error("no joint named")
	model.hold(hero.held_item, "", 1.0, Vector3.ZERO, "NoSuchJoint")
	model.free()


func test_every_hero_holds_its_weapon() -> void:
	for hero in ["knight", "mage", "ranger"]:
		var data := load("res://data/units/%s.tres" % hero) as UnitData
		assert_true(data.held_item != null, "%s holds something" % hero)
		var model := _model(data.model_scene)
		model.hold(data.held_item, data.held_item_replaces, data.held_item_scale, data.held_item_rotation, data.held_item_bone, data.held_item_offset)
		assert_true(model.find_child("HeldItem", true, false) != null, hero)
		model.free()
