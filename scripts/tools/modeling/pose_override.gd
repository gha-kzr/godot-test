class_name PoseOverride
extends Resource
## One hand-made change to a clip, kept in the model's tweaks file: at `time` of `clip`, `joint`
## is at `value` (a rotation in degrees, added to the joint's rest, or with `is_position` a
## position offset in meters). Replaces what the clip set gives for that joint at that time;
## a time the clip has no pose at gets a new pose, the other joints keeping what the clip gives there.

@export var clip := ""
@export var time := 0.0
## The joint's name as the recipe gave it (`Arm.L`).
@export var joint := ""
@export var is_position := false
@export var value := Vector3.ZERO

## Times closer than this are the same moment.
const SAME_TIME := 0.002


func key() -> String:
	return joint + (":p" if is_position else "")
