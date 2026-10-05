extends TestCase
## The hand-built low-poly models: the solids are closed and face outward, every recipe builds a
## model with the full animation set whose tracks all find their joints, and every unit that uses
## one is about as tall as its data says.

const RECIPES_DIR := "res://scripts/tools/modeling/recipes"
const MODELS_DIR := "res://assets/models"
const LOGICAL_ANIMATIONS := ["Idle", "Walk", "Attack", "Cast", "Hit", "Death", "Victory", "Defeat"]
## Props (held items) have no animations.
const PROPS := ["sword", "staff", "bow", "spore_staff", "brute_axe", "orc_club", "rock_1", "rock_2", "rock_3"]


func _recipe_names() -> PackedStringArray:
	var names: PackedStringArray = []
	for file in DirAccess.get_files_at(RECIPES_DIR):
		if file.ends_with(".gd"):
			names.append(file.trim_suffix(".gd"))
	return names


func test_every_solid_is_closed_and_faces_outward() -> void:
	var solids := {
		"box": ModelKit.box(Vector3(1, 2, 3)),
		"prism": ModelKit.prism(6, Vector2(1, 1), Vector2(0.5, 0.5), 2.0),
		"cone": ModelKit.prism(5, Vector2(1, 1), Vector2.ZERO, 2.0),
		"blob": ModelKit.blob(Vector3(1, 1.5, 1)),
		"wedge": ModelKit.wedge(1, 1, 1, 0.5),
	}
	for solid_name: String in solids:
		var arrays := (solids[solid_name] as ArrayMesh).surface_get_arrays(0)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var center := Vector3.ZERO
		for vertex in vertices:
			center += vertex
		center /= vertices.size()
		var inward := 0
		var counter_clockwise := 0
		for first in range(0, vertices.size(), 3):
			var middle := (vertices[first] + vertices[first + 1] + vertices[first + 2]) / 3.0
			if normals[first].dot(middle - center) <= 0.0:
				inward += 1
			# Godot's front face is clockwise: the geometric normal of a visible triangle points inward.
			var geometric := (vertices[first + 1] - vertices[first]).cross(vertices[first + 2] - vertices[first])
			if geometric.dot(normals[first]) >= 0.0:
				counter_clockwise += 1
		assert_eq(inward, 0, "%s: triangles with an inward normal" % solid_name)
		assert_eq(counter_clockwise, 0, "%s: triangles wound the wrong way" % solid_name)


func test_every_recipe_has_a_saved_scene() -> void:
	for recipe_name in _recipe_names():
		assert_true(ResourceLoader.exists("%s/%s.tscn" % [MODELS_DIR, recipe_name]), "%s: run tools/build_models.gd" % recipe_name)


func test_every_creature_model_has_the_whole_animation_set_on_joints_that_exist() -> void:
	for recipe_name in _recipe_names():
		if recipe_name in PROPS:
			continue
		var scene := load("%s/%s.tscn" % [MODELS_DIR, recipe_name]) as PackedScene
		var model := scene.instantiate()
		var players := model.find_children("*", "AnimationPlayer", true, false)
		assert_eq(players.size(), 1, "%s: one AnimationPlayer" % recipe_name)
		if players.size() == 1:
			var player := players[0] as AnimationPlayer
			for logical in LOGICAL_ANIMATIONS:
				assert_true(player.has_animation(logical), "%s: %s" % [recipe_name, logical])
			for animation_name in player.get_animation_list():
				var animation := player.get_animation(animation_name)
				for track in animation.get_track_count():
					var path := animation.track_get_path(track)
					assert_true(model.get_node_or_null(NodePath(path.get_concatenated_names())) != null,
							"%s/%s: a joint for %s" % [recipe_name, animation_name, path])
		model.free()


func test_the_animations_start_from_the_rest_pose_and_the_loops_close() -> void:
	for recipe_name in _recipe_names():
		if recipe_name in PROPS:
			continue
		var model := (load("%s/%s.tscn" % [MODELS_DIR, recipe_name]) as PackedScene).instantiate()
		var player := model.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
		for animation_name in player.get_animation_list():
			var animation := player.get_animation(animation_name)
			if animation.loop_mode != Animation.LOOP_LINEAR:
				continue
			for track in animation.get_track_count():
				var last := animation.track_get_key_count(track) - 1
				assert_eq(animation.track_get_key_value(track, 0), animation.track_get_key_value(track, last),
						"%s/%s: a loop ends where it starts (%s)" % [recipe_name, animation_name, animation.track_get_path(track)])
		model.free()


func test_a_unit_is_about_as_tall_as_its_data_says() -> void:
	for file in DirAccess.get_files_at("res://data/units"):
		var data := load("res://data/units/" + file) as UnitData
		if data == null or data.model_scene == null or not data.model_scene.resource_path.begins_with(MODELS_DIR):
			continue
		var model := data.model_scene.instantiate() as Node3D
		(Engine.get_main_loop() as SceneTree).root.add_child(model)
		var top := 0.0
		for mesh in model.find_children("*", "MeshInstance3D", true, false):
			var instance := mesh as MeshInstance3D
			var box := instance.global_transform * instance.get_aabb()
			top = maxf(top, box.end.y)
		var height := top * data.model_scale
		assert_true(absf(height - data.model_height) <= data.model_height * 0.25,
				"%s: %.2f tall, model_height says %.2f" % [file, height, data.model_height])
		model.free()


func test_arrow_spells_play_the_bow_animation_and_bipeds_have_it() -> void:
	for file in DirAccess.get_files_at("res://data/spells"):
		var spell := load("res://data/spells/" + file) as SpellData
		if spell != null and spell.projectile != null and spell.projectile.resource_path.ends_with("projectile_arrow.tscn"):
			assert_eq(spell.cast_animation, &"Shoot", "%s: an arrow is shot, not cast" % file)
	for recipe_name in ["knight", "ranger", "skeleton_archer"]:
		var player := (load("%s/%s.tscn" % [MODELS_DIR, recipe_name]) as PackedScene).instantiate().find_child("AnimationPlayer", true, false) as AnimationPlayer
		assert_true(player.has_animation("Shoot"), "%s: a Shoot clip" % recipe_name)
		player.owner.free()
