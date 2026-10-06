extends RefCounted
## The Necromancer (PvP): a gaunt hooded caster in a ragged charcoal-violet robe, a spiked bone
## collar behind the hood, rib pauldrons, a rope belt with a skull charm. A skull staff in the
## right hand (glowing green eyes), a green wisp above the open left palm.

const ROBE := Color(0.3, 0.22, 0.4)
const ROBE_DARK := Color(0.2, 0.14, 0.28)
const BONE := Color(0.98, 0.95, 0.82)
const GREEN := Color(0.4, 1.0, 0.5)
const GOLD := Color(0.78, 0.62, 0.3)
const BOOT := Color(0.26, 0.17, 0.17)
const VOID := Color(0.04, 0.02, 0.08)
const WOOD := Color(0.22, 0.16, 0.24)


static func build() -> ModelKit:
	var k := ModelKit.new()
	var rig := k.joint(null, "Rig")
	for side in [1, -1]:
		var tag := ".L" if side == 1 else ".R"
		var leg := k.joint(rig, "Leg" + tag, Vector3(0.09 * side, 0.34, 0))
		k.part(leg, "Trouser", ModelKit.prism(4, Vector2(0.06, 0.07), Vector2(0.055, 0.06), 0.24), ROBE_DARK, Vector3(0, -0.13, 0))
		k.part(leg, "Boot", ModelKit.prism(4, Vector2(0.078, 0.115), Vector2(0.07, 0.085), 0.12), BOOT, Vector3(0, -0.28, 0.025))
	var hips := k.joint(rig, "Hips", Vector3(0, 0.34, 0))
	k.part(hips, "Robe", ModelKit.prism(6, Vector2(0.29, 0.25), Vector2(0.19, 0.16), 0.46), ROBE, Vector3(0, 0.0, 0))
	for index in 6:  # The torn hem: points hanging below the skirt.
		var angle := TAU * (index + 0.5) / 6.0
		k.part(hips, "Rag%d" % index, ModelKit.prism(4, Vector2(0.075, 0.03), Vector2.ZERO, 0.15), ROBE, Vector3(sin(angle) * 0.24, -0.29, cos(angle) * 0.2), Vector3(180, rad_to_deg(angle), 0))
	k.part(hips, "Chest", ModelKit.prism(6, Vector2(0.18, 0.13), Vector2(0.23, 0.16), 0.3), ROBE, Vector3(0, 0.3, 0))
	k.part(hips, "Mantle", ModelKit.prism(6, Vector2(0.3, 0.22), Vector2(0.17, 0.12), 0.1), ROBE_DARK, Vector3(0, 0.44, 0))
	k.part(hips, "Rope", ModelKit.prism(6, Vector2(0.2, 0.15), Vector2(0.2, 0.15), 0.045), BONE, Vector3(0, 0.19, 0))
	for end in [-1, 1]:
		k.part(hips, "RopeEnd%d" % end, ModelKit.box(Vector3(0.035, 0.2, 0.03)), BONE, Vector3(0.03 + 0.03 * end, 0.07, 0.17), Vector3(0, 0, 6 * end))
	k.part(hips, "Charm", ModelKit.blob(Vector3(0.05, 0.055, 0.045), 6, 3), BONE, Vector3(-0.17, 0.17, 0.11))
	k.part(hips, "NeckSkull", ModelKit.blob(Vector3(0.04, 0.045, 0.03), 6, 3), BONE, Vector3(0, 0.46, 0.15))
	# Rib pauldrons: three bone bars fanned over each shoulder.
	for side in [1, -1]:
		for rib in 3:
			k.part(hips, "Rib%d_%d" % [side, rib], ModelKit.box(Vector3(0.17 - 0.02 * rib, 0.03, 0.045)), BONE,
					Vector3(0.27 * side, 0.5 - 0.045 * rib, 0.0), Vector3(0, 0, -20 * side - 10 * rib * side))
	var head := k.joint(hips, "Head", Vector3(0, 0.5, 0))
	k.part(head, "Hood", ModelKit.blob(Vector3(0.21, 0.22, 0.21), 8, 4), ROBE_DARK, Vector3(0, 0.2, -0.02))
	k.part(head, "Cowl", ModelKit.prism(6, Vector2(0.17, 0.13), Vector2(0.2, 0.17), 0.1), ROBE_DARK, Vector3(0, 0.04, 0.0))
	k.part(head, "Peak", ModelKit.prism(6, Vector2(0.15, 0.15), Vector2.ZERO, 0.24), ROBE_DARK, Vector3(0, 0.46, -0.09), Vector3(-28, 0, 0))
	k.part(head, "Shadow", ModelKit.blob(Vector3(0.15, 0.15, 0.1), 8, 3), VOID, Vector3(0, 0.18, 0.13))
	k.part(head, "Chin", ModelKit.blob(Vector3(0.085, 0.08, 0.06), 5, 3), BONE, Vector3(0, 0.07, 0.18))
	for side in [1, -1]:
		k.part(head, "Eye%d" % side, ModelKit.box(Vector3(0.06, 0.035, 0.02)), GREEN, Vector3(0.065 * side, 0.2, 0.2), Vector3(0, 0, -16 * side), 1.4)
	# The silhouette: a ring of bone spikes behind the hood.
	for index in 5:
		var spread := -1.0 + 0.5 * index
		var spike := 0.26 if index in [0, 4] else 0.32
		k.part(head, "Spike%d" % index, ModelKit.prism(4, Vector2(0.035, 0.028), Vector2.ZERO, spike), BONE,
				Vector3(0.2 * spread, 0.3 + 0.07 * (1.0 - absf(spread)), -0.2 + 0.05 * absf(spread)), Vector3(-18, 0, -34 * spread))
	for side in [1, -1]:
		var tag := ".L" if side == 1 else ".R"
		var arm := k.joint(hips, "Arm" + tag, Vector3(0.27 * side, 0.45, 0))
		k.part(arm, "Sleeve", ModelKit.prism(4, Vector2(0.1, 0.09), Vector2(0.055, 0.055), 0.3), ROBE, Vector3(0, -0.15, 0))
		k.part(arm, "Cuff", ModelKit.prism(4, Vector2(0.105, 0.095), Vector2(0.1, 0.09), 0.04), GOLD, Vector3(0, -0.3, 0))
		var hand := k.joint(arm, "Hand" + tag, Vector3(0, -0.35, 0))
		k.part(hand, "Fist", ModelKit.blob(Vector3(0.06, 0.055, 0.06), 6, 3), GOLD)
	# The skull staff hangs from Staff.R: tilted back to stand upright over the arm's rest tilt.
	var staff := k.joint(k.joints["Hand.R"], "Staff.R", Vector3.ZERO, Vector3(15, 0, 0))
	k.part(staff, "Pole", ModelKit.prism(6, Vector2(0.03, 0.03), Vector2(0.026, 0.026), 1.35), WOOD, Vector3(0, 0.3, 0))
	k.part(staff, "Foot", ModelKit.prism(6, Vector2(0.034, 0.034), Vector2(0.034, 0.034), 0.12), GOLD, Vector3(0, -0.32, 0))
	k.part(staff, "Binding", ModelKit.prism(6, Vector2(0.04, 0.04), Vector2(0.04, 0.04), 0.07), GOLD, Vector3(0, 0.88, 0))
	k.part(staff, "Jaw", ModelKit.blob(Vector3(0.06, 0.04, 0.06), 6, 2), BONE, Vector3(0, 1.02, 0.01))
	k.part(staff, "Skull", ModelKit.blob(Vector3(0.1, 0.1, 0.1), 8, 4), BONE, Vector3(0, 1.12, 0))
	for side in [1, -1]:
		k.part(staff, "SocketGlow%d" % side, ModelKit.blob(Vector3(0.04, 0.045, 0.03), 5, 3), GREEN, Vector3(0.045 * side, 1.13, 0.085), Vector3.ZERO, 1.4)
	# The open left palm holds a green wisp, kept upright whatever the arm does at rest.
	var wisp := k.joint(k.joints["Hand.L"], "Wisp.L", Vector3(0.0, 0.1, 0.04), Vector3(40, 0, -38))
	k.part(wisp, "FlameBase", ModelKit.blob(Vector3(0.065, 0.06, 0.065), 6, 3), GREEN, Vector3(0, 0.03, 0), Vector3.ZERO, 1.0)
	k.part(wisp, "Flame", ModelKit.prism(4, Vector2(0.05, 0.05), Vector2.ZERO, 0.2), GREEN, Vector3(0, 0.15, 0), Vector3.ZERO, 1.0)
	k.part(wisp, "FlameTip", ModelKit.prism(4, Vector2(0.03, 0.03), Vector2.ZERO, 0.12), GREEN, Vector3(0.04, 0.1, 0.02), Vector3(0, 0, -25), 1.0)
	k.joints["Arm.R"].rotation_degrees = Vector3(-15, 0, -5)
	k.joints["Arm.L"].rotation_degrees = Vector3(-40, 0, 38)
	BipedClips.animate(k, {"attack": &"swing", "stride": 22.0})
	return k
