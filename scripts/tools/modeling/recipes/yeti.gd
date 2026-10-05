extends RefCounted
## The Yeti: a hulking, hunched white-furred beast with a blue face and hands, very long arms.

const FUR := Color(0.88, 0.91, 0.96)
const SHADE := Color(0.68, 0.75, 0.86)
const ICE := Color(0.35, 0.65, 0.82)
const DARK_ICE := Color(0.22, 0.45, 0.62)
const FANG := Color(0.98, 0.98, 0.95)
const EYE := Color(0.8, 1.0, 1.0)
const DARK := Color(0.05, 0.08, 0.12)


static func build() -> ModelKit:
	var k := ModelKit.new()
	var rig := k.joint(null, "Rig")
	for side in [1, -1]:
		var tag := ".L" if side == 1 else ".R"
		var leg := k.joint(rig, "Leg" + tag, Vector3(0.15 * side, 0.46, 0))
		k.part(leg, "Thigh", ModelKit.prism(4, Vector2(0.125, 0.13), Vector2(0.105, 0.11), 0.36), FUR, Vector3(0, -0.2, 0))
		k.part(leg, "Fluff", ModelKit.prism(4, Vector2(0.13, 0.13), Vector2(0.11, 0.11), 0.08), SHADE, Vector3(0, -0.36, 0))
		k.part(leg, "Foot", ModelKit.prism(4, Vector2(0.125, 0.18), Vector2(0.105, 0.13), 0.1), ICE, Vector3(0, -0.415, 0.05))
		for toe in [-1, 0, 1]:
			k.part(leg, "Toe%d" % toe, ModelKit.prism(4, Vector2(0.03, 0.03), Vector2.ZERO, 0.08), FANG, Vector3(0.07 * toe, -0.435, 0.24), Vector3(90, 0, 0))
	var hips := k.joint(rig, "Hips", Vector3(0, 0.46, 0))
	k.part(hips, "Torso", ModelKit.prism(4, Vector2(0.27, 0.2), Vector2(0.42, 0.25), 0.54), FUR, Vector3(0, 0.3, 0))
	k.part(hips, "Hump", ModelKit.blob(Vector3(0.42, 0.2, 0.28), 8, 3), FUR, Vector3(0, 0.6, -0.06))
	k.part(hips, "Belly", ModelKit.prism(4, Vector2(0.17, 0.02), Vector2(0.22, 0.02), 0.34), SHADE, Vector3(0, 0.27, 0.225))
	k.part(hips, "Skirt", ModelKit.prism(4, Vector2(0.3, 0.22), Vector2(0.28, 0.2), 0.12), SHADE, Vector3(0, 0.0, 0))
	for index in 5:
		var x := (index - 2) * 0.12
		k.part(hips, "Hem%d" % index, ModelKit.prism(4, Vector2(0.06, 0.05), Vector2.ZERO, 0.14), SHADE, Vector3(x, -0.1, 0.1 - absf(index - 2) * 0.03), Vector3(180, 0, 0))
		k.part(hips, "Tuft%d" % index, ModelKit.wedge(0.12, 0.15, 0.11, 0.5), SHADE, Vector3(x * 1.5, 0.74, -0.14 + absf(index - 2) * 0.04))
	var head := k.joint(hips, "Head", Vector3(0, 0.7, 0.14))
	k.part(head, "Skull", ModelKit.blob(Vector3(0.28, 0.26, 0.27), 8, 4), FUR, Vector3(0, 0.12, 0.0))
	k.part(head, "Face", ModelKit.blob(Vector3(0.2, 0.17, 0.11), 8, 3), ICE, Vector3(0, 0.09, 0.22))
	k.part(head, "Brow", ModelKit.box(Vector3(0.3, 0.05, 0.08)), SHADE, Vector3(0, 0.22, 0.24))
	k.part(head, "Mouth", ModelKit.box(Vector3(0.14, 0.04, 0.03)), DARK, Vector3(0, 0.0, 0.325))
	k.part(head, "Crest", ModelKit.wedge(0.1, 0.18, 0.34, 0.5), FUR, Vector3(0, 0.4, -0.02))
	k.part(head, "Ruff", ModelKit.prism(4, Vector2(0.2, 0.08), Vector2(0.06, 0.03), 0.18), SHADE, Vector3(0, -0.1, 0.12), Vector3(-15, 0, 0))
	for side in [1, -1]:
		var tag := ".L" if side == 1 else ".R"
		k.part(head, "Eye" + tag, ModelKit.blob(Vector3(0.05, 0.05, 0.03), 5, 3), EYE, Vector3(0.09 * side, 0.15, 0.31), Vector3.ZERO, 0.5)
		k.part(head, "Pupil" + tag, ModelKit.blob(Vector3(0.02, 0.025, 0.015), 4, 2), DARK, Vector3(0.09 * side, 0.145, 0.338))
		k.part(head, "Fang" + tag, ModelKit.prism(4, Vector2(0.022, 0.022), Vector2.ZERO, 0.09), FANG, Vector3(0.05 * side, -0.04, 0.32), Vector3(180, 0, 0))
		k.part(head, "Horn" + tag, ModelKit.prism(4, Vector2(0.05, 0.05), Vector2.ZERO, 0.2), ICE, Vector3(0.19 * side, 0.36, 0.0), Vector3(0, 0, -28 * side))
		k.part(hips, "Shoulder" + tag, ModelKit.blob(Vector3(0.17, 0.14, 0.16), 6, 3), FUR, Vector3(0.46 * side, 0.55, 0))
		var arm := k.joint(hips, "Arm" + tag, Vector3(0.48 * side, 0.5, 0))
		k.part(arm, "Upper", ModelKit.prism(4, Vector2(0.115, 0.115), Vector2(0.095, 0.095), 0.46), FUR, Vector3(0, -0.24, 0))
		k.part(arm, "Fur", ModelKit.prism(4, Vector2(0.125, 0.125), Vector2(0.1, 0.1), 0.1), SHADE, Vector3(0, -0.38, 0))
		k.part(arm, "Forearm", ModelKit.prism(4, Vector2(0.1, 0.1), Vector2(0.09, 0.09), 0.14), ICE, Vector3(0, -0.5, 0))
		for tuft in 3:
			k.part(arm, "ArmTuft%d" % tuft, ModelKit.prism(4, Vector2(0.05, 0.04), Vector2.ZERO, 0.16), SHADE, Vector3(0.1 * side, -0.14 - tuft * 0.12, -0.02 + tuft * 0.02), Vector3(180, 0, -10 * side))
		var hand := k.joint(arm, "Hand" + tag, Vector3(0, -0.62, 0.0))
		k.part(hand, "Fist", ModelKit.blob(Vector3(0.14, 0.12, 0.12), 6, 3), ICE)
		for claw in [-1, 0, 1]:
			k.part(hand, "Claw%d" % claw, ModelKit.prism(4, Vector2(0.03, 0.03), Vector2.ZERO, 0.12), FANG, Vector3(0.07 * claw, -0.13, 0.03), Vector3(180, 0, 0))
	k.joints["Hips"].rotation_degrees = Vector3(10, 0, 0)
	k.joints["Head"].rotation_degrees = Vector3(-12, 0, 0)
	k.joints["Arm.R"].rotation_degrees = Vector3(-8, 0, -10)
	k.joints["Arm.L"].rotation_degrees = Vector3(-8, 0, 10)
	BipedClips.animate(k, {"attack": &"punch", "stride": 24.0, "bob": 0.06, "lie": 0.22})
	return k
