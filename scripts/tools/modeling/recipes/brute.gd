extends RefCounted
## The Brute: a bare-chested Viking with a horned helmet, a red beard, a fur pelt and a big axe.

const SKIN := Color(0.9, 0.68, 0.52)
const PANTS := Color(0.3, 0.22, 0.17)
const LEATHER := Color(0.4, 0.26, 0.16)
const FUR := Color(0.55, 0.36, 0.22)
const STEEL := Color(0.52, 0.55, 0.62)
const HORN := Color(0.95, 0.9, 0.78)
const BEARD := Color(0.62, 0.28, 0.16)
const GOLD := Color(0.9, 0.75, 0.3)
const DARK := Color(0.08, 0.06, 0.07)


static func build() -> ModelKit:
	var k := ModelKit.new()
	var rig := k.joint(null, "Rig")
	for side in [1, -1]:
		var tag := ".L" if side == 1 else ".R"
		var leg := k.joint(rig, "Leg" + tag, Vector3(0.115 * side, 0.45, 0))
		k.part(leg, "Trouser", ModelKit.prism(4, Vector2(0.095, 0.1), Vector2(0.08, 0.085), 0.34), PANTS, Vector3(0, -0.19, 0))
		k.part(leg, "Boot", ModelKit.prism(4, Vector2(0.105, 0.14), Vector2(0.095, 0.105), 0.12), LEATHER, Vector3(0, -0.39, 0.03))
		k.part(leg, "BootFur", ModelKit.prism(4, Vector2(0.115, 0.115), Vector2(0.115, 0.115), 0.05), FUR, Vector3(0, -0.29, 0))
	var hips := k.joint(rig, "Hips", Vector3(0, 0.45, 0))
	k.part(hips, "Waist", ModelKit.prism(4, Vector2(0.23, 0.15), Vector2(0.2, 0.14), 0.16), PANTS, Vector3(0, 0.0, 0))
	k.part(hips, "Belt", ModelKit.prism(4, Vector2(0.22, 0.155), Vector2(0.22, 0.155), 0.06), LEATHER, Vector3(0, 0.09, 0))
	k.part(hips, "Buckle", ModelKit.box(Vector3(0.09, 0.07, 0.03)), GOLD, Vector3(0, 0.09, 0.16))
	k.part(hips, "Torso", ModelKit.prism(4, Vector2(0.22, 0.14), Vector2(0.31, 0.175), 0.44), SKIN, Vector3(0, 0.32, 0))
	k.part(hips, "Pelt", ModelKit.prism(4, Vector2(0.25, 0.16), Vector2(0.33, 0.19), 0.17), FUR, Vector3(0, 0.5, -0.005))
	k.part(hips, "Strap", ModelKit.prism(4, Vector2(0.03, 0.01), Vector2(0.03, 0.01), 0.4), LEATHER, Vector3(0.1, 0.3, 0.178), Vector3(0, 0, 28))
	var head := k.joint(hips, "Head", Vector3(0, 0.56, 0.02))
	k.part(head, "Neck", ModelKit.prism(4, Vector2(0.09, 0.08), Vector2(0.09, 0.08), 0.07), SKIN, Vector3(0, 0.0, 0))
	k.part(head, "Face", ModelKit.blob(Vector3(0.2, 0.19, 0.2), 8, 4), SKIN, Vector3(0, 0.14, 0.0))
	k.part(head, "Helmet", ModelKit.blob(Vector3(0.225, 0.15, 0.225), 8, 3), STEEL, Vector3(0, 0.31, -0.01))
	k.part(head, "Rim", ModelKit.prism(8, Vector2(0.225, 0.225), Vector2(0.225, 0.225), 0.04), LEATHER, Vector3(0, 0.25, -0.01))
	k.part(head, "NoseGuard", ModelKit.box(Vector3(0.045, 0.14, 0.03)), STEEL, Vector3(0, 0.2, 0.205))
	k.part(head, "Nose", ModelKit.wedge(0.07, 0.07, 0.1, 0.9), SKIN, Vector3(0, 0.12, 0.2))
	k.part(head, "Moustache", ModelKit.box(Vector3(0.22, 0.045, 0.05)), BEARD, Vector3(0, 0.06, 0.18))
	k.part(head, "Beard", ModelKit.prism(4, Vector2(0.15, 0.06), Vector2(0.06, 0.035), 0.2), BEARD, Vector3(0, -0.05, 0.14), Vector3(-10, 0, 0))
	for side in [1, -1]:
		var tag := ".L" if side == 1 else ".R"
		k.part(head, "Eye" + tag, ModelKit.box(Vector3(0.05, 0.03, 0.02)), DARK, Vector3(0.075 * side, 0.165, 0.195))
		k.part(head, "Brow" + tag, ModelKit.box(Vector3(0.08, 0.025, 0.03)), BEARD, Vector3(0.075 * side, 0.2, 0.2), Vector3(0, 0, -12 * side))
		k.part(head, "HornBase" + tag, ModelKit.prism(4, Vector2(0.06, 0.06), Vector2(0.04, 0.04), 0.22), HORN, Vector3(0.29 * side, 0.34, 0), Vector3(0, 0, -58 * side))
		k.part(head, "HornTip" + tag, ModelKit.prism(4, Vector2(0.04, 0.04), Vector2.ZERO, 0.22), HORN, Vector3(0.41 * side, 0.46, 0), Vector3(0, 0, -20 * side))
		k.part(hips, "ShoulderFur" + tag, ModelKit.blob(Vector3(0.13, 0.1, 0.13), 6, 3), FUR, Vector3(0.35 * side, 0.55, 0))
		var arm := k.joint(hips, "Arm" + tag, Vector3(0.37 * side, 0.5, 0))
		k.part(arm, "Bicep", ModelKit.prism(4, Vector2(0.085, 0.085), Vector2(0.07, 0.07), 0.36), SKIN, Vector3(0, -0.19, 0))
		k.part(arm, "Bracer", ModelKit.prism(4, Vector2(0.08, 0.08), Vector2(0.075, 0.075), 0.12), LEATHER, Vector3(0, -0.31, 0))
		var hand := k.joint(arm, "Hand" + tag, Vector3(0, -0.4, 0))
		k.part(hand, "Fist", ModelKit.blob(Vector3(0.085, 0.085, 0.085), 6, 3), SKIN)
	k.joints["Arm.R"].rotation_degrees = Vector3(-25, 0, -6)
	BipedClips.animate(k, {"attack": &"swing", "stride": 26.0, "bob": 0.06, "lie": 0.18})
	return k
