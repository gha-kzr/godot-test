extends RefCounted
## The Ghost: a hovering purple spirit with bat ears, glowing eyes and clawed arms.

const BODY := Color(0.36, 0.22, 0.52)
const DARK := Color(0.22, 0.12, 0.34)
const LIGHT := Color(0.52, 0.36, 0.7)
const EYE := Color(0.7, 0.95, 0.9)
const PUPIL := Color(0.05, 0.02, 0.1)
const CLAW := Color(0.85, 0.8, 0.95)


static func build() -> ModelKit:
	var k := ModelKit.new()
	var rig := k.joint(null, "Rig")
	var body := k.joint(rig, "Body", Vector3(0, 0.2, 0))
	k.part(body, "Hood", ModelKit.blob(Vector3(0.3, 0.3, 0.27), 8, 4), BODY, Vector3(0, 0.78, 0))
	k.part(body, "Torso", ModelKit.prism(6, Vector2(0.17, 0.15), Vector2(0.27, 0.24), 0.4), BODY, Vector3(0, 0.45, 0))
	k.part(body, "Skirt", ModelKit.prism(6, Vector2(0.04, 0.04), Vector2(0.17, 0.15), 0.38), DARK, Vector3(0, 0.12, 0))
	k.part(body, "FaceMask", ModelKit.blob(Vector3(0.22, 0.17, 0.12), 8, 3), DARK, Vector3(0, 0.78, 0.17))
	for side in [1, -1]:
		var tag := ".L" if side == 1 else ".R"
		k.part(body, "Ear" + tag, ModelKit.prism(4, Vector2(0.075, 0.05), Vector2.ZERO, 0.26), BODY, Vector3(0.18 * side, 1.07, -0.02), Vector3(0, 0, -22 * side))
		k.part(body, "Eye" + tag, ModelKit.blob(Vector3(0.075, 0.085, 0.04), 6, 3), EYE, Vector3(0.1 * side, 0.82, 0.255), Vector3.ZERO, 0.5)
		k.part(body, "Pupil" + tag, ModelKit.blob(Vector3(0.03, 0.04, 0.02), 4, 2), PUPIL, Vector3(0.1 * side, 0.82, 0.29))
		var arm := k.joint(body, "Arm" + tag, Vector3(0.27 * side, 0.6, 0.02))
		k.part(arm, "Limb", ModelKit.prism(4, Vector2(0.06, 0.06), Vector2(0.04, 0.04), 0.34), LIGHT, Vector3(0, -0.17, 0))
		k.part(arm, "Hand", ModelKit.blob(Vector3(0.08, 0.07, 0.08), 6, 3), LIGHT, Vector3(0, -0.37, 0))
		for finger in [-1, 0, 1]:
			k.part(arm, "Claw%d" % finger, ModelKit.prism(4, Vector2(0.018, 0.018), Vector2.ZERO, 0.12), CLAW, Vector3(0.04 * finger, -0.47, 0.02), Vector3(-10, 0, -15 * finger))
	for index in 3:
		var angle := TAU * index / 3.0 + 0.4
		k.part(body, "Hem%d" % index, ModelKit.prism(4, Vector2(0.06, 0.04), Vector2.ZERO, 0.2), DARK, Vector3(sin(angle) * 0.1, 0.0, cos(angle) * 0.1), Vector3(180, 0, 0))
	var tail := k.joint(body, "Tail", Vector3(0, 0.0, -0.05))
	k.part(tail, "Wisp", ModelKit.prism(4, Vector2(0.07, 0.07), Vector2(0.0, 0.0), 0.3), DARK, Vector3(0, -0.04, -0.12), Vector3(-30, 0, 0))
	k.part(tail, "Wisp2", ModelKit.prism(4, Vector2(0.05, 0.05), Vector2(0.0, 0.0), 0.24), DARK, Vector3(0.1, -0.02, -0.08), Vector3(-20, 0, -25))
	FloaterClips.animate(k)
	return k
