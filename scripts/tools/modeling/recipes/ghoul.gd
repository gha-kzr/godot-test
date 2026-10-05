extends RefCounted
## The Ghoul: a hunched green brute with a potbelly, arms down to its knees, ragged shorts, a
## lolling tongue and clawed hands. Hips pitched forward, head thrust out.

const SKIN := Color(0.46, 0.64, 0.36)
const BELLY := Color(0.6, 0.74, 0.44)
const DARK := Color(0.3, 0.42, 0.25)
const RAGS := Color(0.3, 0.4, 0.52)
const LEATHER := Color(0.38, 0.24, 0.14)
const VOID := Color(0.07, 0.06, 0.08)
const EYE := Color(1.0, 0.9, 0.4)
const TONGUE := Color(0.8, 0.25, 0.3)
const CLAW := Color(0.88, 0.85, 0.7)


static func build() -> ModelKit:
	var k := ModelKit.new()
	var rig := k.joint(null, "Rig")
	for side in [1, -1]:
		var tag := ".L" if side == 1 else ".R"
		var leg := k.joint(rig, "Leg" + tag, Vector3(0.1 * side, 0.42, 0))
		k.part(leg, "Leg", ModelKit.prism(4, Vector2(0.095, 0.095), Vector2(0.075, 0.075), 0.34), SKIN, Vector3(0, -0.19, 0))
		k.part(leg, "Foot", ModelKit.prism(4, Vector2(0.1, 0.13), Vector2(0.09, 0.1), 0.08), DARK, Vector3(0, -0.38, 0.035))
	var hips := k.joint(rig, "Hips", Vector3(0, 0.42, 0), Vector3(17, 0, 0))
	k.part(hips, "Shorts", ModelKit.prism(4, Vector2(0.23, 0.17), Vector2(0.2, 0.15), 0.17), RAGS, Vector3(0, 0.0, 0))
	for index in 5:
		var angle := TAU * index / 5.0 + 0.3
		k.part(hips, "Rag%d" % index, ModelKit.prism(4, Vector2(0.05, 0.03), Vector2.ZERO, 0.12), RAGS, Vector3(sin(angle) * 0.16, -0.12, cos(angle) * 0.12), Vector3(180, 0, 0))
	k.part(hips, "Belt", ModelKit.prism(4, Vector2(0.21, 0.155), Vector2(0.21, 0.155), 0.04), LEATHER, Vector3(0, 0.1, 0))
	k.part(hips, "Torso", ModelKit.prism(4, Vector2(0.2, 0.14), Vector2(0.28, 0.18), 0.4), SKIN, Vector3(0, 0.3, 0))
	k.part(hips, "Belly", ModelKit.blob(Vector3(0.2, 0.17, 0.15), 8, 3), BELLY, Vector3(0, 0.19, 0.12))
	k.part(hips, "Hump", ModelKit.blob(Vector3(0.2, 0.14, 0.16), 6, 3), DARK, Vector3(0, 0.5, -0.1))
	var head := k.joint(hips, "Head", Vector3(0, 0.52, 0.04), Vector3(-22, 0, 0))
	k.part(head, "Skull", ModelKit.blob(Vector3(0.21, 0.19, 0.2), 8, 4), SKIN, Vector3(0, 0.15, 0.02))
	k.part(head, "Jaw", ModelKit.prism(4, Vector2(0.12, 0.09), Vector2(0.14, 0.11), 0.08), SKIN, Vector3(0, 0.02, 0.1))
	k.part(head, "Mouth", ModelKit.box(Vector3(0.17, 0.035, 0.03)), VOID, Vector3(0, 0.07, 0.205))
	k.part(head, "Tongue", ModelKit.wedge(0.06, 0.14, 0.04, 1.0), TONGUE, Vector3(0, 0.0, 0.2))
	k.part(head, "Nose", ModelKit.blob(Vector3(0.045, 0.04, 0.04), 5, 2), BELLY, Vector3(0, 0.15, 0.22))
	for side in [1, -1]:
		var tag := ".L" if side == 1 else ".R"
		k.part(head, "Eye" + tag, ModelKit.blob(Vector3(0.045, 0.04, 0.03), 5, 2), EYE, Vector3(0.085 * side, 0.2, 0.185), Vector3.ZERO, 0.8)
		k.part(head, "Pupil" + tag, ModelKit.blob(Vector3(0.018, 0.02, 0.015), 4, 2), VOID, Vector3(0.085 * side, 0.2, 0.213))
		k.part(head, "Brow" + tag, ModelKit.box(Vector3(0.11, 0.03, 0.04)), VOID, Vector3(0.09 * side, 0.265, 0.185), Vector3(0, 0, -22 * side))
		k.part(head, "Ear" + tag, ModelKit.prism(4, Vector2(0.06, 0.03), Vector2.ZERO, 0.17), SKIN, Vector3(0.22 * side, 0.18, -0.01), Vector3(0, 0, -75 * side))
		k.part(hips, "Shoulder" + tag, ModelKit.blob(Vector3(0.1, 0.09, 0.1), 6, 3), DARK, Vector3(0.3 * side, 0.5, 0))
		var arm := k.joint(hips, "Arm" + tag, Vector3(0.3 * side, 0.48, 0), Vector3(-17, 0, 10 * side))
		k.part(arm, "Arm", ModelKit.prism(4, Vector2(0.085, 0.085), Vector2(0.07, 0.07), 0.5), SKIN, Vector3(0, -0.26, 0))
		var hand := k.joint(arm, "Hand" + tag, Vector3(0, -0.52, 0))
		k.part(hand, "Fist", ModelKit.blob(Vector3(0.1, 0.09, 0.1), 6, 3), SKIN)
		for finger in [-1, 0, 1]:
			k.part(hand, "Claw%d" % finger, ModelKit.prism(4, Vector2(0.022, 0.022), Vector2.ZERO, 0.12), CLAW, Vector3(0.05 * finger, -0.11, 0.02), Vector3(0, 0, 8 * finger))
	BipedClips.animate(k, {"attack": &"punch", "stride": 22.0, "bob": 0.05, "lie": 0.2})
	return k
