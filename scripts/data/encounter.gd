@tool
class_name Encounter
extends Resource
## A fight: a map and the enemies on its enemy spawns (in spawn order). The game's battles
## and the balance lab use it; milestone 4's generator will produce them.

@export var display_name := ""
@export var map: MapData
@export var spawns: Array[EncounterSpawn] = []
## For enemies whose preset doesn't set one.
@export var ai_profile: AIProfile


## The enemies to field; empty or broken spawns are skipped (with an error).
func builds() -> Array[EnemyData.Build]:
	var result: Array[EnemyData.Build] = []
	for spawn in spawns:
		var build := spawn.build() if spawn != null else null
		if build == null:
			push_error("Encounter %s: skipping an empty or broken spawn" % display_name)
			continue
		result.append(build)
	return result


func get_validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	if map == null:
		errors.append("%s: no map" % display_name)
	else:
		var parsed := map.parse()
		errors.append_array(parsed.errors)
		if parsed.grid != null and spawns.size() > parsed.enemy_spawns.size():
			errors.append("%s: %d enemies for %d enemy spawns" % [display_name, spawns.size(), parsed.enemy_spawns.size()])
	if spawns.is_empty():
		errors.append("%s: no enemies" % display_name)
	for spawn in spawns:
		if spawn == null:
			errors.append("%s: empty spawn slot" % display_name)
			continue
		for error in spawn.get_validation_errors():
			errors.append("%s: %s" % [display_name, error])
	return errors
