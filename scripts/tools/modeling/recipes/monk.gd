extends RefCounted
## The Monk (PvP): broad and calm, a bald head with a pointed goatee, a saffron sleeveless robe over
## a bare chest, a deep-red sash, loose cream trousers, wrapped forearms and fists, a necklace of
## big wooden beads. A long wooden staff in the right hand, a wrapped fist held low on the left.

const ORANGE := Color(1.0, 0.64, 0.14)
const ORANGE_DARK := Color(0.88, 0.5, 0.1)
const RED := Color(0.64, 0.1, 0.2)
const CREAM := Color(0.97, 0.92, 0.74)
const SKIN := Color(0.9, 0.64, 0.4)
const WOOD := Color(0.6, 0.4, 0.2)
const BEAD := Color(0.5, 0.32, 0.16)
const SANDAL := Color(0.4, 0.26, 0.14)
const DARK := Color(0.1, 0.06, 0.04)


static func build() -> ModelKit:
	var k := ModelKit.new()
	var rig := k.joint(null, "Rig")
	for side in [1, -1]:
		var tag := ".L" if side == 1 else ".R"
		var leg := k.joint(rig, "Leg" + tag, Vector3(0.1 * side, 0.4, 0))
		k.part(leg, "Trouser", ModelKit.prism(6, Vector2(0.115, 0.115), Vector2(0.09, 0.09), 0.3), CREAM, Vector3(0, -0.12, 0))
		k.part(leg, "Wrap", ModelKit.prism(4, Vector2(0.07, 0.07), Vector2(0.075, 0.075), 0.08), CREAM, Vector3(0, -0.3, 0))
		k.part(leg, "Foot", ModelKit.prism(4, Vector2(0.075, 0.115), Vector2(0.07, 0.09), 0.06), SKIN, Vector3(0, -0.37, 0.025))
		k.part(leg, "Sole", ModelKit.prism(4, Vector2(0.08, 0.12), Vector2(0.08, 0.12), 0.025), SANDAL, Vector3(0, -0.395, 0.025))
	var hips := k.joint(rig, "Hips", Vector3(0, 0.4, 0))
	k.part(hips, "Pelvis", ModelKit.prism(6, Vector2(0.22, 0.15), Vector2(0.2, 0.14), 0.12), CREAM, Vector3(0, 0.0, 0))
	k.part(hips, "Sash", ModelKit.prism(6, Vector2(0.22, 0.155), Vector2(0.22, 0.155), 0.11), RED, Vector3(0, 0.1, 0))
	for end in [-1, 1]:
		k.part(hips, "SashEnd%d" % end, ModelKit.box(Vector3(0.06, 0.26, 0.025)), RED, Vector3(0.12 + 0.05 * end, -0.08, 0.17), Vector3(0, 0, 6 * end))
	k.part(hips, "Torso", ModelKit.prism(6, Vector2(0.2, 0.14), Vector2(0.29, 0.17), 0.38), SKIN, Vector3(0, 0.34, 0))
	# The open robe: a back and sides, and two front panels leaving the chest bare.
	k.part(hips, "RobeBack", ModelKit.prism(4, Vector2(0.24, 0.04), Vector2(0.3, 0.05), 0.4), ORANGE, Vector3(0, 0.32, -0.12))
	for side in [1, -1]:
		k.part(hips, "Panel%d" % side, ModelKit.prism(4, Vector2(0.06, 0.03), Vector2(0.075, 0.035), 0.4), ORANGE, Vector3(0.18 * side, 0.32, 0.14), Vector3(0, 0, -4 * side))
		k.part(hips, "Skirt%d" % side, ModelKit.prism(4, Vector2(0.09, 0.03), Vector2(0.075, 0.03), 0.18), ORANGE_DARK, Vector3(0.15 * side, -0.02, 0.15))
		k.part(hips, "Shoulder%d" % side, ModelKit.blob(Vector3(0.12, 0.09, 0.14), 6, 3), ORANGE, Vector3(0.26 * side, 0.5, -0.01))
	k.part(hips, "SkirtBack", ModelKit.prism(4, Vector2(0.22, 0.03), Vector2(0.2, 0.03), 0.2), ORANGE_DARK, Vector3(0, -0.02, -0.14))
	# The big round beads.
	for index in 11:
		var angle := -PI * 0.9 + PI * 1.8 * index / 10.0
		var depth := 0.16 + 0.04 * cos(angle)
		k.part(hips, "Bead%d" % index, ModelKit.blob(Vector3(0.05, 0.05, 0.05), 6, 3), BEAD,
				Vector3(sin(angle) * 0.2, 0.55 - 0.06 * maxf(0.0, cos(angle)), cos(angle) * depth * 0.95))
	var head := k.joint(hips, "Head", Vector3(0, 0.52, 0))
	k.part(head, "Skull", ModelKit.blob(Vector3(0.17, 0.2, 0.17), 8, 4), SKIN, Vector3(0, 0.17, 0))
	k.part(head, "Jaw", ModelKit.blob(Vector3(0.14, 0.09, 0.14), 6, 3), SKIN, Vector3(0, 0.06, 0.03))
	k.part(head, "Nose", ModelKit.blob(Vector3(0.035, 0.045, 0.045), 4, 2), SKIN, Vector3(0, 0.14, 0.17))
	k.part(head, "Goatee", ModelKit.prism(4, Vector2(0.045, 0.035), Vector2.ZERO, 0.12), DARK, Vector3(0, 0.0, 0.14), Vector3(180, 0, 0))
	for side in [1, -1]:
		k.part(head, "Eye%d" % side, ModelKit.box(Vector3(0.035, 0.035, 0.02)), DARK, Vector3(0.07 * side, 0.165, 0.169))
		k.part(head, "Brow%d" % side, ModelKit.box(Vector3(0.08, 0.016, 0.02)), DARK, Vector3(0.07 * side, 0.232, 0.17), Vector3(0, 0, -10 * side))
		k.part(head, "Ear%d" % side, ModelKit.blob(Vector3(0.03, 0.05, 0.03), 4, 2), SKIN, Vector3(0.17 * side, 0.16, 0.0))
	for side in [1, -1]:
		var tag := ".L" if side == 1 else ".R"
		var arm := k.joint(hips, "Arm" + tag, Vector3(0.31 * side, 0.5, 0))
		k.part(arm, "Upper", ModelKit.prism(6, Vector2(0.095, 0.095), Vector2(0.08, 0.08), 0.22), SKIN, Vector3(0, -0.11, 0))
		k.part(arm, "Wrap", ModelKit.prism(6, Vector2(0.085, 0.085), Vector2(0.09, 0.09), 0.2), CREAM, Vector3(0, -0.31, 0))
		var hand := k.joint(arm, "Hand" + tag, Vector3(0, -0.43, 0))
		k.part(hand, "Fist", ModelKit.blob(Vector3(0.085, 0.08, 0.085), 6, 3), CREAM)
	# The staff, taller than the monk, planted beside him: tilted back to stand upright.
	var staff := k.joint(k.joints["Hand.R"], "Staff.R", Vector3.ZERO, Vector3(10, 0, 0))
	k.part(staff, "Pole", ModelKit.prism(6, Vector2(0.035, 0.035), Vector2(0.035, 0.035), 1.55), WOOD, Vector3(0, 0.25, 0))
	k.part(staff, "TipBand", ModelKit.prism(6, Vector2(0.04, 0.04), Vector2(0.04, 0.04), 0.05), BEAD, Vector3(0, 0.95, 0))
	k.part(staff, "FootBand", ModelKit.prism(6, Vector2(0.04, 0.04), Vector2(0.04, 0.04), 0.05), BEAD, Vector3(0, -0.45, 0))
	k.joints["Arm.R"].rotation_degrees = Vector3(-8, 0, -10)
	k.joints["Arm.L"].rotation_degrees = Vector3(-22, 0, 10)
	BipedClips.animate(k, {"attack": &"punch", "stride": 30.0, "bob": 0.04})
	return k
