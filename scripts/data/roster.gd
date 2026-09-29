@tool
class_name Roster
extends Resource
## Every hero the game has, which ones start unlocked and in the party, and the
## progression config. A new profile starts from it.

@export var heroes: Array[HeroData] = []
## Indices into `heroes`.
@export var starting_unlocked: Array[int] = [0, 1]
@export var starting_party: Array[int] = [0, 1]
@export var config: ProgressionConfig


func get_validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	if config == null:
		errors.append("roster has no progression config")
	else:
		errors.append_array(config.get_validation_errors())
	for hero in heroes:
		if hero == null:
			errors.append("roster: empty hero slot")
			continue
		errors.append_array(hero.get_validation_errors())
	for index in starting_party:
		if index < 0 or index >= heroes.size():
			errors.append("roster: starting party index %d out of range" % index)
		elif index not in starting_unlocked:
			errors.append("roster: starting party hero %d isn't unlocked" % index)
	return errors
