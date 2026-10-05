extends RefCounted
## TEST (not a milestone): the crystal sage from a concept-art reference, low-poly version.
## A tall stone golem in a wrapped robe: a crown of coloured crystals, glowing blue veins on the
## bare right arm with floating shards beside it, the left hand holding a flame.

const STONE := Color(0.62, 0.55, 0.47)
const STONE_DARK := Color(0.42, 0.36, 0.30)
const STONE_LIGHT := Color(0.7, 0.63, 0.54)
const ROBE := Color(0.34, 0.30, 0.26)
const ROBE_DARK := Color(0.26, 0.23, 0.20)
const GOLD := Color(0.72, 0.56, 0.26)
const TEAL := Color(0.15, 0.27, 0.28)
const VEIN := Color(0.3, 0.7, 1.0)
const AMBER := Color(1.0, 0.7, 0.2)
const FLAME := Color(1.0, 0.82, 0.45)
const FLAME_OUTER := Color(1.0, 0.5, 0.15)
const CRYSTALS := [
	Color(0.95, 0.4, 0.7), Color(0.3, 0.85, 0.5), Color(0.3, 0.55, 1.0), Color(1.0, 0.85, 0.3),
	Color(1.0, 0.55, 0.2), Color(0.65, 0.4, 0.95), Color(0.3, 0.9, 0.95),
]


static func build() -> ModelKit:
	var k := ModelKit.new()
	var rig := k.joint(null, "Rig")
	# Legs: bare stone under the skirt, broad feet.
	for side in [1, -1]:
		var tag := ".L" if side == 1 else ".R"
		var leg := k.joint(rig, "Leg" + tag, Vector3(0.11 * side, 0.46, 0))
		k.part(leg, "Shin", ModelKit.prism(4, Vector2(0.09, 0.09), Vector2(0.075, 0.075), 0.36), STONE, Vector3(0, -0.22, 0))
		k.part(leg, "Foot", ModelKit.prism(4, Vector2(0.095, 0.15), Vector2(0.085, 0.11), 0.07), STONE_DARK, Vector3(0, -0.425, 0.045))
	var hips := k.joint(rig, "Hips", Vector3(0, 0.46, 0))
	# Skirt, belt, teal front panel, gold trim.
	k.part(hips, "Skirt", ModelKit.prism(4, Vector2(0.29, 0.21), Vector2(0.2, 0.15), 0.34), ROBE, Vector3(0, -0.12, 0))
	k.part(hips, "HemTrim", ModelKit.prism(4, Vector2(0.295, 0.215), Vector2(0.295, 0.215), 0.035), GOLD, Vector3(0, -0.285, 0))
	k.part(hips, "Panel", ModelKit.box(Vector3(0.2, 0.31, 0.02)), TEAL, Vector3(0, -0.12, 0.2), Vector3(-8, 0, 0))
	for side in [1, -1]:
		k.part(hips, "PanelTrim%d" % side, ModelKit.box(Vector3(0.022, 0.31, 0.026)), GOLD, Vector3(0.11 * side, -0.12, 0.2), Vector3(-8, 0, 0))
	k.part(hips, "Belt", ModelKit.prism(4, Vector2(0.2, 0.145), Vector2(0.2, 0.145), 0.06), ROBE_DARK, Vector3(0, 0.07, 0))
	k.part(hips, "BeltTrim", ModelKit.prism(4, Vector2(0.205, 0.15), Vector2(0.205, 0.15), 0.014), GOLD, Vector3(0, 0.1, 0))
	# Bare stone chest with muscle lumps and cracks.
	k.part(hips, "Torso", ModelKit.prism(4, Vector2(0.19, 0.125), Vector2(0.25, 0.145), 0.36), STONE, Vector3(0, 0.28, 0))
	for side in [1, -1]:
		k.part(hips, "Pec%d" % side, ModelKit.blob(Vector3(0.1, 0.075, 0.05), 6, 3), STONE_LIGHT, Vector3(0.1 * side, 0.36, 0.14))
	for crack in [[-0.12, 0.43, -28.0, 0.14], [0.02, 0.32, 20.0, 0.12], [-0.05, 0.19, -60.0, 0.1], [-0.17, 0.3, 75.0, 0.09]]:
		k.part(hips, "Crack", ModelKit.box(Vector3(0.012, crack[3], 0.012)), STONE_DARK, Vector3(crack[0], crack[1], 0.157), Vector3(0, 0, crack[2]))
	# The robe's diagonal: from the left shoulder across the chest to the right hip.
	var sash := k.joint(hips, "Sash", Vector3(0.04, 0.26, 0.152), Vector3(0, 0, -33))
	k.part(sash, "Cloth", ModelKit.box(Vector3(0.14, 0.66, 0.03)), ROBE, Vector3.ZERO)
	for side in [1, -1]:
		k.part(sash, "SashTrim%d" % side, ModelKit.box(Vector3(0.02, 0.66, 0.038)), GOLD, Vector3(0.075 * side, 0, 0))
	# Head: stone face, heavy brow, amber eyes, a tuft of crystals.
	var head := k.joint(hips, "Head", Vector3(0, 0.46, 0))
	k.part(head, "Neck", ModelKit.prism(4, Vector2(0.075, 0.075), Vector2(0.075, 0.075), 0.1), STONE, Vector3(0, 0.0, 0))
	k.part(head, "Skull", ModelKit.blob(Vector3(0.2, 0.22, 0.2), 8, 4), STONE, Vector3(0, 0.2, 0))
	k.part(head, "Jaw", ModelKit.prism(4, Vector2(0.1, 0.1), Vector2(0.14, 0.13), 0.1), STONE, Vector3(0, 0.08, 0.06))
	k.part(head, "Brow", ModelKit.box(Vector3(0.3, 0.05, 0.06)), STONE_DARK, Vector3(0, 0.255, 0.165), Vector3(8, 0, 0))
	k.part(head, "Nose", ModelKit.wedge(0.05, 0.1, 0.09, 1.0), STONE_DARK, Vector3(0, 0.17, 0.2))
	for side in [1, -1]:
		k.part(head, "Eye%d" % side, ModelKit.blob(Vector3(0.036, 0.022, 0.02), 4, 2), AMBER, Vector3(0.085 * side, 0.215, 0.185), Vector3.ZERO, 1.3)
	_crown(k, head)
	# Left arm (+X): the robe drapes over the shoulder; the elbow is bent, the hand holds a flame.
	k.part(hips, "ShoulderCloth", ModelKit.blob(Vector3(0.13, 0.09, 0.12), 6, 3), ROBE, Vector3(0.29, 0.44, 0))
	var arm_l := k.joint(hips, "Arm.L", Vector3(0.3, 0.4, 0))
	k.part(arm_l, "Sleeve", ModelKit.prism(4, Vector2(0.115, 0.105), Vector2(0.085, 0.085), 0.3), ROBE, Vector3(0, -0.15, 0))
	k.part(arm_l, "SleeveTrim", ModelKit.box(Vector3(0.235, 0.03, 0.215)), GOLD, Vector3(0, -0.3, 0))
	var forearm := k.joint(arm_l, "Forearm.L", Vector3(0, -0.3, 0), Vector3(-95, 0, 0))
	k.part(forearm, "Forearm", ModelKit.prism(4, Vector2(0.065, 0.065), Vector2(0.052, 0.052), 0.28), STONE, Vector3(0, -0.14, 0))
	var hand_l := k.joint(forearm, "Hand.L", Vector3(0, -0.3, 0))
	k.part(hand_l, "Palm", ModelKit.box(Vector3(0.1, 0.03, 0.12)), STONE, Vector3(0, -0.01, 0.0), Vector3(0, 0, 0))
	k.part(hand_l, "Fingers", ModelKit.prism(4, Vector2(0.05, 0.015), Vector2(0.04, 0.012), 0.1), STONE_LIGHT, Vector3(0, -0.07, 0.0))
	# The flame floats in the palm (up is local +Z of the forearm frame).
	k.part(hand_l, "FlameCore", ModelKit.blob(Vector3(0.06, 0.06, 0.06), 6, 3), FLAME, Vector3(0, -0.01, 0.1), Vector3.ZERO, 2.0)
	k.part(hand_l, "FlameTip", ModelKit.prism(4, Vector2(0.05, 0.05), Vector2.ZERO, 0.16), FLAME_OUTER, Vector3(0, -0.01, 0.21), Vector3(90, 0, 0), 1.4)
	# Right arm (-X): bare stone with glowing veins.
	k.part(hips, "Shoulder.R", ModelKit.blob(Vector3(0.11, 0.09, 0.1), 6, 3), STONE, Vector3(-0.29, 0.44, 0))
	var arm_r := k.joint(hips, "Arm.R", Vector3(-0.3, 0.4, 0))
	k.part(arm_r, "Arm", ModelKit.prism(4, Vector2(0.075, 0.075), Vector2(0.06, 0.06), 0.34), STONE, Vector3(0, -0.17, 0))
	k.part(arm_r, "Bicep", ModelKit.blob(Vector3(0.085, 0.09, 0.085), 6, 3), STONE_LIGHT, Vector3(0, -0.08, 0.005))
	var hand_r := k.joint(arm_r, "Hand.R", Vector3(0, -0.4, 0))
	k.part(hand_r, "Fist", ModelKit.blob(Vector3(0.065, 0.08, 0.06), 6, 3), STONE)
	for vein in [[0.0, -0.14, 0.066, 30.0], [0.0, -0.24, 0.058, -35.0], [0.0, -0.3, 0.056, 25.0], [0.0, -0.2, 0.064, 85.0]]:
		k.part(arm_r, "Vein", ModelKit.box(Vector3(0.022, 0.14, 0.014)), VEIN, Vector3(vein[0], vein[1], vein[2]), Vector3(0, 0, vein[3]), 1.8)
	for vein in [[-0.068, -0.12, 0.0, 25.0], [-0.062, -0.26, 0.0, -30.0], [-0.062, -0.33, 0.0, 20.0]]:
		k.part(arm_r, "VeinSide", ModelKit.box(Vector3(0.014, 0.14, 0.022)), VEIN, Vector3(vein[0], vein[1], vein[2]), Vector3(vein[3], 0, 0), 1.8)
	# Rest poses, then the clips.
	k.joints["Arm.L"].rotation_degrees = Vector3(-10, 0, 10)
	k.joints["Arm.R"].rotation_degrees = Vector3(0, 0, -7)
	BipedClips.animate(k, {"attack": &"punch", "lie": 0.2, "stride": 26.0})
	_shards(k)
	return k


## A tuft of crystals: a tall middle one, a ring of six leaning out, an outer ring of five.
static func _crown(k: ModelKit, head: Node3D) -> void:
	var specs := [[0.0, 0.0, 0.0, 0.38, 0.05, 0.0]]
	for i in 6:
		specs.append([0.07, TAU * i / 6.0, 20.0, 0.3 - 0.03 * (i % 3), 0.04, 0.34])
	for i in 5:
		specs.append([0.14, TAU * (i + 0.5) / 5.0, 38.0, 0.2 + 0.02 * (i % 2), 0.035, 0.3])
	var index := 0
	for spec in specs:
		var radius: float = spec[0]
		var phi: float = spec[1]
		var tilt: float = deg_to_rad(spec[2])
		var length: float = spec[3]
		var width: float = spec[4]
		var base := Vector3(sin(phi) * radius, 0.34 - spec[5] * 0.0 - radius * 0.35, cos(phi) * radius)
		var outward := Vector3(sin(phi), 0, cos(phi))
		var up := (Vector3.UP * cos(tilt) + outward * sin(tilt)).normalized()
		var euler := Quaternion(Vector3.UP, up).get_euler() * (180.0 / PI)
		var color: Color = CRYSTALS[index % CRYSTALS.size()]
		var body := length * 0.62
		var tip := length * 0.38
		k.part(head, "CrystalBody%d" % index, ModelKit.prism(6, Vector2(width, width), Vector2(width * 0.85, width * 0.85), body), color, base + up * (body * 0.5), euler, 0.5)
		k.part(head, "CrystalTip%d" % index, ModelKit.prism(6, Vector2(width * 0.85, width * 0.85), Vector2.ZERO, tip), color, base + up * (body + tip * 0.5), euler, 0.5)
		index += 1


## Six shards (three stone chunks, three crystals) hovering beside the right arm; the Idle clip
## bobs and sways them (value tracks added after the biped clips, loops closed).
static func _shards(k: ModelKit) -> void:
	var orbit := k.joint(k.joints["Rig"], "Orbit", Vector3(-0.5, 0.75, 0.0))
	var specs := [
		["stone", Vector3(-0.05, 0.38, 0.05), 0.07], ["crystal", Vector3(0.0, 0.25, -0.12), 0.06],
		["stone", Vector3(-0.1, 0.05, 0.12), 0.09], ["crystal", Vector3(0.05, -0.1, -0.05), 0.07],
		["stone", Vector3(-0.06, -0.3, 0.08), 0.08], ["crystal", Vector3(0.02, -0.45, -0.1), 0.05],
	]
	var shard_colors := [CRYSTALS[2], CRYSTALS[5], CRYSTALS[1]]
	var player := k.root.get_node("AnimationPlayer") as AnimationPlayer
	var idle := player.get_animation("Idle")
	for index in specs.size():
		var spec: Array = specs[index]
		var shard := k.joint(orbit, "Shard%d" % index, spec[1])
		var size: float = spec[2]
		if spec[0] == "stone":
			k.part(shard, "Chunk", ModelKit.blob(Vector3(size, size * 1.2, size * 0.7), 5, 3), STONE_DARK if index % 4 == 0 else STONE)
		else:
			k.part(shard, "Gem", ModelKit.prism(4, Vector2(size * 0.45, size * 0.45), Vector2.ZERO, size * 2.2), shard_colors[index % 3], Vector3.ZERO, Vector3(10, 20, 15), 0.9)
		var sign := 1.0 if index % 2 == 0 else -1.0
		_loop_track(idle, k.root.get_path_to(shard), "position", spec[1], spec[1] + Vector3(0, 0.05 * sign, 0))
		_loop_track(idle, k.root.get_path_to(shard), "rotation", Vector3.ZERO, Vector3(0, deg_to_rad(35.0) * sign, deg_to_rad(10.0) * sign))


## A closed loop in the Idle clip: `from` at the start and the end, `to` in the middle.
static func _loop_track(animation: Animation, node_path: NodePath, property: String, from: Vector3, to: Vector3) -> void:
	var track := animation.add_track(Animation.TYPE_VALUE)
	animation.track_set_path(track, NodePath("%s:%s" % [node_path, property]))
	animation.track_set_interpolation_type(track, Animation.INTERPOLATION_CUBIC)
	animation.value_track_set_update_mode(track, Animation.UPDATE_CONTINUOUS)
	animation.track_insert_key(track, 0.0, from)
	animation.track_insert_key(track, animation.length * 0.5, to)
	animation.track_insert_key(track, animation.length, from)
