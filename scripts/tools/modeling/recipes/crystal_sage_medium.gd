extends RefCounted
## TEST: the crystal sage of a concept-art reference, medium poly. A stone golem sage: carved
## faceted stone skin with glowing blue veins on the right arm, a crown of colored crystals, a brown
## robe draped diagonally over the left shoulder with gold trim, a teal front panel, a flame in the
## open left hand, stone shards orbiting the right arm. Semi-realistic proportions (head ~1/7).

const D := preload("res://scripts/tools/modeling/detail_kit.gd")

const STONE := Color(0.64, 0.57, 0.48)
const STONE_LIGHT := Color(0.72, 0.65, 0.55)
const STONE_DARK := Color(0.42, 0.36, 0.3)
const CRACK := Color(0.3, 0.25, 0.2)
const ROBE := Color(0.4, 0.35, 0.3)
const ROBE_DARK := Color(0.3, 0.26, 0.22)
const GOLD := Color(0.8, 0.62, 0.28)
const TEAL := Color(0.17, 0.3, 0.32)
const GLOW := Color(0.3, 0.72, 1.0)
const AMBER := Color(1.0, 0.72, 0.2)
const FLAME := Color(1.0, 0.78, 0.4)
const CRYSTALS: Array[Color] = [Color(0.95, 0.45, 0.75), Color(0.45, 0.88, 0.55), Color(0.45, 0.65, 1.0),
		Color(0.98, 0.88, 0.4), Color(0.98, 0.58, 0.28), Color(0.75, 0.5, 0.95), Color(0.45, 0.92, 0.92)]


static func build() -> ModelKit:
	var k := ModelKit.new()
	var rig := k.joint(null, "Rig")
	_legs(k, rig)
	var hips := k.joint(rig, "Hips", Vector3(0, 0.84, 0))
	_torso(k, hips)
	_robe(k, hips)
	_head(k, hips)
	_arm_right(k, hips)
	_arm_left(k, hips)
	_shards(k, hips)
	k.joints["Arm.L"].rotation_degrees = Vector3(-18, 0, 10)
	k.joints["Elbow.L"].rotation_degrees = Vector3(-78, 0, 0)
	k.joints["Arm.R"].rotation_degrees = Vector3(4, 0, -5)
	k.joints["Elbow.R"].rotation_degrees = Vector3(-8, 0, 0)
	BipedClips.animate(k, {"attack": &"punch", "stride": 22.0, "bob": 0.035, "lie": 0.14})
	_floating_motion(k)
	return k


# --- Body ---------------------------------------------------------------------------------------

static func _legs(k: ModelKit, rig: Node3D) -> void:
	for side: int in [1, -1]:
		var tag := ".L" if side == 1 else ".R"
		var leg := k.joint(rig, "Leg" + tag, Vector3(0.1 * side, 0.84, 0))
		k.part(leg, "Thigh", D.tube([Vector3(0, 0, 0), Vector3(0, -0.2, 0.01), Vector3(0, -0.4, 0.0)], [0.085, 0.075, 0.062], 8), STONE, Vector3.ZERO)
		k.part(leg, "Knee", D.ellipsoid(Vector3(0.06, 0.055, 0.06), 10, 6, 0.08, 11, false), STONE_DARK, Vector3(0, -0.42, 0.01))
		k.part(leg, "Shin", D.tube([Vector3(0, -0.42, 0.0), Vector3(0, -0.6, -0.005), Vector3(0, -0.78, 0.0)], [0.058, 0.048, 0.036], 8), STONE, Vector3.ZERO)
		k.part(leg, "Calf", D.ellipsoid(Vector3(0.05, 0.1, 0.055), 10, 7, 0.07, 5, false), STONE, Vector3(0, -0.56, -0.015))
		k.part(leg, "Foot", D.ellipsoid(Vector3(0.062, 0.04, 0.135), 12, 6, 0.06, 7 + side, false), STONE, Vector3(0, -0.815, 0.045))
		for toe in 5:
			var x := (toe - 2) * 0.024 * -side
			k.part(leg, "Toe%d" % toe, D.ellipsoid(Vector3(0.016, 0.014, 0.022 - absf(toe - 2) * 0.002), 6, 4, 0.0, 0, false), STONE_LIGHT, Vector3(x, -0.82, 0.175 - absf(toe - 2) * 0.006))


static func _torso(k: ModelKit, hips: Node3D) -> void:
	k.part(hips, "Pelvis", D.ellipsoid(Vector3(0.17, 0.1, 0.11), 12, 7, 0.05, 2, false), STONE_DARK, Vector3(0, 0.02, 0))
	k.part(hips, "Abdomen", D.ellipsoid(Vector3(0.15, 0.15, 0.1), 14, 8, 0.05, 4, false), STONE, Vector3(0, 0.14, 0.005))
	k.part(hips, "Chest", D.ellipsoid(Vector3(0.2, 0.2, 0.125), 16, 9, 0.04, 8, false), STONE, Vector3(0, 0.36, 0))
	for side: int in [1, -1]:
		k.part(hips, "Pec%d" % side, D.ellipsoid(Vector3(0.095, 0.075, 0.06), 12, 7, 0.06, 20 + side, false), STONE_LIGHT, Vector3(0.085 * side, 0.4, 0.085))
		k.part(hips, "Trapezius%d" % side, D.ellipsoid(Vector3(0.1, 0.05, 0.08), 10, 6, 0.06, 30 + side, false), STONE, Vector3(0.1 * side, 0.52, -0.01))
		for row in 3:
			k.part(hips, "Ab%d_%d" % [row, side], D.ellipsoid(Vector3(0.05, 0.035, 0.03), 8, 5, 0.08, 40 + row + side, false), STONE_LIGHT,
					Vector3(0.05 * side, 0.08 + row * 0.07, 0.09))
	# Cracks in the stone: thin dark veins.
	var cracks := [
		[Vector3(0.0, 0.5, 0.115), Vector3(-0.02, 0.43, 0.125), Vector3(0.015, 0.36, 0.126), Vector3(0.0, 0.28, 0.115)],
		[Vector3(0.1, 0.42, 0.115), Vector3(0.14, 0.38, 0.1), Vector3(0.16, 0.3, 0.09)],
		[Vector3(-0.1, 0.43, 0.116), Vector3(-0.14, 0.37, 0.1), Vector3(-0.15, 0.3, 0.09)],
		[Vector3(0.0, 0.22, 0.1), Vector3(0.03, 0.16, 0.105), Vector3(-0.01, 0.08, 0.098)],
		[Vector3(-0.19, 0.4, 0.03), Vector3(-0.2, 0.34, 0.0), Vector3(-0.19, 0.28, -0.04)],
	]
	for index in cracks.size():
		k.part(hips, "Crack%d" % index, D.tube(cracks[index], _same(cracks[index].size(), 0.006), 4, true, false), CRACK)


static func _robe(k: ModelKit, hips: Node3D) -> void:
	var fold := func(angle: float, _y: float) -> float: return 1.0 + 0.05 * sin(angle * 6.0) + 0.025 * sin(angle * 11.0 + 1.0)
	# The long skirt, a wrap at the waist, a gold hem.
	k.part(hips, "Skirt", D.lathe([Vector2(0.235, -0.5), Vector2(0.225, -0.35), Vector2(0.21, -0.18), Vector2(0.195, 0.0), Vector2(0.18, 0.12)], 20, true, fold), ROBE)
	k.part(hips, "Hem", D.lathe([Vector2(0.237, -0.5), Vector2(0.243, -0.5), Vector2(0.24, -0.45), Vector2(0.23, -0.45)], 20, true, fold), GOLD)
	k.part(hips, "Wrap", D.lathe([Vector2(0.185, 0.04), Vector2(0.21, 0.07), Vector2(0.215, 0.14), Vector2(0.19, 0.19)], 20, true), ROBE_DARK)
	k.part(hips, "WrapTrim", D.lathe([Vector2(0.21, 0.16), Vector2(0.222, 0.16), Vector2(0.222, 0.175), Vector2(0.21, 0.175)], 20, true), GOLD)
	# The teal front panel, edged in gold.
	var panel_points := [Vector3(0, 0.1, 0.19), Vector3(0, -0.15, 0.215), Vector3(0, -0.35, 0.232), Vector3(0, -0.5, 0.245)]
	k.part(hips, "Panel", D.band(panel_points, [0.2, 0.19, 0.17, 0.15], 0.02, Vector3.UP, false), TEAL)
	for side: int in [1, -1]:
		var edge := []
		var widths := [0.2, 0.19, 0.17, 0.15]
		for index in panel_points.size():
			edge.append((panel_points[index] as Vector3) + Vector3(side * widths[index] * 0.5, 0, 0.004))
		k.part(hips, "PanelTrim%d" % side, D.band(edge, _same(4, 0.014), 0.024, Vector3.UP, false), GOLD)
	# The cloth over the left shoulder and across the chest to the right hip.
	var drape := [Vector3(0.1, 0.3, -0.14), Vector3(0.19, 0.5, -0.09), Vector3(0.2, 0.54, -0.02), Vector3(0.17, 0.5, 0.1), Vector3(0.07, 0.38, 0.145), Vector3(-0.05, 0.25, 0.155),
			Vector3(-0.15, 0.13, 0.17), Vector3(-0.2, 0.05, 0.17)]
	var widths := [0.16, 0.16, 0.15, 0.15, 0.14, 0.13, 0.13, 0.12]
	k.part(hips, "Drape", D.band(drape, widths, 0.045, Vector3(0.3, 0.4, 0.8), true), ROBE)
	for side: int in [1, -1]:
		var edge := []
		for index in drape.size():
			var tangent: Vector3 = ((drape[mini(index + 1, drape.size() - 1)] as Vector3) - (drape[maxi(index - 1, 0)] as Vector3)).normalized()
			var across := Vector3(0.3, 0.4, 0.8).cross(tangent).normalized()
			edge.append((drape[index] as Vector3) + across * side * widths[index] * 0.5)
		k.part(hips, "DrapeTrim%d" % side, D.tube(edge, _same(drape.size(), 0.011), 5, true, true), GOLD)
	# Cloth hanging from the left shoulder down the side (a wide sleeve), rippled.
	var side_cloth := [Vector3(0.28, 0.5, -0.02), Vector3(0.31, 0.3, -0.03), Vector3(0.32, 0.05, -0.04), Vector3(0.31, -0.2, -0.05)]
	k.part(hips, "SideCloth", D.sweep(side_cloth, _cloth_sections([0.2, 0.22, 0.25, 0.28], 0.018, 3.0), Vector3.RIGHT, true, false), ROBE)
	var hem_line := _cloth_sections([0.28], 0.018, 3.0)
	k.part(hips, "SideClothTrim", D.sweep([Vector3(0.31, -0.2, -0.05), Vector3(0.31, -0.225, -0.05)], [hem_line[0], hem_line[0]], Vector3.RIGHT, true, false), GOLD)


## Wavy strips (a cloth seen edge on): one polygon per width, `amplitude` deep ripples
## `ripples` times across, 0.012 thick.
static func _cloth_sections(widths: Array, amplitude: float, ripples: float) -> Array:
	var sections: Array = []
	for width: float in widths:
		var polygon: Array[Vector2] = []
		var count := 10
		for i in count:
			var x := -width * 0.5 + width * i / (count - 1)
			polygon.append(Vector2(x, amplitude * sin(x / width * TAU * ripples * 0.5) + 0.006))
		for i in count:
			var x := width * 0.5 - width * i / (count - 1)
			polygon.append(Vector2(x, amplitude * sin(x / width * TAU * ripples * 0.5) - 0.006))
		sections.append(polygon)
	return sections


static func _head(k: ModelKit, hips: Node3D) -> void:
	var head := k.joint(hips, "Head", Vector3(0, 0.55, 0))
	k.part(head, "Neck", D.tube([Vector3(0, -0.04, 0), Vector3(0, 0.04, 0.005), Vector3(0, 0.1, 0.01)], [0.06, 0.052, 0.05], 8), STONE_DARK)
	k.part(head, "Skull", D.ellipsoid(Vector3(0.1, 0.125, 0.11), 16, 10, 0.03, 50, false), STONE, Vector3(0, 0.18, 0))
	k.part(head, "Jaw", D.ellipsoid(Vector3(0.078, 0.062, 0.085), 12, 7, 0.05, 51, false), STONE, Vector3(0, 0.1, 0.035))
	k.part(head, "Chin", D.ellipsoid(Vector3(0.04, 0.035, 0.04), 8, 5, 0.06, 52, false), STONE_LIGHT, Vector3(0, 0.065, 0.085))
	k.part(head, "Brow", D.ellipsoid(Vector3(0.082, 0.014, 0.03), 12, 5, 0.08, 53, false), STONE_DARK, Vector3(0, 0.222, 0.092))
	k.part(head, "Nose", D.ellipsoid(Vector3(0.016, 0.04, 0.03), 8, 5, 0.06, 54, false), STONE_LIGHT, Vector3(0, 0.165, 0.115), Vector3(-15, 0, 0))
	k.part(head, "Mouth", ModelKit.box(Vector3(0.05, 0.005, 0.01)), CRACK, Vector3(0, 0.118, 0.108))
	for side: int in [1, -1]:
		var tag := ".L" if side == 1 else ".R"
		k.part(head, "Socket" + tag, D.ellipsoid(Vector3(0.03, 0.017, 0.016), 8, 5, 0.0, 0, false), CRACK, Vector3(0.046 * side, 0.198, 0.103), Vector3(0, 0, -8 * side))
		k.part(head, "Eye" + tag, D.ellipsoid(Vector3(0.019, 0.011, 0.01), 6, 4, 0.0, 0, false), AMBER, Vector3(0.046 * side, 0.198, 0.113), Vector3.ZERO, 2.4)
		k.part(head, "Cheek" + tag, D.ellipsoid(Vector3(0.03, 0.025, 0.03), 8, 5, 0.08, 55 + side, false), STONE_LIGHT, Vector3(0.06 * side, 0.155, 0.085))
		k.part(head, "Ear" + tag, D.crystal(0.014, 0.1, 0.5, 4), STONE_DARK, Vector3(0.108 * side, 0.2, -0.005), Vector3(0, 0, -78 * side))
	# The crown: rings of crystals growing out of the scalp, the tallest in the middle.
	var rings := [[1, 0.0, 0.0, 0.3, 0.03], [6, 0.035, 12.0, 0.23, 0.026], [11, 0.07, 26.0, 0.17, 0.022], [9, 0.098, 42.0, 0.11, 0.019]]
	var count := 0
	for ring: Array in rings:
		for index in int(ring[0]):
			var around: float = TAU * (index + 0.5 * float(count % 2)) / float(ring[0]) + count * 0.7
			var direction := Vector3(sin(around), 0, cos(around))
			var tilt: float = ring[2]
			var axis := Vector3.UP.cross(direction).normalized() if tilt > 0.0 else Vector3.RIGHT
			var euler := Basis(axis, deg_to_rad(tilt)).get_euler() * (180.0 / PI) if tilt > 0.0 else Vector3.ZERO
			var height: float = ring[3] * (0.8 + 0.4 * D._noise(count, 3, 9))
			var base := Vector3(0, 0.27, 0) + direction * float(ring[1]) * 0.8
			k.part(head, "Crystal%d" % count, D.crystal(float(ring[4]) * (0.85 + 0.3 * D._noise(count, 5, 2)), height, 0.4, 6),
					CRYSTALS[count % CRYSTALS.size()], base + Vector3(0, height * 0.42, 0).rotated(axis, deg_to_rad(tilt)) if tilt > 0.0 else base + Vector3(0, height * 0.42, 0), euler, 0.45)
			count += 1


static func _arm_right(k: ModelKit, hips: Node3D) -> void:
	var arm := k.joint(hips, "Arm.R", Vector3(-0.245, 0.46, 0))
	k.part(arm, "Deltoid", D.ellipsoid(Vector3(0.075, 0.08, 0.075), 12, 7, 0.06, 60, false), STONE, Vector3(0, -0.01, 0))
	k.part(arm, "UpperArm", D.tube([Vector3(0, 0, 0), Vector3(0, -0.14, 0.005), Vector3(0, -0.28, 0)], [0.068, 0.063, 0.054], 8), STONE)
	k.part(arm, "Biceps", D.ellipsoid(Vector3(0.057, 0.095, 0.057), 10, 7, 0.07, 61, false), STONE_LIGHT, Vector3(0, -0.12, 0.012))
	var elbow := k.joint(arm, "Elbow.R", Vector3(0, -0.28, 0))
	k.part(elbow, "ElbowKnob", D.ellipsoid(Vector3(0.05, 0.045, 0.05), 8, 5, 0.1, 62, false), STONE_DARK)
	k.part(elbow, "Forearm", D.tube([Vector3(0, 0, 0), Vector3(0, -0.13, 0.004), Vector3(0, -0.27, 0)], [0.054, 0.051, 0.038], 8), STONE)
	k.part(elbow, "ForearmMuscle", D.ellipsoid(Vector3(0.042, 0.09, 0.042), 10, 7, 0.07, 63, false), STONE_LIGHT, Vector3(0, -0.09, 0.006))
	_hand(k, elbow, "R", -1, false)
	# The glowing veins: snaking lines on the surface from the shoulder to the knuckles.
	var seeds := [[0.0, 0.0], [2.2, 0.8], [4.4, 1.6]]
	for index in seeds.size():
		var points := []
		var radii := []
		for step in 11:
			var t := step / 10.0
			var y := -0.02 - t * 0.53
			var on_forearm := y < -0.28
			var local_y := y + 0.28 if on_forearm else y
			var radius := (0.053 - 0.013 * (-local_y / 0.27) if on_forearm else 0.066 - 0.012 * (-y / 0.28)) + 0.004
			var angle := deg_to_rad(float(seeds[index][0]) * 15.0 - 25.0 + 20.0 * sin(t * 5.5 + float(seeds[index][1])))
			var local := Vector3(sin(angle) * radius, local_y, cos(angle) * radius)
			points.append(local)
			radii.append(0.0058 - 0.0015 * t)
		var upper := points.slice(0, 6)
		var lower := points.slice(5)
		k.part(arm, "VeinU%d" % index, D.tube(upper, radii.slice(0, 6), 4, true, false), GLOW, Vector3.ZERO, Vector3.ZERO, 1.4)
		k.part(elbow, "VeinL%d" % index, D.tube(lower, radii.slice(5), 4, true, false), GLOW, Vector3.ZERO, Vector3.ZERO, 1.4)


static func _arm_left(k: ModelKit, hips: Node3D) -> void:
	var arm := k.joint(hips, "Arm.L", Vector3(0.245, 0.46, 0))
	k.part(arm, "Deltoid", D.ellipsoid(Vector3(0.075, 0.08, 0.075), 12, 7, 0.06, 70, false), STONE, Vector3(0, -0.01, 0))
	k.part(arm, "UpperArm", D.tube([Vector3(0, 0, 0), Vector3(0, -0.14, 0.005), Vector3(0, -0.28, 0)], [0.068, 0.063, 0.054], 8), STONE)
	var elbow := k.joint(arm, "Elbow.L", Vector3(0, -0.28, 0))
	k.part(elbow, "ElbowKnob", D.ellipsoid(Vector3(0.05, 0.045, 0.05), 8, 5, 0.1, 71, false), STONE_DARK)
	k.part(elbow, "Forearm", D.tube([Vector3(0, 0, 0), Vector3(0, -0.13, 0.004), Vector3(0, -0.27, 0)], [0.054, 0.051, 0.038], 8), STONE)
	k.part(elbow, "ForearmMuscle", D.ellipsoid(Vector3(0.042, 0.09, 0.042), 10, 7, 0.07, 72, false), STONE_LIGHT, Vector3(0, -0.09, 0.006))
	_hand(k, elbow, "L", 1, true)
	var wrist := [Vector3(0.012, -0.18, 0.052), Vector3(-0.01, -0.22, 0.046), Vector3(0.01, -0.27, 0.04)]
	k.part(elbow, "VeinWrist", D.tube(wrist, [0.006, 0.006, 0.005], 4, true, false), GLOW, Vector3.ZERO, Vector3.ZERO, 1.4)


## A hand at the end of the forearm (joint `Hand.<tag>`), palm toward +Z in the hanging frame.
static func _hand(k: ModelKit, elbow: Node3D, tag: String, side: int, open: bool) -> void:
	var hand := k.joint(elbow, "Hand." + tag, Vector3(0, -0.27, 0))
	k.part(hand, "Palm", D.ellipsoid(Vector3(0.036, 0.044, 0.017), 10, 6, 0.05, 80 + side, false), STONE, Vector3(0, -0.04, 0))
	k.part(hand, "Wristband", D.lathe([Vector2(0.04, 0.0), Vector2(0.044, -0.01), Vector2(0.04, -0.02)], 10, true), STONE_DARK)
	for finger in 4:
		var x := (finger - 1.5) * 0.019
		var length := 0.062 - absf(finger - 1.5) * 0.006
		var points: Array
		if open:
			points = [Vector3(x, -0.075, 0.002), Vector3(x * 1.4, -0.075 - length * 0.8, 0.02), Vector3(x * 1.7, -0.07 - length * 1.3, 0.052)]
		else:
			points = [Vector3(x, -0.075, 0.0), Vector3(x, -0.075 - length * 0.9, 0.012), Vector3(x, -0.075 - length * 1.1, 0.04)]
		k.part(hand, "Finger%d" % finger, D.tube(points, [0.0095, 0.008, 0.006], 5), STONE)
	var thumb: Array = [Vector3(0.03 * -side, -0.025, 0.004), Vector3(0.046 * -side, -0.06, 0.016), Vector3(0.05 * -side, -0.09, 0.03)]
	k.part(hand, "Thumb", D.tube(thumb, [0.012, 0.01, 0.007], 5), STONE)
	if open:
		var flame := k.joint(hand, "Flame", Vector3(0, -0.1, 0.075))
		k.part(flame, "FlameOuter", D.ellipsoid(Vector3(0.026, 0.05, 0.026), 10, 7, 0.0, 0, true), FLAME, Vector3(0, 0.0, 0), Vector3.ZERO, 2.0)
		k.part(flame, "FlameInner", D.ellipsoid(Vector3(0.014, 0.03, 0.014), 8, 5, 0.0, 0, true), Color(1.0, 0.97, 0.85), Vector3(0, -0.008, 0), Vector3.ZERO, 3.0)
		for spark in 4:
			var a := spark * 1.6
			k.part(flame, "Spark%d" % spark, D.crystal(0.004, 0.02, 0.5, 4), FLAME, Vector3(sin(a) * 0.04, 0.05 + spark * 0.018, cos(a) * 0.03), Vector3(0, 0, spark * 17), 3.0)


static func _shards(k: ModelKit, hips: Node3D) -> void:
	# Stone chunks and crystals floating beside the right arm.
	var placements := [
		[Vector3(-0.42, 0.52, 0.03), 0.055, "stone"], [Vector3(-0.5, 0.36, -0.06), 0.035, "crystal"], [Vector3(-0.38, 0.22, 0.08), 0.07, "stone"],
		[Vector3(-0.5, 0.08, 0.0), 0.045, "crystal"], [Vector3(-0.36, -0.06, -0.05), 0.05, "stone"], [Vector3(-0.47, -0.2, 0.06), 0.04, "crystal"],
		[Vector3(-0.54, 0.2, 0.1), 0.028, "stone"], [Vector3(-0.33, 0.42, -0.1), 0.03, "crystal"], [Vector3(-0.42, -0.34, -0.02), 0.03, "stone"],
	]
	for index in placements.size():
		var spec: Array = placements[index]
		var shard := k.joint(hips, "Shard%d" % index, spec[0])
		var size: float = spec[1]
		if spec[2] == "stone":
			k.part(shard, "Chunk", D.ellipsoid(Vector3(size, size * 1.3, size * 0.7), 7, 5, 0.22, 90 + index, false), STONE_DARK if index % 2 == 0 else STONE, Vector3.ZERO, Vector3(index * 23, index * 41, index * 11))
		else:
			k.part(shard, "Gem", D.crystal(size * 0.45, size * 2.2, 0.35, 5), CRYSTALS[(index * 2 + 1) % CRYSTALS.size()], Vector3.ZERO, Vector3(index * 17, 0, 20 + index * 9), 0.8)


# --- Motion -------------------------------------------------------------------------------------

## The shards bob and sway, the flame flickers, in the Idle and Walk loops (each loop closes).
static func _floating_motion(k: ModelKit) -> void:
	var player := k.root.get_node("AnimationPlayer") as AnimationPlayer
	for clip in ["Idle", "Walk"]:
		var animation := player.get_animation(clip)
		var length := animation.length
		var steps := 6
		for name: String in k.joints:
			if not name.begins_with("Shard"):
				continue
			var index := int(name.trim_prefix("Shard"))
			var joint := k.joints[name]
			var position_track := animation.add_track(Animation.TYPE_VALUE)
			animation.track_set_path(position_track, NodePath("%s:position" % k.root.get_path_to(joint)))
			animation.value_track_set_update_mode(position_track, Animation.UPDATE_CONTINUOUS)
			animation.track_set_interpolation_type(position_track, Animation.INTERPOLATION_CUBIC)
			var rotation_track := animation.add_track(Animation.TYPE_VALUE)
			animation.track_set_path(rotation_track, NodePath("%s:rotation" % k.root.get_path_to(joint)))
			animation.value_track_set_update_mode(rotation_track, Animation.UPDATE_CONTINUOUS)
			animation.track_set_interpolation_type(rotation_track, Animation.INTERPOLATION_CUBIC)
			for step in steps + 1:
				var phase := index * 1.1 + TAU * step / steps
				var at_end := step == steps
				var first_position := joint.position + Vector3(0, 0.025 * sin(index * 1.1), 0)
				var offset := Vector3(0.01 * cos(phase), 0.025 * sin(phase), 0.01 * sin(phase * 2.0))
				animation.track_insert_key(position_track, length * step / steps, first_position if at_end else joint.position + offset)
				animation.track_insert_key(rotation_track, length * step / steps, Vector3(0.0, 0.4 * sin(index * 1.1), 0.0) if at_end else Vector3(0.3 * sin(phase), 0.4 * sin(phase + 1.0), 0.0))
			# The first key must equal the last: rewrite it with the end value.
			animation.track_set_key_value(position_track, 0, animation.track_get_key_value(position_track, steps))
			animation.track_set_key_value(rotation_track, 0, animation.track_get_key_value(rotation_track, steps))
		var flame := k.joints["Flame"]
		var flame_track := animation.add_track(Animation.TYPE_VALUE)
		animation.track_set_path(flame_track, NodePath("%s:scale" % k.root.get_path_to(flame)))
		animation.value_track_set_update_mode(flame_track, Animation.UPDATE_CONTINUOUS)
		var flicker := [Vector3.ONE, Vector3(1.1, 0.85, 1.1), Vector3(0.92, 1.18, 0.92), Vector3(1.06, 0.92, 1.06), Vector3.ONE]
		for step in flicker.size():
			animation.track_insert_key(flame_track, length * step / (flicker.size() - 1), flicker[step])


static func _same(count: int, value: float) -> Array:
	var values := []
	for i in count:
		values.append(value)
	return values
