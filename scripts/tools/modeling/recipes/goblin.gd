extends RefCounted
## The Goblin (PvP): a small green bomb thrower, a head half its height, huge ears, brass goggles on
## the forehead, a ragged vest with a bandolier of bombs, rust trousers, oversized boots. A big
## bomb with a lit fuse in the right hand.

const GREEN := Color(0.46, 0.72, 0.3)
const GREEN_DARK := Color(0.36, 0.6, 0.24)
const EAR_IN := Color(0.7, 0.5, 0.4)
const VEST := Color(0.5, 0.33, 0.2)
const PANTS := Color(0.72, 0.32, 0.14)
const BOOT := Color(0.55, 0.43, 0.26)
const BOMB := Color(0.14, 0.14, 0.18)
const SPARK := Color(1.0, 0.86, 0.15)
const EYE := Color(1.0, 0.86, 0.12)
const BRASS := Color(0.8, 0.58, 0.22)
const LENS := Color(0.6, 0.72, 0.62)
const FANG := Color(0.98, 0.95, 0.8)
const DARK := Color(0.08, 0.05, 0.05)


static func build() -> ModelKit:
	var k := ModelKit.new()
	var rig := k.joint(null, "Rig")
	for side in [1, -1]:
		var tag := ".L" if side == 1 else ".R"
		var leg := k.joint(rig, "Leg" + tag, Vector3(0.09 * side, 0.23, 0))
		k.part(leg, "Trouser", ModelKit.prism(4, Vector2(0.075, 0.075), Vector2(0.07, 0.07), 0.15), PANTS, Vector3(0, -0.07, 0))
		k.part(leg, "Boot", ModelKit.prism(4, Vector2(0.095, 0.14), Vector2(0.085, 0.1), 0.11), BOOT, Vector3(0, -0.175, 0.04))
	var hips := k.joint(rig, "Hips", Vector3(0, 0.23, 0))
	k.part(hips, "Pants", ModelKit.prism(6, Vector2(0.2, 0.17), Vector2(0.18, 0.16), 0.14), PANTS, Vector3(0, 0.0, 0))
	k.part(hips, "Patch", ModelKit.box(Vector3(0.06, 0.06, 0.02)), GREEN_DARK, Vector3(-0.08, -0.03, 0.165), Vector3(0, 0, 12))
	k.part(hips, "Belly", ModelKit.prism(6, Vector2(0.18, 0.16), Vector2(0.22, 0.19), 0.2), GREEN, Vector3(0, 0.15, 0.01))
	k.part(hips, "Chest", ModelKit.prism(6, Vector2(0.21, 0.18), Vector2(0.18, 0.15), 0.12), GREEN, Vector3(0, 0.3, 0))
	k.part(hips, "Vest", ModelKit.prism(6, Vector2(0.225, 0.2), Vector2(0.2, 0.17), 0.2), VEST, Vector3(0, 0.25, -0.025))
	k.part(hips, "Strap", ModelKit.box(Vector3(0.055, 0.4, 0.025)), VEST, Vector3(0, 0.22, 0.17), Vector3(0, 0, -38))
	for index in 3:
		k.part(hips, "Bomb%d" % index, ModelKit.blob(Vector3(0.05, 0.05, 0.05), 6, 3), BOMB, Vector3(0.075 - 0.07 * index, 0.3 - 0.075 * index, 0.2))
		k.part(hips, "Fuse%d" % index, ModelKit.box(Vector3(0.012, 0.03, 0.012)), BRASS, Vector3(0.075 - 0.07 * index, 0.345 - 0.075 * index, 0.2))
	var head := k.joint(hips, "Head", Vector3(0, 0.34, 0))
	k.part(head, "Skull", ModelKit.blob(Vector3(0.27, 0.25, 0.25), 8, 4), GREEN, Vector3(0, 0.22, 0))
	k.part(head, "Jaw", ModelKit.blob(Vector3(0.2, 0.1, 0.19), 7, 3), GREEN_DARK, Vector3(0, 0.07, 0.04))
	k.part(head, "Nose", ModelKit.prism(4, Vector2(0.05, 0.05), Vector2.ZERO, 0.16), EAR_IN, Vector3(0, 0.17, 0.3), Vector3(105, 0, 0))
	k.part(head, "Mouth", ModelKit.box(Vector3(0.2, 0.03, 0.03)), DARK, Vector3(0, 0.08, 0.215), Vector3(0, 0, -4))
	for side in [1, -1]:
		k.part(head, "Fang%d" % side, ModelKit.prism(4, Vector2(0.018, 0.012), Vector2.ZERO, 0.06), FANG, Vector3(0.06 * side, 0.1, 0.225), Vector3(180, 0, 0))
		k.part(head, "Eye%d" % side, ModelKit.blob(Vector3(0.06, 0.06, 0.03), 6, 3), EYE, Vector3(0.1 * side, 0.26, 0.235), Vector3.ZERO, 0.5)
		k.part(head, "Pupil%d" % side, ModelKit.blob(Vector3(0.022, 0.03, 0.015), 4, 2), DARK, Vector3(0.1 * side, 0.26, 0.262))
		k.part(head, "Brow%d" % side, ModelKit.box(Vector3(0.11, 0.03, 0.03)), GREEN_DARK, Vector3(0.1 * side, 0.335, 0.215), Vector3(0, 0, 14 * side))
		# The big ears: flat pyramids sticking out sideways and a little up, with a pink inner face.
		var ear_angle := 12.0
		var direction := Vector2(cos(deg_to_rad(ear_angle)), sin(deg_to_rad(ear_angle)))
		var center := Vector3(side * (0.22 + direction.x * 0.15), 0.27 + direction.y * 0.15, -0.02)
		k.part(head, "Ear%d" % side, ModelKit.prism(4, Vector2(0.1, 0.02), Vector2.ZERO, 0.32), GREEN, center, Vector3(0, 0, -(90 - ear_angle) * side))
		k.part(head, "EarIn%d" % side, ModelKit.prism(4, Vector2(0.07, 0.015), Vector2.ZERO, 0.24), EAR_IN, center + Vector3(side * 0.01, 0, 0.012), Vector3(0, 0, -(90 - ear_angle) * side))
	# Goggles pushed up onto the forehead.
	k.part(head, "Strap", ModelKit.prism(8, Vector2(0.24, 0.23), Vector2(0.2, 0.19), 0.05), VEST, Vector3(0, 0.37, 0))
	for side in [1, -1]:
		k.part(head, "GoggleRim%d" % side, ModelKit.prism(8, Vector2(0.075, 0.075), Vector2(0.075, 0.075), 0.045), BRASS, Vector3(0.09 * side, 0.43, 0.17), Vector3(60, 0, 0))
		k.part(head, "Lens%d" % side, ModelKit.prism(8, Vector2(0.055, 0.055), Vector2(0.055, 0.055), 0.05), LENS, Vector3(0.09 * side, 0.435, 0.178), Vector3(60, 0, 0))
	for side in [1, -1]:
		var tag := ".L" if side == 1 else ".R"
		var arm := k.joint(hips, "Arm" + tag, Vector3(0.23 * side, 0.32, 0))
		k.part(arm, "Arm", ModelKit.prism(4, Vector2(0.06, 0.06), Vector2(0.05, 0.05), 0.28), GREEN, Vector3(0, -0.14, 0))
		var hand := k.joint(arm, "Hand" + tag, Vector3(0, -0.31, 0))
		k.part(hand, "Fist", ModelKit.blob(Vector3(0.07, 0.065, 0.07), 6, 3), GREEN)
	# The lit bomb held in the right hand, a little in front of the fist.
	var bomb := k.joint(k.joints["Hand.R"], "Bomb.R", Vector3(0, 0.04, 0.09))
	k.part(bomb, "Bomb", ModelKit.blob(Vector3(0.13, 0.13, 0.13), 8, 4), BOMB, Vector3(0, 0.08, 0))
	k.part(bomb, "Glint", ModelKit.blob(Vector3(0.03, 0.03, 0.02), 4, 2), Color(0.4, 0.42, 0.5), Vector3(-0.06, 0.13, 0.12))
	k.part(bomb, "Neck", ModelKit.prism(6, Vector2(0.035, 0.035), Vector2(0.03, 0.03), 0.05), BOMB, Vector3(0, 0.2, 0))
	k.part(bomb, "FuseRope", ModelKit.prism(4, Vector2(0.01, 0.01), Vector2(0.01, 0.01), 0.1), BRASS, Vector3(0.015, 0.27, 0), Vector3(0, 0, -14))
	k.part(bomb, "Spark", ModelKit.blob(Vector3(0.05, 0.05, 0.05), 6, 3), SPARK, Vector3(0.04, 0.34, 0), Vector3.ZERO, 1.5)
	k.joints["Arm.R"].rotation_degrees = Vector3(-18, 0, -34)
	k.joints["Arm.L"].rotation_degrees = Vector3(0, 0, 8)
	k.joints["Hips"].rotation_degrees = Vector3(6, 0, 0)
	k.joints["Head"].rotation_degrees = Vector3(-6, 0, 0)
	BipedClips.animate(k, {"attack": &"punch", "stride": 36.0, "bob": 0.04, "lie": 0.2})
	return k
