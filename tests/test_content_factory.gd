extends TestCase
## The Design panel's content factory, writing into a temporary data folder.

## Under res://, where Godot writes UIDs into the files (it doesn't for user:// paths).
const ROOT := "res://tmp_test_content_factory"


func _factory() -> ContentFactory:
	_clean()
	return ContentFactory.new(ROOT)


func _clean() -> void:
	var dirs := [ROOT]
	var all_dirs: Array[String] = []
	while not dirs.is_empty():
		var dir: String = dirs.pop_back()
		if not DirAccess.dir_exists_absolute(dir):
			continue
		all_dirs.append(dir)
		for sub in DirAccess.get_directories_at(dir):
			dirs.append(dir.path_join(sub))
		for file in DirAccess.get_files_at(dir):
			DirAccess.remove_absolute(dir.path_join(file))
	all_dirs.reverse()
	for dir in all_dirs:
		DirAccess.remove_absolute(dir)


func test_file_stems() -> void:
	assert_eq(ContentFactory.file_stem("Frost Bolt"), "frost_bolt")
	assert_eq(ContentFactory.file_stem("  Ogre's Club!  "), "ogres_club")
	assert_eq(ContentFactory.file_stem("???"), "")


func test_new_spell_from_the_template() -> void:
	var factory := _factory()
	assert_eq(factory.create(ContentFactory.Kind.SPELL, "Frost Bolt"), "")
	assert_eq(factory.last_path, ROOT + "/spells/frost_bolt.tres")
	var spell := load(factory.last_path) as SpellData
	assert_eq(spell.display_name, "Frost Bolt")
	assert_eq(spell.get_validation_errors(), PackedStringArray(), "a valid starting point")
	assert_true(FileAccess.get_file_as_string(factory.last_path).contains('uid="uid://'), "the file stores a UID")
	_clean()


func test_new_enemy_comes_with_its_unit() -> void:
	var factory := _factory()
	assert_eq(factory.create(ContentFactory.Kind.ENEMY, "Ogre"), "")
	var enemy := load(factory.last_path) as EnemyData
	assert_eq(enemy.unit.resource_path, ROOT + "/units/ogre.tres")
	assert_eq(enemy.display_name(), "Ogre")
	assert_eq(enemy.get_validation_errors(), PackedStringArray())
	_clean()


func test_new_encounter_and_preset() -> void:
	var factory := _factory()
	assert_eq(factory.create(ContentFactory.Kind.ENCOUNTER, "Ambush"), "")
	assert_eq((load(factory.last_path) as Encounter).get_validation_errors(), PackedStringArray())
	assert_eq(factory.create(ContentFactory.Kind.PRESET, "Champion"), "")
	var preset := load(factory.last_path) as DifficultyPreset
	assert_eq([preset.display_name, preset.tag], ["Champion", "Champion"])
	_clean()


func test_names_must_be_new_and_non_empty() -> void:
	var factory := _factory()
	assert_eq(factory.create(ContentFactory.Kind.SPELL, "  "), "Give it a name.")
	assert_eq(factory.create(ContentFactory.Kind.SPELL, "Zap"), "")
	assert_true(factory.create(ContentFactory.Kind.SPELL, "Zap").ends_with("already exists."))
	_clean()


func test_duplicates_are_independent_but_share_files() -> void:
	var factory := _factory()
	var source := load("res://data/spells/poison_arrow.tres") as SpellData
	assert_eq(factory.duplicate_resource(source, "Venom Arrow"), "")
	var copy := load(factory.last_path) as SpellData
	assert_eq(copy.display_name, "Venom Arrow")
	assert_eq(source.display_name, "Poison Arrow", "the source is untouched")
	assert_ne(copy.effects[0], source.effects[0], "its own inline effects")
	(copy.effects[0] as DamageEffect).max_amount = 99
	assert_eq((source.effects[0] as DamageEffect).max_amount, 3)
	var status_copy := (copy.effects[1] as ApplyStatusEffect).status
	assert_eq(status_copy, (source.effects[1] as ApplyStatusEffect).status, "the Poison status file is shared")
	assert_ne(factory.duplicate_resource(load("res://data/units/knight.tres"), "Knight 2"), "", "units aren't a kind")
	_clean()


func test_duplicating_an_enemy_copies_its_unit_under_the_new_name() -> void:
	var factory := _factory()
	var brute := load("res://data/enemies/brute.tres") as EnemyData
	assert_eq(factory.duplicate_resource(brute, "Big Brute"), "")
	var copy := load(factory.last_path) as EnemyData
	assert_eq(copy.display_name(), "Big Brute")
	assert_eq(copy.unit.resource_path, ROOT + "/units/big_brute.tres")
	assert_ne(copy.unit, brute.unit, "its own unit")
	assert_eq(copy.unit.max_hp, brute.unit.max_hp, "same stats to start from")
	assert_eq(brute.display_name(), "Brute", "the original is untouched")
	assert_eq(copy.loot_table, brute.loot_table, "the loot table file stays shared")
	_clean()


func test_a_tower_floor_exports_as_an_encounter() -> void:
	var factory := _factory()
	var tower := load("res://data/tower/tower.tres") as TowerConfig
	assert_eq(factory.export_floor(tower, 5), "")
	assert_eq(factory.last_path, ROOT + "/encounters/floor_5.tres")
	var exported := load(factory.last_path) as Encounter
	var generated := FloorGenerator.encounter(tower, 5)
	assert_eq(exported.display_name, "Floor 5")
	assert_eq(exported.map.layout, generated.map.layout, "the same map, saved inside")
	assert_eq(exported.spawns.map(func(s: EncounterSpawn) -> String: return s.enemy.resource_path),
			generated.spawns.map(func(s: EncounterSpawn) -> String: return s.enemy.resource_path))
	assert_eq(exported.get_validation_errors(), PackedStringArray())
	assert_true(factory.export_floor(tower, 5).contains("already exists"))
	assert_eq(factory.export_floor(tower, 0), "Floors start at 1.")
	_clean()
