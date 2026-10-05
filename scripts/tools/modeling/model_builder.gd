class_name ModelBuilder
extends RefCounted
## Builds a model from its recipe with its tweaks file and saves it as a scene: the code shared
## by `tools/build_models.gd` and the model workshop.

const RECIPES_DIR := "res://scripts/tools/modeling/recipes"
const OUTPUT_DIR := "res://assets/models"

## Where scenes and tweaks files go (tests point it elsewhere).
static var output_dir := OUTPUT_DIR


static func recipe_names() -> PackedStringArray:
	var names: PackedStringArray = []
	for file in DirAccess.get_files_at(RECIPES_DIR):
		if file.ends_with(".gd"):
			names.append(file.trim_suffix(".gd"))
	names.sort()
	return names


static func recipe_path(model_name: String) -> String:
	return "%s/%s.gd" % [RECIPES_DIR, model_name]


static func scene_path(model_name: String) -> String:
	return "%s/%s.tscn" % [output_dir, model_name]


static func tweaks_path(model_name: String) -> String:
	return "%s/%s.tweaks.tres" % [output_dir, model_name]


## The model's tweaks file (a copy: editing it doesn't touch the cached resource), or an empty one.
static func load_tweaks(model_name: String) -> ModelTweaks:
	var path := tweaks_path(model_name)
	var loaded := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE) as ModelTweaks if ResourceLoader.exists(path) else null
	return loaded if loaded != null else ModelTweaks.new()


## Writes the tweaks file (tweaks that change nothing are left out); no file at all when nothing is left.
static func save_tweaks(model_name: String, tweaks: ModelTweaks) -> Error:
	var kept := tweaks.duplicate(true) as ModelTweaks
	kept.nodes = kept.nodes.filter(func(t: NodeTweak) -> bool: return not t.is_empty())
	var path := tweaks_path(model_name)
	if kept.nodes.is_empty() and kept.pose_overrides.is_empty() and kept.renames.is_empty():
		if FileAccess.file_exists(path):
			return DirAccess.remove_absolute(path)
		return OK
	return ResourceSaver.save(kept, path)


## The recipe's model built with `tweaks` (null: none), or null when the recipe doesn't load.
## `fresh` reads the recipe again from disk (the workshop reloads after an edit).
static func build_kit(model_name: String, tweaks: ModelTweaks, fresh := false) -> ModelKit:
	var recipe := ResourceLoader.load(recipe_path(model_name), "", \
			ResourceLoader.CACHE_MODE_IGNORE if fresh else ResourceLoader.CACHE_MODE_REUSE) as GDScript
	if recipe == null or not recipe.can_instantiate():
		return null
	ModelKit.tweaks_for_build = tweaks
	var kit = recipe.call("build")
	ModelKit.tweaks_for_build = null
	kit.root.name = model_name.to_pascal_case()
	return kit


## Saves the kit as the model's scene; a scene that only differs by Godot's random node ids stays as it was.
static func save_scene(model_name: String, kit: ModelKit) -> Error:
	var path := scene_path(model_name)
	var before := FileAccess.get_file_as_string(path) if FileAccess.file_exists(path) else ""
	var error := kit.save(path)
	if error == OK and not before.is_empty() and _same_scene(before, FileAccess.get_file_as_string(path)):
		FileAccess.open(path, FileAccess.WRITE).store_string(before)
	return error


static func _same_scene(a: String, b: String) -> bool:
	var ids := RegEx.create_from_string(" unique_id=[0-9]+")
	return ids.sub(a, "", true) == ids.sub(b, "", true)
