extends SceneTree
## Builds the hand-made low-poly models: every `scripts/tools/modeling/recipes/<name>.gd`
## (a script with `static func build() -> ModelKit`) is saved as `assets/models/<name>.tscn`.
## `godot --headless --script res://tools/build_models.gd` builds them all,
## `... -- knight warg` only those. Run `tools/fill_uid_refs.gd` after (new scenes get a UID).

const RECIPES_DIR := "res://scripts/tools/modeling/recipes"
const OUTPUT_DIR := "res://assets/models"


func _init() -> void:
	var wanted := OS.get_cmdline_user_args()
	DirAccess.make_dir_recursive_absolute(OUTPUT_DIR)
	var failed := false
	var names: PackedStringArray = []
	for file in DirAccess.get_files_at(RECIPES_DIR):
		if file.ends_with(".gd"):
			names.append(file.trim_suffix(".gd"))
	names.sort()
	for model_name in names:
		if not wanted.is_empty() and model_name not in wanted:
			continue
		var recipe := load("%s/%s.gd" % [RECIPES_DIR, model_name]) as GDScript
		if recipe == null or not recipe.can_instantiate():
			print("%s: the recipe doesn't load" % model_name)
			failed = true
			continue
		var kit = recipe.call("build")
		kit.root.name = model_name.to_pascal_case()
		var path := "%s/%s.tscn" % [OUTPUT_DIR, model_name]
		var error: Error = kit.save(path)
		print("%s %s" % [path, "ok" if error == OK else error_string(error)])
		failed = failed or error != OK
		kit.root.free()
	quit(1 if failed else 0)
