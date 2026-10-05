extends RefCounted
## The Warg: a lean grey wolf, long snout, big ears, a dark mane, red eyes.

const FUR := Color(0.5, 0.51, 0.56)
const DARK := Color(0.27, 0.28, 0.33)
const LIGHT := Color(0.74, 0.75, 0.78)
const EYE := Color(1.0, 0.25, 0.15)
const NOSE := Color(0.08, 0.08, 0.1)
const FANG := Color(0.95, 0.95, 0.9)


static func build() -> ModelKit:
	var k := ModelKit.new()
	var rig := k.joint(null, "Rig")
	var body := k.joint(rig, "Body", Vector3(0, 0.55, 0))
	k.part(body, "Chest", ModelKit.prism(6, Vector2(0.21, 0.2), Vector2(0.26, 0.24), 0.46), FUR, Vector3(0, 0.0, 0.17), Vector3(90, 0, 0))
	k.part(body, "Haunch", ModelKit.prism(6, Vector2(0.16, 0.17), Vector2(0.21, 0.2), 0.4), FUR, Vector3(0, -0.01, -0.2), Vector3(90, 0, 0))
	k.part(body, "Belly", ModelKit.prism(4, Vector2(0.11, 0.3), Vector2(0.11, 0.3), 0.04), LIGHT, Vector3(0, -0.17, 0.0))
	k.part(body, "Mane", ModelKit.wedge(0.1, 0.16, 0.5, 0.5), DARK, Vector3(0, 0.27, 0.22))
	k.part(body, "Spine", ModelKit.wedge(0.06, 0.08, 0.4, 0.5), DARK, Vector3(0, 0.24, -0.2))
	var head := k.joint(body, "Head", Vector3(0, 0.1, 0.42))
	k.part(head, "Skull", ModelKit.blob(Vector3(0.19, 0.17, 0.19), 8, 4), FUR, Vector3(0, 0.04, 0.04))
	k.part(head, "Snout", ModelKit.prism(4, Vector2(0.085, 0.07), Vector2(0.055, 0.045), 0.27), FUR, Vector3(0, -0.01, 0.24), Vector3(90, 0, 0))
	k.part(head, "Nose", ModelKit.box(Vector3(0.07, 0.05, 0.05)), NOSE, Vector3(0, 0.0, 0.38))
	for side in [1, -1]:
		var tag := ".L" if side == 1 else ".R"
		k.part(head, "Ear" + tag, ModelKit.prism(4, Vector2(0.07, 0.035), Vector2.ZERO, 0.26), DARK, Vector3(0.11 * side, 0.25, -0.03), Vector3(-8, 0, -14 * side))
		k.part(head, "Eye" + tag, ModelKit.blob(Vector3(0.03, 0.025, 0.02), 4, 2), EYE, Vector3(0.09 * side, 0.1, 0.15), Vector3.ZERO, 1.5)
		k.part(head, "Fang" + tag, ModelKit.prism(4, Vector2(0.014, 0.014), Vector2.ZERO, 0.07), FANG, Vector3(0.04 * side, -0.07, 0.33), Vector3(180, 0, 0))
	var jaw := k.joint(head, "Jaw", Vector3(0, -0.06, 0.08))
	k.part(jaw, "LowerJaw", ModelKit.prism(4, Vector2(0.065, 0.032), Vector2(0.04, 0.02), 0.24), LIGHT, Vector3(0, -0.01, 0.12), Vector3(90, 0, 0))
	var tail := k.joint(body, "Tail", Vector3(0, 0.08, -0.36))
	k.part(tail, "Brush", ModelKit.prism(6, Vector2(0.075, 0.075), Vector2(0.11, 0.11), 0.3), FUR, Vector3(0, 0.0, -0.15), Vector3(-100, 0, 0))
	k.part(tail, "Tip", ModelKit.prism(6, Vector2(0.11, 0.11), Vector2.ZERO, 0.16), LIGHT, Vector3(0, -0.04, -0.37), Vector3(-100, 0, 0))
	for leg_name: String in ["FL", "FR", "BL", "BR"]:
		var side := 1 if leg_name.ends_with("L") else -1
		var front := leg_name.begins_with("F")
		var z := 0.3 if front else -0.28
		var leg := k.joint(body, "Leg." + leg_name, Vector3(0.12 * side, -0.1, z))
		k.part(leg, "Limb", ModelKit.prism(4, Vector2(0.06, 0.065), Vector2(0.04, 0.045), 0.34), FUR, Vector3(0, -0.19, 0))
		if not front:
			k.part(leg, "Thigh", ModelKit.blob(Vector3(0.09, 0.12, 0.11), 6, 3), FUR, Vector3(0.01 * side, -0.04, 0.0))
		k.part(leg, "Paw", ModelKit.box(Vector3(0.09, 0.06, 0.14)), DARK, Vector3(0, -0.42, 0.025))
	QuadrupedClips.animate(k, {"lie": 0.2})
	return k
