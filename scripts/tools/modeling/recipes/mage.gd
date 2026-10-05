extends RefCounted
## The Mage: a violet robe, a wide pointed hat with a bent tip, a white beard, a crystal staff.
## The robe hides the legs down to the boots; the sleeves flare at the wrists.

const ROBE := Color(0.46, 0.34, 0.88)
const ROBE_DARK := Color(0.3, 0.22, 0.66)
const HAT := Color(0.32, 0.24, 0.7)
const GOLD := Color(0.92, 0.76, 0.32)
const LEATHER := Color(0.36, 0.23, 0.15)
const SKIN := Color(0.96, 0.8, 0.68)
const BEARD := Color(0.95, 0.95, 0.97)
const DARK := Color(0.08, 0.06, 0.12)


static func build() -> ModelKit:
	var k := ModelKit.new()
	var rig := k.joint(null, "Rig")
	for side in [1, -1]:
		var tag := ".L" if side == 1 else ".R"
		var leg := k.joint(rig, "Leg" + tag, Vector3(0.09 * side, 0.34, 0))
		k.part(leg, "Trouser", ModelKit.prism(4, Vector2(0.06, 0.07), Vector2(0.055, 0.06), 0.24), ROBE_DARK, Vector3(0, -0.13, 0))
		k.part(leg, "Boot", ModelKit.prism(4, Vector2(0.075, 0.115), Vector2(0.068, 0.085), 0.1), LEATHER, Vector3(0, -0.29, 0.025))
	var hips := k.joint(rig, "Hips", Vector3(0, 0.34, 0))
	k.part(hips, "Robe", ModelKit.prism(6, Vector2(0.29, 0.25), Vector2(0.2, 0.17), 0.46), ROBE, Vector3(0, 0.0, 0))
	k.part(hips, "Hem", ModelKit.prism(6, Vector2(0.3, 0.26), Vector2(0.29, 0.25), 0.05), GOLD, Vector3(0, -0.2, 0))
	k.part(hips, "Chest", ModelKit.prism(6, Vector2(0.19, 0.14), Vector2(0.23, 0.16), 0.3), ROBE, Vector3(0, 0.3, 0))
	k.part(hips, "Belt", ModelKit.prism(6, Vector2(0.2, 0.15), Vector2(0.2, 0.15), 0.05), LEATHER, Vector3(0, 0.19, 0))
	k.part(hips, "Buckle", ModelKit.box(Vector3(0.07, 0.07, 0.03)), GOLD, Vector3(0, 0.19, 0.16))
	k.part(hips, "Mantle", ModelKit.prism(6, Vector2(0.29, 0.21), Vector2(0.17, 0.12), 0.12), ROBE_DARK, Vector3(0, 0.44, 0))
	var head := k.joint(hips, "Head", Vector3(0, 0.5, 0))
	k.part(head, "Face", ModelKit.blob(Vector3(0.17, 0.18, 0.17), 8, 4), SKIN, Vector3(0, 0.15, 0))
	k.part(head, "Nose", ModelKit.blob(Vector3(0.035, 0.04, 0.045), 4, 2), SKIN, Vector3(0, 0.13, 0.18))
	k.part(head, "Beard", ModelKit.prism(4, Vector2(0.14, 0.08), Vector2(0.04, 0.03), 0.26), BEARD, Vector3(0, -0.02, 0.12), Vector3(-10, 0, 0))
	k.part(head, "Moustache", ModelKit.wedge(0.26, 0.07, 0.1, 0.5), BEARD, Vector3(0, 0.08, 0.17))
	for side in [1, -1]:
		k.part(head, "Eye%d" % side, ModelKit.box(Vector3(0.04, 0.045, 0.02)), DARK, Vector3(0.075 * side, 0.19, 0.165))
		k.part(head, "Brow%d" % side, ModelKit.box(Vector3(0.07, 0.025, 0.025)), BEARD, Vector3(0.075 * side, 0.23, 0.165))
	k.part(head, "Brim", ModelKit.prism(8, Vector2(0.33, 0.33), Vector2(0.3, 0.3), 0.04), HAT, Vector3(0, 0.31, -0.035), Vector3(-7, 0, 0))
	k.part(head, "Band", ModelKit.prism(8, Vector2(0.23, 0.23), Vector2(0.22, 0.22), 0.06), GOLD, Vector3(0, 0.36, -0.035), Vector3(-7, 0, 0))
	k.part(head, "Crown", ModelKit.prism(8, Vector2(0.22, 0.22), Vector2(0.12, 0.12), 0.2), HAT, Vector3(0, 0.46, -0.05), Vector3(-10, 0, 0))
	k.part(head, "Tip", ModelKit.prism(6, Vector2(0.12, 0.12), Vector2.ZERO, 0.18), HAT, Vector3(0, 0.65, -0.1), Vector3(-40, 0, 0))
	for side in [1, -1]:
		var tag := ".L" if side == 1 else ".R"
		var arm := k.joint(hips, "Arm" + tag, Vector3(0.27 * side, 0.45, 0))
		k.part(arm, "Sleeve", ModelKit.prism(4, Vector2(0.105, 0.095), Vector2(0.06, 0.06), 0.3), ROBE, Vector3(0, -0.15, 0))
		k.part(arm, "Cuff", ModelKit.prism(4, Vector2(0.108, 0.098), Vector2(0.104, 0.094), 0.04), GOLD, Vector3(0, -0.3, 0))
		var hand := k.joint(arm, "Hand" + tag, Vector3(0, -0.35, 0))
		k.part(hand, "Fist", ModelKit.blob(Vector3(0.055, 0.055, 0.055), 6, 3), SKIN)
	k.joints["Arm.R"].rotation_degrees = Vector3(-15, 0, -5)
	k.joints["Arm.L"].rotation_degrees = Vector3(0, 0, 3)
	BipedClips.animate(k, {"attack": &"swing", "stride": 24.0})
	return k
