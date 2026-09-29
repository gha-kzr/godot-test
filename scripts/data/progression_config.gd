@tool
class_name ProgressionConfig
extends Resource
## Shared progression numbers: the level cap and the XP curve.

@export_range(1, 99) var level_cap := 10
## Total XP needed for each level; index 0 is level 1 (always 0).
@export var xp_thresholds: Array[int] = [0, 20, 50, 90, 140, 200, 270, 350, 440, 540]


func level_for_xp(xp: int) -> int:
	var level := 1
	for i in range(1, mini(level_cap, xp_thresholds.size())):
		if xp >= xp_thresholds[i]:
			level = i + 1
	return level


## Total XP for the next level, or -1 at the cap.
func xp_for_next(level: int) -> int:
	return xp_thresholds[level] if level < mini(level_cap, xp_thresholds.size()) else -1


func get_validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	if xp_thresholds.size() < level_cap:
		errors.append("progression: %d XP thresholds for level cap %d" % [xp_thresholds.size(), level_cap])
	if not xp_thresholds.is_empty() and xp_thresholds[0] != 0:
		errors.append("progression: level 1 must need 0 XP")
	for i in range(1, xp_thresholds.size()):
		if xp_thresholds[i] <= xp_thresholds[i - 1]:
			errors.append("progression: XP thresholds must increase (level %d)" % (i + 1))
	return errors
