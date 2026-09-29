@tool
class_name EncounterSpawn
extends Resource
## One enemy of an encounter: which, at what level, with which preset.

@export var enemy: EnemyData
@export_range(1, 99) var level := 1
## Null: normal.
@export var preset: DifficultyPreset


## Null (with an error) for a spawn without an enemy.
func build() -> EnemyData.Build:
	if enemy == null:
		push_error("EncounterSpawn: no enemy")
		return null
	return enemy.build(level, preset)


func get_validation_errors() -> PackedStringArray:
	if enemy == null:
		return PackedStringArray(["spawn has no enemy"])
	var errors := enemy.get_validation_errors()
	if preset != null:
		errors.append_array(preset.get_validation_errors())
	return errors
