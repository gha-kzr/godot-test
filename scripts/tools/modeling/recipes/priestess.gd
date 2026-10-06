extends RefCounted
## The Priestess (PvP, female): a long ivory robe with golden trim, a pale-blue sash, a short cape,
## a tall mitre with a sun emblem and a floating golden halo, a long braid down the back. A sun
## staff in the right hand, a small closed book at the left hip.

const IVORY := Color(0.94, 0.92, 0.84)
const IVORY_DARK := Color(0.8, 0.78, 0.7)
const GOLD := Color(0.97, 0.74, 0.2)
const SKY := Color(0.62, 0.8, 0.94)
const SKIN := Color(1.0, 0.8, 0.68)
const HAIR := Color(0.52, 0.42, 0.22)
const SANDAL := Color(0.5, 0.38, 0.22)
const WOOD := Color(0.58, 0.5, 0.24)
const BOOK := Color(0.62, 0.36, 0.26)
const DARK := Color(0.1, 0.07, 0.07)


static func build() -> ModelKit:
	var k := ModelKit.new()
	var rig := k.joint(null, "Rig")
	for side in [1, -1]:
		var tag := ".L" if side == 1 else ".R"
		var leg := k.joint(rig, "Leg" + tag, Vector3(0.085 * side, 0.34, 0))
		k.part(leg, "Shin", ModelKit.prism(4, Vector2(0.05, 0.055), Vector2(0.045, 0.05), 0.2), SKIN, Vector3(0, -0.14, 0))
		k.part(leg, "Sandal", ModelKit.prism(4, Vector2(0.07, 0.115), Vector2(0.065, 0.1), 0.05), SANDAL, Vector3(0, -0.3, 0.03))
	var hips := k.joint(rig, "Hips", Vector3(0, 0.34, 0))
	k.part(hips, "Robe", ModelKit.prism(8, Vector2(0.27, 0.23), Vector2(0.17, 0.15), 0.46), IVORY, Vector3(0, 0.0, 0))
	k.part(hips, "Hem", ModelKit.prism(8, Vector2(0.285, 0.245), Vector2(0.275, 0.235), 0.06), GOLD, Vector3(0, -0.2, 0))
	k.part(hips, "Chest", ModelKit.prism(6, Vector2(0.16, 0.12), Vector2(0.21, 0.145), 0.3), IVORY, Vector3(0, 0.3, 0))
	k.part(hips, "Sash", ModelKit.prism(6, Vector2(0.2, 0.15), Vector2(0.2, 0.15), 0.09), SKY, Vector3(0, 0.17, 0))
	for end in [-1, 1]:
		k.part(hips, "SashEnd%d" % end, ModelKit.box(Vector3(0.06, 0.22, 0.025)), SKY, Vector3(0.06 + 0.04 * end, 0.04, 0.19), Vector3(0, 0, 8 * end))
	# The cape: a short mantle over the shoulders, trimmed in gold, held by a clasp.
	k.part(hips, "Cape", ModelKit.prism(8, Vector2(0.29, 0.22), Vector2(0.19, 0.14), 0.16), IVORY, Vector3(0, 0.4, 0))
	k.part(hips, "CapeTrim", ModelKit.prism(8, Vector2(0.295, 0.225), Vector2(0.285, 0.215), 0.03), GOLD, Vector3(0, 0.32, 0))
	k.part(hips, "Clasp", ModelKit.blob(Vector3(0.04, 0.04, 0.025), 5, 2), GOLD, Vector3(0, 0.43, 0.2))
	# The braid down the back.
	for index in 4:
		k.part(hips, "Braid%d" % index, ModelKit.blob(Vector3(0.05, 0.065, 0.05), 6, 3), HAIR, Vector3(0, 0.5 - 0.12 * index, -0.2 - 0.01 * index))
	k.part(hips, "BraidTie", ModelKit.blob(Vector3(0.04, 0.03, 0.04), 5, 2), SKY, Vector3(0, 0.0, -0.225))
	var head := k.joint(hips, "Head", Vector3(0, 0.5, 0))
	k.part(head, "Face", ModelKit.blob(Vector3(0.17, 0.18, 0.17), 8, 4), SKIN, Vector3(0, 0.15, 0.0))
	k.part(head, "Hair", ModelKit.blob(Vector3(0.19, 0.19, 0.15), 8, 4), HAIR, Vector3(0, 0.17, -0.1))
	k.part(head, "Nose", ModelKit.blob(Vector3(0.025, 0.03, 0.035), 4, 2), SKIN, Vector3(0, 0.12, 0.17))
	k.part(head, "Smile", ModelKit.box(Vector3(0.07, 0.015, 0.02)), BOOK, Vector3(0, 0.065, 0.163))
	for side in [1, -1]:
		k.part(head, "Eye%d" % side, ModelKit.box(Vector3(0.045, 0.06, 0.02)), DARK, Vector3(0.07 * side, 0.165, 0.168))
	# The mitre: a tall ivory crown with a gold band and a sun emblem on the front.
	k.part(head, "Mitre", ModelKit.prism(4, Vector2(0.15, 0.13), Vector2(0.13, 0.115), 0.27), IVORY, Vector3(0, 0.45, -0.03))
	k.part(head, "MitreBand", ModelKit.prism(4, Vector2(0.155, 0.135), Vector2(0.155, 0.135), 0.045), GOLD, Vector3(0, 0.34, -0.03))
	k.part(head, "MitreTop", ModelKit.prism(4, Vector2(0.134, 0.12), Vector2(0.134, 0.12), 0.03), GOLD, Vector3(0, 0.59, -0.03))
	k.part(head, "Sun", ModelKit.blob(Vector3(0.045, 0.045, 0.02), 6, 3), GOLD, Vector3(0, 0.46, 0.098))
	# The halo: a ring of twelve golden bars standing behind the head.
	for index in 12:
		var angle := TAU * index / 12.0
		k.part(head, "Halo%d" % index, ModelKit.box(Vector3(0.15, 0.045, 0.035)), GOLD,
				Vector3(cos(angle) * 0.28, 0.42 + sin(angle) * 0.28, -0.2), Vector3(0, 0, rad_to_deg(angle) + 90.0), 0.25)
	for side in [1, -1]:
		var tag := ".L" if side == 1 else ".R"
		var arm := k.joint(hips, "Arm" + tag, Vector3(0.265 * side, 0.45, 0))
		k.part(arm, "Sleeve", ModelKit.prism(4, Vector2(0.095, 0.09), Vector2(0.06, 0.06), 0.3), IVORY, Vector3(0, -0.15, 0))
		k.part(arm, "Cuff", ModelKit.prism(4, Vector2(0.1, 0.095), Vector2(0.095, 0.09), 0.05), GOLD, Vector3(0, -0.3, 0))
		var hand := k.joint(arm, "Hand" + tag, Vector3(0, -0.35, 0))
		k.part(hand, "Fist", ModelKit.blob(Vector3(0.055, 0.055, 0.055), 6, 3), SKIN)
	# The sun staff: tilted back to stand upright over the arm's rest tilt.
	var staff := k.joint(k.joints["Hand.R"], "Staff.R", Vector3.ZERO, Vector3(15, 0, 0))
	k.part(staff, "Pole", ModelKit.prism(6, Vector2(0.028, 0.028), Vector2(0.024, 0.024), 1.4), WOOD, Vector3(0, 0.3, 0))
	k.part(staff, "SunDisc", ModelKit.prism(8, Vector2(0.11, 0.11), Vector2(0.11, 0.11), 0.045), GOLD, Vector3(0, 1.15, 0), Vector3(90, 0, 0), 0.3)
	for index in 8:
		var angle := TAU * index / 8.0
		k.part(staff, "Ray%d" % index, ModelKit.prism(4, Vector2(0.035, 0.012), Vector2.ZERO, 0.1), GOLD,
				Vector3(cos(angle) * 0.16, 1.15 + sin(angle) * 0.16, 0), Vector3(0, 0, rad_to_deg(angle) - 90.0), 0.3)
	# The small closed book held against the left hip.
	var book := k.joint(k.joints["Hand.L"], "Book.L", Vector3(0.0, 0.0, 0.0))
	k.part(book, "Cover", ModelKit.box(Vector3(0.11, 0.15, 0.04)), BOOK, Vector3(0, 0.03, 0.06))
	k.part(book, "Pages", ModelKit.box(Vector3(0.095, 0.135, 0.044)), IVORY, Vector3(0, 0.03, 0.06))
	k.part(book, "BookCross", ModelKit.box(Vector3(0.03, 0.06, 0.01)), GOLD, Vector3(0, 0.04, 0.085))
	k.joints["Arm.R"].rotation_degrees = Vector3(-15, 0, -5)
	k.joints["Arm.L"].rotation_degrees = Vector3(-20, 0, 6)
	BipedClips.animate(k, {"attack": &"swing", "stride": 22.0})
	return k
