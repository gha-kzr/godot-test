extends RefCounted
## The Knight: steel armor, a blue tabard and shield, a red plume. Chunky: the helmet is a third
## of the height.

const STEEL := Color(0.66, 0.7, 0.78)
const DARK_STEEL := Color(0.42, 0.46, 0.55)
const BLUE := Color(0.22, 0.42, 0.88)
const RED := Color(0.8, 0.15, 0.15)
const LEATHER := Color(0.35, 0.22, 0.14)
const VISOR := Color(0.07, 0.07, 0.1)
const SKIN := Color(0.95, 0.78, 0.64)


static func build() -> ModelKit:
	var k := ModelKit.new()
	var rig := k.joint(null, "Rig")
	for side in [1, -1]:  # +X is the left side (the model faces +Z).
		var tag := ".L" if side == 1 else ".R"
		var leg := k.joint(rig, "Leg" + tag, Vector3(0.1 * side, 0.42, 0))
		k.part(leg, "Greave", ModelKit.prism(4, Vector2(0.075, 0.08), Vector2(0.065, 0.065), 0.3), DARK_STEEL, Vector3(0, -0.17, 0))
		k.part(leg, "Boot", ModelKit.prism(4, Vector2(0.085, 0.115), Vector2(0.075, 0.09), 0.1), LEATHER, Vector3(0, -0.37, 0.025))
	var hips := k.joint(rig, "Hips", Vector3(0, 0.42, 0))
	k.part(hips, "Skirt", ModelKit.prism(4, Vector2(0.22, 0.15), Vector2(0.18, 0.125), 0.14), BLUE, Vector3(0, 0.02, 0))
	k.part(hips, "Belt", ModelKit.prism(4, Vector2(0.19, 0.13), Vector2(0.19, 0.13), 0.04), LEATHER, Vector3(0, 0.1, 0))
	k.part(hips, "Torso", ModelKit.prism(4, Vector2(0.19, 0.125), Vector2(0.24, 0.145), 0.34), STEEL, Vector3(0, 0.29, 0))
	k.part(hips, "Tabard", ModelKit.prism(4, Vector2(0.09, 0.012), Vector2(0.12, 0.012), 0.3), BLUE, Vector3(0, 0.27, 0.15))
	var head := k.joint(hips, "Head", Vector3(0, 0.48, 0))
	k.part(head, "Neck", ModelKit.prism(4, Vector2(0.06, 0.06), Vector2(0.06, 0.06), 0.06), DARK_STEEL, Vector3(0, -0.01, 0))
	k.part(head, "Helmet", ModelKit.blob(Vector3(0.2, 0.21, 0.21), 8, 4), STEEL, Vector3(0, 0.2, 0))
	k.part(head, "Visor", ModelKit.box(Vector3(0.3, 0.045, 0.03)), VISOR, Vector3(0, 0.2, 0.185))
	k.part(head, "Plume", ModelKit.wedge(0.06, 0.18, 0.36, 0.15), RED, Vector3(0, 0.44, -0.03))
	for side in [1, -1]:
		var tag := ".L" if side == 1 else ".R"
		k.part(hips, "Pauldron" + tag, ModelKit.blob(Vector3(0.11, 0.075, 0.11), 6, 3), DARK_STEEL, Vector3(0.27 * side, 0.43, 0))
		var arm := k.joint(hips, "Arm" + tag, Vector3(0.28 * side, 0.4, 0))
		k.part(arm, "Sleeve", ModelKit.prism(4, Vector2(0.06, 0.06), Vector2(0.052, 0.052), 0.3), STEEL, Vector3(0, -0.16, 0))
		k.part(arm, "Gauntlet", ModelKit.prism(4, Vector2(0.056, 0.056), Vector2(0.05, 0.05), 0.08), DARK_STEEL, Vector3(0, -0.3, 0))
		var hand := k.joint(arm, "Hand" + tag, Vector3(0, -0.36, 0))
		k.part(hand, "Fist", ModelKit.blob(Vector3(0.06, 0.06, 0.06), 6, 3), SKIN)
	var left_arm := k.joints["Arm.L"]
	k.part(left_arm, "Shield", ModelKit.prism(8, Vector2(0.2, 0.2), Vector2(0.2, 0.2), 0.05), BLUE, Vector3(0.09, -0.16, 0.1), Vector3(90, 0, 0))
	k.part(left_arm, "ShieldRim", ModelKit.prism(8, Vector2(0.22, 0.22), Vector2(0.22, 0.22), 0.03), STEEL, Vector3(0.09, -0.16, 0.086), Vector3(90, 0, 0))
	k.part(left_arm, "ShieldBoss", ModelKit.blob(Vector3(0.07, 0.07, 0.04), 6, 3), STEEL, Vector3(0.09, -0.16, 0.14))
	k.joints["Arm.R"].rotation_degrees = Vector3(-25, 0, -6)
	k.joints["Arm.L"].rotation_degrees = Vector3(0, 0, 4)
	BipedClips.animate(k, {"attack": &"swing"})
	return k
