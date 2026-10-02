@tool
class_name AchievementData
extends Resource
## An achievement: a name, what to do, and the condition (a kind and a number). Content is data:
## a new one is a file in data/achievements/ (its file name is its id, saved in the profile).

enum Kind {
	FLOOR_REACHED,  ## The best floor reached is at least `threshold`.
	ELITE_DEFEATED,  ## An elite floor was won.
	BOSS_DEFEATED,  ## A boss floor or a stage was won.
	FLAWLESS_FLOOR,  ## A floor was won without a hero falling.
	FULL_RUNES,  ## A hero wears a rune in each of its slots.
	HERO_LEVEL,  ## A hero reached level `threshold`.
	STAGES_CLEARED,  ## At least `threshold` stages are cleared.
}

@export var display_name := ""
@export_multiline var description := ""
@export var kind := Kind.FLOOR_REACHED
@export_range(1, 9999) var threshold := 1
## Display order (lower first).
@export var sort_order := 0


func id() -> String:
	return resource_path.get_file().get_basename()


func get_validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	if display_name.is_empty():
		errors.append("achievement %s has no display_name" % id())
	if description.is_empty():
		errors.append("achievement %s has no description" % id())
	return errors
