extends TestCase
## UnitModel: one animation contract over any pack's model, skin colors, hit flash.

const KNIGHT := preload("res://assets/quaternius/characters/Knight_Male.fbx")
const BARREL := preload("res://assets/quaternius/dungeon/Barrel.fbx")


func _model(scene: PackedScene = KNIGHT, skin := Color(0, 0, 0, 0)) -> UnitModel:
	var model := UnitModel.new()
	(Engine.get_main_loop() as SceneTree).root.add_child(model)
	model.setup(scene, 0.5, skin)
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


func test_the_packs_animations_resolve_from_logical_names() -> void:
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


func test_a_model_without_animations_is_fine() -> void:
	var model := _model(BARREL)
	assert_false(model.has_animation(&"Idle"))
	assert_eq(model.play(&"Idle"), 0.0)
	model.free()


func test_idle_and_walk_loop_but_actions_do_not() -> void:
	var model := _model()
	var player := model.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	assert_eq(player.get_animation("CharacterArmature|Idle").loop_mode, Animation.LOOP_LINEAR)
	assert_eq(player.get_animation("CharacterArmature|Walk").loop_mode, Animation.LOOP_LINEAR)
	assert_eq(player.get_animation("CharacterArmature|Death").loop_mode, Animation.LOOP_NONE)
	assert_eq(player.current_animation, "CharacterArmature|Idle", "starts idle")
	model.free()


func _skin_albedo(model: UnitModel) -> Color:
	for mesh in model.find_children("*", "MeshInstance3D", true, false):
		var instance := mesh as MeshInstance3D
		for surface in instance.mesh.get_surface_count():
			var material := instance.mesh.surface_get_material(surface) as BaseMaterial3D
			if material != null and material.resource_name == "Skin":
				return material.albedo_color
	return Color(-1, -1, -1)


func test_skin_color_is_set_per_model_without_touching_the_shared_material() -> void:
	var tan := Color(0.95, 0.78, 0.64)
	var colored := _model(KNIGHT, tan)
	var plain := _model()
	assert_eq(_skin_albedo(colored), tan)
	assert_ne(_skin_albedo(plain), tan, "another instance of the same model keeps the pack's skin")
	colored.free()
	plain.free()


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
	assert_eq(player.current_animation, "CharacterArmature|Idle", "standing again")
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
		if player.current_animation.ends_with("|Idle"):
			break
		await (Engine.get_main_loop() as SceneTree).process_frame
	assert_true(player.current_animation.ends_with("|Idle"), "an action ends back at Idle: %s" % player.current_animation)
	model.play(&"Death")
	for i in 600:
		if not player.is_playing():
			break
		await (Engine.get_main_loop() as SceneTree).process_frame
	assert_true(player.assigned_animation.ends_with("|Death"), "but a death stays: %s" % player.assigned_animation)
	model.free()


func test_a_mangled_export_resolves_through_any_part_between_bars() -> void:
	var model := _model(_scene_with_animations(["Arm|Arm|Arm|Idle|Arm|Idle", "Arm|Arm|Arm|Death|Arm|Dea", "Arm|Arm|Arm|Jump_Idle|Arm"] as Array[String]))
	assert_true(model.has_animation(&"Idle"), "Idle in the middle")
	assert_true(model.has_animation(&"Death"), "a truncated tail")
	model.free()


func test_the_monsters_have_the_animations_the_game_needs() -> void:
	for path in ["res://assets/quaternius/monsters/Skeleton.glb", "res://assets/quaternius/monsters/Zombie.glb", "res://assets/quaternius/monsters/Ghost.glb"]:
		var model := _model(load(path) as PackedScene)
		for logical: StringName in [&"Idle", &"Walk", &"Attack", &"Cast", &"Hit", &"Death"]:
			assert_true(model.has_animation(logical), "%s: %s" % [path.get_file(), logical])
		model.free()
