@tool
class_name ContentFactory
extends RefCounted
## Creates content files for the Design panel: a new spell, enemy (with its unit),
## encounter or preset from a template, or a copy of an existing one. Files get a UID so
## saves can find them after renames. Returns an error message, or "" and sets `last_path`.

enum Kind { SPELL, ENEMY, ENCOUNTER, PRESET }

const FOLDERS: Dictionary[Kind, String] = {Kind.SPELL: "spells", Kind.ENEMY: "enemies", Kind.ENCOUNTER: "encounters", Kind.PRESET: "presets"}

## Where content goes (tests use a temporary folder).
var data_root := "res://data"
var last_path := ""
var _path_error := ""


func _init(root := "res://data") -> void:
	data_root = root


static func kind_name(kind: Kind) -> String:
	return Kind.keys()[kind].capitalize()


## Which kind a resource is, or -1.
static func kind_of(resource: Resource) -> int:
	if resource is SpellData:
		return Kind.SPELL
	if resource is EnemyData:
		return Kind.ENEMY
	if resource is Encounter:
		return Kind.ENCOUNTER
	if resource is DifficultyPreset:
		return Kind.PRESET
	return -1


## "Frost Bolt" → "frost_bolt".
static func file_stem(display_name: String) -> String:
	var stem := display_name.strip_edges().to_snake_case()
	var cleaned := ""
	for character in stem:
		if character == "_" or (character >= "a" and character <= "z") or (character >= "0" and character <= "9"):
			cleaned += character
	return cleaned


func create(kind: Kind, display_name: String) -> String:
	var path := _free_path(kind, display_name)
	if path.is_empty():
		return _path_error
	var resource: Resource
	match kind:
		Kind.SPELL:
			resource = _template_spell(display_name)
		Kind.ENEMY:
			var unit := _template_unit(display_name)
			var unit_path := "%s/units/%s.tres" % [data_root, file_stem(display_name)]
			if FileAccess.file_exists(unit_path):
				return "A unit file %s already exists." % unit_path
			DirAccess.make_dir_recursive_absolute(unit_path.get_base_dir())
			var error := _save(unit, unit_path)
			if not error.is_empty():
				return error
			resource = _template_enemy(load(unit_path) as UnitData)
		Kind.ENCOUNTER:
			resource = _template_encounter(display_name)
		Kind.PRESET:
			var preset := DifficultyPreset.new()
			preset.display_name = display_name
			preset.tag = display_name
			resource = preset
	return _save(resource, path)


## A copy of `source` named `display_name`, with its own copies of inline sub-resources
## (area, effects…); files it refers to (statuses, loot tables…) stay shared, except an
## enemy's unit, which is copied too (its name and stats belong to the new enemy).
func duplicate_resource(source: Resource, display_name: String) -> String:
	var kind := kind_of(source)
	if kind == -1:
		return "Only spells, enemies, encounters and presets can be duplicated."
	var path := _free_path(kind, display_name)
	if path.is_empty():
		return _path_error
	var copy := source.duplicate_deep(Resource.DEEP_DUPLICATE_INTERNAL)
	if copy is EnemyData and (copy as EnemyData).unit != null:
		var unit_path := "%s/units/%s.tres" % [data_root, file_stem(display_name)]
		if FileAccess.file_exists(unit_path):
			return "A unit file %s already exists." % unit_path
		var unit := (copy as EnemyData).unit.duplicate_deep(Resource.DEEP_DUPLICATE_INTERNAL) as UnitData
		unit.display_name = display_name
		DirAccess.make_dir_recursive_absolute(unit_path.get_base_dir())
		var error := _save(unit, unit_path)
		if not error.is_empty():
			return error
		(copy as EnemyData).unit = load(unit_path) as UnitData
	elif "display_name" in copy and copy.get("display_name") is String:
		copy.set("display_name", display_name)
	return _save(copy, path)


## The file path for a new resource, or "" (with the reason in _path_error).
func _free_path(kind: Kind, display_name: String) -> String:
	var stem := file_stem(display_name)
	if stem.is_empty():
		_path_error = "Give it a name."
		return ""
	var folder := "%s/%s" % [data_root, FOLDERS[kind]]
	var path := "%s/%s.tres" % [folder, stem]
	if FileAccess.file_exists(path):
		_path_error = "%s already exists." % path
		return ""
	DirAccess.make_dir_recursive_absolute(folder)
	return path


func _save(resource: Resource, path: String) -> String:
	var error := ResourceSaver.save(resource, path)
	if error != OK:
		return "Couldn't save %s (%s)." % [path, error_string(error)]
	var id := ResourceUID.create_id()
	ResourceSaver.set_uid(path, id)
	if not ResourceUID.has_id(id):
		ResourceUID.add_id(id, path)
	last_path = path
	return ""


func _template_spell(display_name: String) -> SpellData:
	var spell := SpellData.new()
	spell.display_name = display_name
	spell.ap_cost = 3
	spell.min_range = 1
	spell.max_range = 1
	spell.area = AreaShape.new()
	var damage := DamageEffect.new()
	damage.min_amount = 5
	damage.max_amount = 7
	var physical := "res://data/damage_types/physical.tres"
	if ResourceLoader.exists(physical):
		damage.damage_type = load(physical)
	spell.effects = [damage] as Array[EffectData]
	return spell


func _template_unit(display_name: String) -> UnitData:
	var unit := UnitData.new()
	unit.display_name = display_name
	unit.max_hp = 30
	unit.color = Color(0.8, 0.3, 0.3)
	var slash := "res://data/spells/slash.tres"
	if ResourceLoader.exists(slash):
		unit.spells = [load(slash)] as Array[SpellData]
	return unit


func _template_enemy(unit: UnitData) -> EnemyData:
	var enemy := EnemyData.new()
	enemy.unit = unit
	var pool := "res://data/loot/common_pool.tres"
	if ResourceLoader.exists(pool):
		enemy.loot_table = load(pool)
	return enemy


func _template_encounter(display_name: String) -> Encounter:
	var encounter := Encounter.new()
	encounter.display_name = display_name
	for entry in [["map", "res://data/maps/slice.tres"], ["ai_profile", "res://data/ai/default.tres"]]:
		if ResourceLoader.exists(entry[1]):
			encounter.set(entry[0], load(entry[1]))
	var brute := "res://data/enemies/brute.tres"
	if ResourceLoader.exists(brute):
		var spawn := EncounterSpawn.new()
		spawn.enemy = load(brute)
		encounter.spawns = [spawn] as Array[EncounterSpawn]
	return encounter
