@tool
class_name ProgressionConfig
extends Resource
## Shared progression numbers: the level cap and the XP curve.
##
## The XP needed to reach level L is `curve_coefficient` x (L - 1) ^ `curve_exponent`, so a very
## high cap needs no authored numbers. `xp_thresholds` may pin the first levels by hand (the
## curve takes over past its end); leave it empty to use the curve from level 2. The two curve
## numbers are the pacing knobs: the coefficient shifts the whole curve, the exponent how much
## steeper late levels are (tuned with tools/pace.gd's idea: levels reached per floor).

@export_range(1, 1000) var level_cap := 100
@export_range(0.1, 1000.0) var curve_coefficient := 8.0
@export_range(1.0, 4.0) var curve_exponent := 2.45
## The rune the first victory always grants, so a new player has one to learn equipping with
## (the tutorial's hub step). Empty: none.
@export var first_rune: RuneData
## Total XP for the first levels, by hand (quick first levels); index 0 is level 1 (always 0). The
## curve takes over past its end; empty: the curve from level 2.
@export var xp_thresholds: Array[int] = [0, 20, 50, 90]


## Total XP needed to reach `level` (level 1: 0).
func xp_for_level(level: int) -> int:
	if level <= 1:
		return 0
	if level <= xp_thresholds.size():
		return xp_thresholds[level - 1]
	var from_table := xp_thresholds[-1] if not xp_thresholds.is_empty() else 0
	var curve := roundi(curve_coefficient * pow(level - 1, curve_exponent))
	return maxi(curve, from_table + (level - maxi(xp_thresholds.size(), 1)))  # Always increasing.


func level_for_xp(xp: int) -> int:
	var level := 1
	while level < level_cap and xp >= xp_for_level(level + 1):
		level += 1
	return level


## Total XP for the next level, or -1 at the cap.
func xp_for_next(level: int) -> int:
	return xp_for_level(level + 1) if level < level_cap else -1


func get_validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	if not xp_thresholds.is_empty() and xp_thresholds[0] != 0:
		errors.append("progression: level 1 must need 0 XP")
	if xp_thresholds.size() > level_cap:
		errors.append("progression: %d XP thresholds for level cap %d" % [xp_thresholds.size(), level_cap])
	for i in range(1, xp_thresholds.size()):
		if xp_thresholds[i] <= xp_thresholds[i - 1]:
			errors.append("progression: XP thresholds must increase (level %d)" % (i + 1))
	return errors
