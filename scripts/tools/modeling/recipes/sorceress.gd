extends RefCounted
## The Sorceress (PvP, female): a slender fire caster, a tiara of three red crystals, a huge faceted
## flame-orange ponytail down to the knees, a black tunic with a tall ember-red collar, a short cape
## on the left shoulder, gold-trimmed skirt panels, tall black boots with gold cuffs. No staff: a
## fire orb floats over her open right palm.

const EMBER := Color(0.82, 0.14, 0.1)
const BLACK := Color(0.24, 0.21, 0.24)
const GOLD := Color(0.96, 0.72, 0.26)
const HAIR := Color(0.98, 0.5, 0.1)
const HAIR_DARK := Color(0.88, 0.38, 0.08)
const SKIN := Color(1.0, 0.76, 0.62)
const CRYSTAL := Color(0.95, 0.16, 0.14)
const FIRE := Color(1.0, 0.55, 0.08)
const FIRE_CORE := Color(1.0, 0.9, 0.3)
const BOOT := Color(0.2, 0.18, 0.2)
const TROUSER := Color(0.3, 0.17, 0.17)
const DARK := Color(0.09, 0.06, 0.05)


static func build() -> ModelKit:
	var k := ModelKit.new()
	var rig := k.joint(null, "Rig")
	for side in [1, -1]:
		var tag := ".L" if side == 1 else ".R"
		var leg := k.joint(rig, "Leg" + tag, Vector3(0.085 * side, 0.4, 0))
		k.part(leg, "Trouser", ModelKit.prism(4, Vector2(0.07, 0.07), Vector2(0.058, 0.058), 0.24), TROUSER, Vector3(0, -0.12, 0))
		k.part(leg, "Boot", ModelKit.prism(4, Vector2(0.075, 0.105), Vector2(0.068, 0.078), 0.22), BOOT, Vector3(0, -0.29, 0.015))
		k.part(leg, "BootCuff", ModelKit.prism(4, Vector2(0.088, 0.092), Vector2(0.088, 0.092), 0.05), GOLD, Vector3(0, -0.19, 0))
	var hips := k.joint(rig, "Hips", Vector3(0, 0.4, 0))
	k.part(hips, "Hip", ModelKit.prism(6, Vector2(0.185, 0.13), Vector2(0.16, 0.115), 0.12), BLACK, Vector3(0, 0.0, 0))
	k.part(hips, "Waist", ModelKit.prism(6, Vector2(0.15, 0.105), Vector2(0.15, 0.105), 0.14), BLACK, Vector3(0, 0.13, 0))
	k.part(hips, "Chest", ModelKit.prism(6, Vector2(0.155, 0.11), Vector2(0.2, 0.135), 0.26), BLACK, Vector3(0, 0.33, 0))
	k.part(hips, "Belt", ModelKit.prism(6, Vector2(0.17, 0.12), Vector2(0.17, 0.12), 0.04), GOLD, Vector3(0, 0.06, 0))
	k.part(hips, "Gem", ModelKit.blob(Vector3(0.035, 0.045, 0.02), 4, 2), CRYSTAL, Vector3(0, 0.38, 0.14), Vector3.ZERO, 0.4)
	# Gold-trimmed skirt panels, front and back.
	for index in 2:
		var z := 0.14 if index == 0 else -0.14
		k.part(hips, "Panel%d" % index, ModelKit.prism(4, Vector2(0.1, 0.02), Vector2(0.14, 0.025), 0.3), BLACK, Vector3(0, -0.1, z), Vector3(18 if index == 0 else -18, 0, 0))
		k.part(hips, "PanelTrim%d" % index, ModelKit.prism(4, Vector2(0.14, 0.03), Vector2(0.145, 0.032), 0.04), GOLD, Vector3(0, -0.24, z + (0.045 if index == 0 else -0.045)), Vector3(18 if index == 0 else -18, 0, 0))
	# The tall ember collar and the short cape on the left shoulder only.
	k.part(hips, "Collar", ModelKit.prism(6, Vector2(0.14, 0.11), Vector2(0.255, 0.19), 0.15), EMBER, Vector3(0, 0.5, -0.02))
	k.part(hips, "CollarBack", ModelKit.prism(4, Vector2(0.2, 0.03), Vector2(0.27, 0.03), 0.22), BLACK, Vector3(0, 0.55, -0.15), Vector3(-12, 0, 0))
	k.part(hips, "Cape", ModelKit.prism(4, Vector2(0.09, 0.03), Vector2(0.13, 0.04), 0.36), EMBER, Vector3(0.22, 0.32, -0.1), Vector3(0, 0, 10))
	var head := k.joint(hips, "Head", Vector3(0, 0.55, 0))
	k.part(head, "Face", ModelKit.blob(Vector3(0.16, 0.17, 0.16), 8, 4), SKIN, Vector3(0, 0.14, 0.02))
	k.part(head, "Hair", ModelKit.blob(Vector3(0.19, 0.19, 0.17), 8, 4), HAIR, Vector3(0, 0.19, -0.06))
	k.part(head, "Fringe", ModelKit.wedge(0.26, 0.06, 0.07, 0.5), HAIR, Vector3(0, 0.29, 0.1), Vector3(-30, 0, 0))
	k.part(head, "Nose", ModelKit.blob(Vector3(0.025, 0.03, 0.035), 4, 2), SKIN, Vector3(0, 0.115, 0.185))
	for side in [1, -1]:
		k.part(head, "Eye%d" % side, ModelKit.box(Vector3(0.045, 0.04, 0.02)), DARK, Vector3(0.07 * side, 0.165, 0.176), Vector3(0, 0, 8 * side))
		k.part(head, "Brow%d" % side, ModelKit.box(Vector3(0.07, 0.022, 0.025)), HAIR_DARK, Vector3(0.07 * side, 0.21, 0.18), Vector3(0, 0, 14 * side))
	k.part(head, "Smirk", ModelKit.box(Vector3(0.06, 0.014, 0.02)), EMBER, Vector3(0.012, 0.065, 0.176), Vector3(0, 0, 8))
	# The tiara: a gold band and three tall red crystals.
	k.part(head, "TiaraBand", ModelKit.prism(8, Vector2(0.19, 0.18), Vector2(0.19, 0.18), 0.035), GOLD, Vector3(0, 0.32, 0.0), Vector3(-12, 0, 0))
	for index in 3:
		var tall := 0.3 if index == 1 else 0.22
		k.part(head, "Crystal%d" % index, ModelKit.prism(4, Vector2(0.045, 0.04), Vector2.ZERO, tall), CRYSTAL,
				Vector3(0.11 * (index - 1), 0.34 + tall * 0.5, 0.07 - 0.03 * absf(index - 1)), Vector3(-8, 0, -22 * (index - 1)), 0.4)
	# The ponytail: a tie high at the back and three faceted flame locks falling to the knees.
	k.part(head, "Tie", ModelKit.prism(6, Vector2(0.06, 0.06), Vector2(0.06, 0.06), 0.04), GOLD, Vector3(0, 0.33, -0.2), Vector3(-30, 0, 0))
	var pony := k.joint(head, "Pony", Vector3(0, 0.3, -0.2))
	k.part(pony, "Mass", ModelKit.blob(Vector3(0.13, 0.14, 0.12), 6, 3), HAIR, Vector3(0, -0.06, -0.05))
	k.part(pony, "Center", ModelKit.prism(5, Vector2.ZERO, Vector2(0.12, 0.075), 0.8), HAIR, Vector3(0, -0.48, -0.12), Vector3(-6, 0, 0))
	for side in [1, -1]:
		k.part(pony, "Lock%d" % side, ModelKit.prism(4, Vector2.ZERO, Vector2(0.09, 0.05), 0.58), HAIR_DARK, Vector3(0.15 * side, -0.34, -0.1), Vector3(-6, 0, 14 * side))
		k.part(pony, "Tip%d" % side, ModelKit.prism(4, Vector2.ZERO, Vector2(0.06, 0.04), 0.3), HAIR_DARK, Vector3(0.27 * side, -0.55, -0.1), Vector3(-6, 0, 24 * side))
	for side in [1, -1]:
		var tag := ".L" if side == 1 else ".R"
		var arm := k.joint(hips, "Arm" + tag, Vector3(0.24 * side, 0.44, 0))
		k.part(arm, "Sleeve", ModelKit.prism(4, Vector2(0.068, 0.068), Vector2(0.058, 0.058), 0.3), BLACK, Vector3(0, -0.15, 0))
		k.part(arm, "Cuff", ModelKit.prism(4, Vector2(0.072, 0.072), Vector2(0.07, 0.07), 0.04), GOLD, Vector3(0, -0.3, 0))
		var hand := k.joint(arm, "Hand" + tag, Vector3(0, -0.34, 0))
		k.part(hand, "Palm", ModelKit.blob(Vector3(0.06, 0.055, 0.06), 6, 3), SKIN)
	# The fire orb hovers over the open right palm (the joint cancels the arm's forward tilt).
	var orb := k.joint(k.joints["Hand.R"], "Orb.R", Vector3(0, 0.0, 0.0), Vector3(40, 0, 0))
	k.part(orb, "Fire", ModelKit.blob(Vector3(0.1, 0.1, 0.1), 7, 3), FIRE, Vector3(0, 0.17, 0.04), Vector3.ZERO, 0.7)
	k.part(orb, "Core", ModelKit.blob(Vector3(0.06, 0.06, 0.06), 6, 3), FIRE_CORE, Vector3(0, 0.17, 0.1), Vector3.ZERO, 1.0)
	k.part(orb, "Flame", ModelKit.prism(4, Vector2(0.06, 0.06), Vector2.ZERO, 0.14), FIRE, Vector3(0, 0.31, 0.04), Vector3.ZERO, 0.7)
	k.joints["Arm.R"].rotation_degrees = Vector3(-40, 0, -8)
	k.joints["Arm.L"].rotation_degrees = Vector3(0, 0, 12)
	BipedClips.animate(k, {"attack": &"swing", "stride": 26.0})
	return k
