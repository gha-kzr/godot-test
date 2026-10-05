extends RefCounted
## The Orc Guard: a hunched green brute in iron plates, tusks, a round shield and a spiked club.

const SKIN := Color(0.46, 0.62, 0.3)
const DARK_SKIN := Color(0.32, 0.45, 0.22)
const IRON := Color(0.38, 0.4, 0.46)
const LIGHT_IRON := Color(0.6, 0.62, 0.68)
const LEATHER := Color(0.4, 0.27, 0.17)
const CLOTH := Color(0.32, 0.25, 0.2)
const IVORY := Color(0.95, 0.92, 0.8)
const CREST := Color(0.2, 0.45, 0.65)
const WOOD := Color(0.5, 0.34, 0.2)
const EYE := Color(1.0, 0.85, 0.2)
const DARK := Color(0.08, 0.07, 0.07)


static func build() -> ModelKit:
	var k := ModelKit.new()
	var rig := k.joint(null, "Rig")
	for side in [1, -1]:
		var tag := ".L" if side == 1 else ".R"
		var leg := k.joint(rig, "Leg" + tag, Vector3(0.13 * side, 0.48, 0))
		k.part(leg, "Trouser", ModelKit.prism(4, Vector2(0.105, 0.11), Vector2(0.09, 0.095), 0.36), CLOTH, Vector3(0, -0.2, 0))
		k.part(leg, "Greave", ModelKit.prism(4, Vector2(0.1, 0.1), Vector2(0.095, 0.1), 0.1), IRON, Vector3(0, -0.33, 0.01))
		k.part(leg, "Foot", ModelKit.prism(4, Vector2(0.115, 0.15), Vector2(0.1, 0.115), 0.09), DARK_SKIN, Vector3(0, -0.435, 0.04))
	var hips := k.joint(rig, "Hips", Vector3(0, 0.48, 0))
	k.part(hips, "Skirt", ModelKit.prism(4, Vector2(0.27, 0.18), Vector2(0.24, 0.165), 0.16), CLOTH, Vector3(0, 0.0, 0))
	k.part(hips, "Belt", ModelKit.prism(4, Vector2(0.255, 0.18), Vector2(0.255, 0.18), 0.06), LEATHER, Vector3(0, 0.09, 0))
	k.part(hips, "Torso", ModelKit.prism(4, Vector2(0.26, 0.17), Vector2(0.36, 0.2), 0.46), SKIN, Vector3(0, 0.31, 0))
	k.part(hips, "Plate", ModelKit.prism(4, Vector2(0.255, 0.04), Vector2(0.33, 0.04), 0.3), IRON, Vector3(0, 0.34, 0.185))
	k.part(hips, "PlateBack", ModelKit.prism(4, Vector2(0.27, 0.04), Vector2(0.34, 0.04), 0.3), IRON, Vector3(0, 0.34, -0.185))
	for rivet in [-1, 1]:
		k.part(hips, "Rivet%d" % rivet, ModelKit.blob(Vector3(0.03, 0.03, 0.02), 4, 2), LIGHT_IRON, Vector3(0.1 * rivet, 0.4, 0.225))
	var head := k.joint(hips, "Head", Vector3(0, 0.56, 0.05))
	k.part(head, "Neck", ModelKit.prism(4, Vector2(0.11, 0.1), Vector2(0.11, 0.1), 0.08), DARK_SKIN, Vector3(0, 0.0, 0))
	k.part(head, "Skull", ModelKit.blob(Vector3(0.22, 0.19, 0.22), 8, 4), SKIN, Vector3(0, 0.16, 0.03))
	k.part(head, "Jaw", ModelKit.prism(4, Vector2(0.13, 0.075), Vector2(0.15, 0.1), 0.1), SKIN, Vector3(0, 0.03, 0.15))
	k.part(head, "BrowRidge", ModelKit.box(Vector3(0.3, 0.05, 0.07)), DARK_SKIN, Vector3(0, 0.21, 0.17))
	k.part(head, "Crest", ModelKit.wedge(0.07, 0.17, 0.32, 0.5), CREST, Vector3(0, 0.35, 0.0))
	k.part(head, "Mouth", ModelKit.box(Vector3(0.14, 0.025, 0.02)), DARK, Vector3(0, 0.05, 0.255))
	for side in [1, -1]:
		var tag := ".L" if side == 1 else ".R"
		k.part(head, "Eye" + tag, ModelKit.blob(Vector3(0.035, 0.025, 0.02), 4, 2), EYE, Vector3(0.085 * side, 0.18, 0.205), Vector3.ZERO, 0.6)
		k.part(head, "Tusk" + tag, ModelKit.prism(4, Vector2(0.032, 0.032), Vector2.ZERO, 0.15), IVORY, Vector3(0.075 * side, 0.12, 0.235), Vector3(18, 0, -6 * side))
		k.part(head, "Ear" + tag, ModelKit.prism(4, Vector2(0.06, 0.03), Vector2.ZERO, 0.24), SKIN, Vector3(0.28 * side, 0.2, -0.02), Vector3(0, 0, -75 * side))
		k.part(hips, "Pauldron" + tag, ModelKit.prism(6, Vector2(0.15, 0.15), Vector2(0.09, 0.09), 0.14), IRON, Vector3(0.4 * side, 0.54, 0))
		k.part(hips, "PauldronSpike" + tag, ModelKit.prism(4, Vector2(0.05, 0.05), Vector2.ZERO, 0.15), LIGHT_IRON, Vector3(0.41 * side, 0.66, 0), Vector3(0, 0, -12 * side))
		var arm := k.joint(hips, "Arm" + tag, Vector3(0.4 * side, 0.46, 0))
		k.part(arm, "Bicep", ModelKit.prism(4, Vector2(0.095, 0.095), Vector2(0.075, 0.075), 0.34), SKIN, Vector3(0, -0.18, 0))
		k.part(arm, "Bracer", ModelKit.prism(4, Vector2(0.085, 0.085), Vector2(0.08, 0.08), 0.1), IRON, Vector3(0, -0.3, 0))
		var hand := k.joint(arm, "Hand" + tag, Vector3(0, -0.38, 0))
		k.part(hand, "Fist", ModelKit.blob(Vector3(0.09, 0.085, 0.09), 6, 3), DARK_SKIN)
	var left_arm := k.joints["Arm.L"]
	k.part(left_arm, "Shield", ModelKit.prism(8, Vector2(0.27, 0.27), Vector2(0.27, 0.27), 0.06), WOOD, Vector3(0.12, -0.2, 0.15), Vector3(90, 0, 0))
	k.part(left_arm, "ShieldRim", ModelKit.prism(8, Vector2(0.295, 0.295), Vector2(0.295, 0.295), 0.04), IRON, Vector3(0.12, -0.2, 0.14), Vector3(90, 0, 0))
	k.part(left_arm, "ShieldBoss", ModelKit.prism(6, Vector2(0.09, 0.09), Vector2(0.03, 0.03), 0.1), LIGHT_IRON, Vector3(0.12, -0.2, 0.22), Vector3(90, 0, 0))
	k.part(left_arm, "ShieldBar", ModelKit.box(Vector3(0.5, 0.05, 0.015)), IRON, Vector3(0.12, -0.2, 0.184))
	# Hunched: the whole upper body leans forward, the head sits low between the shoulders.
	k.joints["Hips"].rotation_degrees = Vector3(14, 0, 0)
	k.joints["Head"].rotation_degrees = Vector3(-12, 0, 0)
	k.joints["Arm.R"].rotation_degrees = Vector3(-22, 0, -6)
	k.joints["Arm.L"].rotation_degrees = Vector3(-28, 0, 6)
	BipedClips.animate(k, {"attack": &"swing", "stride": 24.0, "bob": 0.05, "lie": 0.2})
	return k
