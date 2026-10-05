extends SceneTree
## Builds the hand-made low-poly models: every `scripts/tools/modeling/recipes/<name>.gd`
## (a script with `static func build() -> ModelKit`) is saved as `assets/models/<name>.tscn`.
## `godot --headless --script res://tools/build_models.gd` builds them all,
## `... -- knight warg` only those. Run `tools/fill_uid_refs.gd` after (new scenes get a UID).
## A model's hand-made polish, `assets/models/<name>.tweaks.tres` (see ModelTweaks; made in the
## model workshop), is applied on every build; tweaks whose node is gone are listed and fail the build.
## A scene that only differs by Godot's random node ids is left as it was (no diff noise).


func _init() -> void:
	var wanted := OS.get_cmdline_user_args()
	DirAccess.make_dir_recursive_absolute(ModelBuilder.OUTPUT_DIR)
	var failed := false
	for model_name in ModelBuilder.recipe_names():
		if not wanted.is_empty() and model_name not in wanted:
			continue
		var tweaks := ModelBuilder.load_tweaks(model_name) if ResourceLoader.exists(ModelBuilder.tweaks_path(model_name)) else null
		var kit := ModelBuilder.build_kit(model_name, tweaks)
		if kit == null:
			print("%s: the recipe doesn't load" % model_name)
			failed = true
			continue
		var path := ModelBuilder.scene_path(model_name)
		var error := ModelBuilder.save_scene(model_name, kit)
		print("%s %s%s" % [path, "ok" if error == OK else error_string(error), " (tweaked)" if tweaks != null else ""])
		for orphan: String in kit.orphans:
			print("  orphan tweak: %s" % orphan)
		failed = failed or error != OK or not kit.orphans.is_empty()
		kit.root.free()
	quit(1 if failed else 0)
