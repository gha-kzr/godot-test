extends RefCounted
## The Rogue (PvP, female): a slim assassin in a deep teal hooded cloak, a crimson scarf over the
## lower face with a long tail streaming behind, dark leather armour, a curved dagger in the right
## hand and a second one sheathed at the left hip. Narrower waist, wider hips than the male heroes.

const CLOAK := Color(0.2, 0.46, 0.48)
const CLOAK_DARK := Color(0.14, 0.34, 0.37)
const LEATHER := Color(0.3, 0.26, 0.26)
const TROUSER := Color(0.2, 0.2, 0.24)
const BOOT := Color(0.36, 0.25, 0.2)
const SCARF := Color(0.78, 0.14, 0.3)
const SILVER := Color(0.88, 0.9, 0.96)
const SKIN := Color(1.0, 0.78, 0.62)
const HAIR := Color(0.55, 0.34, 0.18)
const DARK := Color(0.08, 0.07, 0.07)


static func build() -> ModelKit:
	var k := ModelKit.new()
	var rig := k.joint(null, "Rig")
	for side in [1, -1]:
		var tag := ".L" if side == 1 else ".R"
		var leg := k.joint(rig, "Leg" + tag, Vector3(0.09 * side, 0.4, 0))
		k.part(leg, "Trouser", ModelKit.prism(4, Vector2(0.075, 0.075), Vector2(0.06, 0.06), 0.26), TROUSER, Vector3(0, -0.14, 0))
		k.part(leg, "Boot", ModelKit.prism(4, Vector2(0.08, 0.115), Vector2(0.07, 0.08), 0.17), BOOT, Vector3(0, -0.32, 0.02))
		k.part(leg, "Cuff", ModelKit.prism(4, Vector2(0.088, 0.09), Vector2(0.088, 0.09), 0.045), LEATHER, Vector3(0, -0.24, 0))
	var hips := k.joint(rig, "Hips", Vector3(0, 0.4, 0))
	k.part(hips, "Hip", ModelKit.prism(6, Vector2(0.2, 0.14), Vector2(0.17, 0.12), 0.14), TROUSER, Vector3(0, 0.0, 0))
	k.part(hips, "Waist", ModelKit.prism(6, Vector2(0.155, 0.11), Vector2(0.15, 0.108), 0.14), LEATHER, Vector3(0, 0.13, 0))
	k.part(hips, "Chest", ModelKit.prism(6, Vector2(0.16, 0.115), Vector2(0.205, 0.14), 0.26), LEATHER, Vector3(0, 0.33, 0))
	k.part(hips, "Belt", ModelKit.prism(6, Vector2(0.185, 0.13), Vector2(0.185, 0.13), 0.05), DARK, Vector3(0, 0.07, 0))
	k.part(hips, "Buckle", ModelKit.box(Vector3(0.055, 0.055, 0.03)), SILVER, Vector3(0, 0.07, 0.135))
	for side in [1, -1]:
		k.part(hips, "Pouch%d" % side, ModelKit.box(Vector3(0.07, 0.08, 0.05)), BOOT, Vector3(0.13 * side, 0.03, 0.1), Vector3(0, 12 * side, 0))
	# The cloak: a collar around the shoulders and a longer panel down the back.
	k.part(hips, "Collar", ModelKit.prism(6, Vector2(0.21, 0.17), Vector2(0.24, 0.2), 0.1), CLOAK, Vector3(0, 0.46, -0.01))
	k.part(hips, "Cape", ModelKit.prism(4, Vector2(0.2, 0.025), Vector2(0.28, 0.025), 0.62), CLOAK, Vector3(0.0, 0.2, -0.16), Vector3(6, 0, 0))
	k.part(hips, "CapeSide", ModelKit.prism(4, Vector2(0.03, 0.12), Vector2(0.03, 0.17), 0.4), CLOAK_DARK, Vector3(0.27, 0.27, -0.06), Vector3(0, 0, 12))
	# The scarf: a thick wrap round the neck and a long tail streaming back.
	k.part(hips, "ScarfWrap", ModelKit.prism(6, Vector2(0.21, 0.17), Vector2(0.23, 0.19), 0.08), SCARF, Vector3(0, 0.5, 0.0))
	k.part(hips, "ScarfTail", ModelKit.box(Vector3(0.1, 0.035, 0.46)), SCARF, Vector3(0.11, 0.5, -0.35), Vector3(-10, -16, 8))
	k.part(hips, "ScarfTip", ModelKit.wedge(0.1, 0.035, 0.14, 0.0), SCARF, Vector3(0.18, 0.54, -0.61), Vector3(-10, -16, 8))
	# The dagger sheathed on the left hip.
	var sheath := k.joint(hips, "Sheath.L", Vector3(0.2, 0.0, 0.0), Vector3(0, 0, 14))
	k.part(sheath, "Scabbard", ModelKit.prism(4, Vector2(0.025, 0.04), Vector2(0.015, 0.025), 0.22), DARK, Vector3(0, -0.08, 0))
	k.part(sheath, "Pommel", ModelKit.prism(4, Vector2(0.025, 0.035), Vector2(0.025, 0.035), 0.1), BOOT, Vector3(0, 0.08, 0))
	var head := k.joint(hips, "Head", Vector3(0, 0.5, 0))
	k.part(head, "Face", ModelKit.blob(Vector3(0.16, 0.17, 0.16), 8, 4), SKIN, Vector3(0, 0.15, 0.015))
	k.part(head, "Mask", ModelKit.blob(Vector3(0.15, 0.085, 0.1), 7, 3), SCARF, Vector3(0, 0.07, 0.085))
	k.part(head, "MaskChin", ModelKit.wedge(0.14, 0.07, 0.1, 1.0), SCARF, Vector3(0, 0.0, 0.1), Vector3(180, 0, 0))
	for side in [1, -1]:
		k.part(head, "Eye%d" % side, ModelKit.box(Vector3(0.05, 0.05, 0.02)), DARK, Vector3(0.07 * side, 0.19, 0.17))
		k.part(head, "Brow%d" % side, ModelKit.box(Vector3(0.075, 0.022, 0.025)), HAIR, Vector3(0.07 * side, 0.235, 0.172), Vector3(0, 0, 18 * side))
	k.part(head, "Hood", ModelKit.blob(Vector3(0.21, 0.21, 0.2), 8, 4), CLOAK, Vector3(0, 0.21, -0.07))
	k.part(head, "HoodPeak", ModelKit.prism(6, Vector2(0.14, 0.14), Vector2.ZERO, 0.16), CLOAK, Vector3(0, 0.4, -0.15), Vector3(-58, 0, 0))
	# A short ponytail sticking out of the back of the hood.
	k.part(head, "Ponytail", ModelKit.prism(4, Vector2(0.055, 0.055), Vector2(0.03, 0.03), 0.22), HAIR, Vector3(0, 0.13, -0.3), Vector3(-155, 0, 0))
	for side in [1, -1]:
		var tag := ".L" if side == 1 else ".R"
		var arm := k.joint(hips, "Arm" + tag, Vector3(0.25 * side, 0.43, 0))
		k.part(arm, "Sleeve", ModelKit.prism(4, Vector2(0.065, 0.065), Vector2(0.058, 0.058), 0.2), SKIN, Vector3(0, -0.1, 0))
		k.part(arm, "Bracer", ModelKit.prism(4, Vector2(0.07, 0.07), Vector2(0.062, 0.062), 0.16), LEATHER, Vector3(0, -0.27, 0))
		var hand := k.joint(arm, "Hand" + tag, Vector3(0, -0.35, 0))
		k.part(hand, "Fist", ModelKit.blob(Vector3(0.06, 0.06, 0.06), 6, 3), LEATHER)
	# The curved dagger in the right hand, pointing forward and up from the hanging arm.
	var grip := k.joint(k.joints["Hand.R"], "Grip.R", Vector3.ZERO, Vector3(55, 0, 0))
	k.part(grip, "Handle", ModelKit.prism(4, Vector2(0.026, 0.026), Vector2(0.022, 0.022), 0.12), DARK, Vector3(0, 0.0, 0))
	k.part(grip, "Guard", ModelKit.box(Vector3(0.09, 0.025, 0.04)), SILVER, Vector3(0, 0.07, 0))
	k.part(grip, "BladeBase", ModelKit.prism(4, Vector2(0.015, 0.032), Vector2(0.012, 0.03), 0.14), SILVER, Vector3(0, 0.15, 0))
	k.part(grip, "BladeTip", ModelKit.prism(4, Vector2(0.012, 0.03), Vector2.ZERO, 0.14), SILVER, Vector3(0, 0.295, 0.025), Vector3(18, 0, 0))
	k.joints["Arm.R"].rotation_degrees = Vector3(-25, 0, -6)
	k.joints["Arm.L"].rotation_degrees = Vector3(0, 0, 5)
	BipedClips.animate(k, {"attack": &"punch", "stride": 32.0})
	return k
