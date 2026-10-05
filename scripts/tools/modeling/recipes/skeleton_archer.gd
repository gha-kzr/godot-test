extends RefCounted
## The Skeleton Archer: bone-white, a visible ribcage, a big skull with dark sockets, steel
## shoulder plates, leather gloves and boots. The bow stays upright in its left hand whatever the
## arm does (see _keep_upright).

const BONE := Color(1.0, 0.96, 0.84)
const SHADE := Color(0.8, 0.75, 0.62)
const VOID := Color(0.08, 0.07, 0.09)
const STEEL := Color(0.55, 0.58, 0.66)
const LEATHER := Color(0.55, 0.34, 0.16)
const GLOW := Color(0.5, 1.0, 0.7)


static func build() -> ModelKit:
	var k := ModelKit.new()
	var rig := k.joint(null, "Rig")
	for side in [1, -1]:
		var tag := ".L" if side == 1 else ".R"
		var leg := k.joint(rig, "Leg" + tag, Vector3(0.09 * side, 0.4, 0))
		k.part(leg, "Femur", ModelKit.prism(4, Vector2(0.045, 0.045), Vector2(0.04, 0.04), 0.32), BONE, Vector3(0, -0.17, 0))
		k.part(leg, "Knee", ModelKit.blob(Vector3(0.06, 0.05, 0.06), 6, 3), BONE, Vector3(0, -0.18, 0.01))
		k.part(leg, "Boot", ModelKit.prism(4, Vector2(0.075, 0.11), Vector2(0.065, 0.085), 0.1), LEATHER, Vector3(0, -0.35, 0.025))
	var hips := k.joint(rig, "Hips", Vector3(0, 0.4, 0))
	k.part(hips, "Pelvis", ModelKit.prism(4, Vector2(0.15, 0.09), Vector2(0.12, 0.08), 0.1), BONE, Vector3(0, 0.03, 0))
	k.part(hips, "Spine", ModelKit.box(Vector3(0.06, 0.34, 0.06)), SHADE, Vector3(0, 0.22, -0.02))
	k.part(hips, "Cavity", ModelKit.prism(6, Vector2(0.11, 0.075), Vector2(0.13, 0.09), 0.32), VOID, Vector3(0, 0.27, 0))
	for rib in 4:
		var width := 0.15 + 0.015 * rib
		k.part(hips, "Rib%d" % rib, ModelKit.prism(6, Vector2(width, width * 0.72), Vector2(width, width * 0.72), 0.035), BONE, Vector3(0, 0.16 + 0.075 * rib, 0.01))
	k.part(hips, "Breastbone", ModelKit.box(Vector3(0.04, 0.26, 0.03)), BONE, Vector3(0, 0.27, 0.1))
	var head := k.joint(hips, "Head", Vector3(0, 0.46, 0))
	k.part(head, "Neck", ModelKit.box(Vector3(0.05, 0.08, 0.05)), SHADE, Vector3(0, 0.0, 0))
	k.part(head, "Skull", ModelKit.blob(Vector3(0.21, 0.2, 0.2), 8, 4), BONE, Vector3(0, 0.2, 0))
	k.part(head, "Jaw", ModelKit.prism(4, Vector2(0.095, 0.08), Vector2(0.075, 0.06), 0.07), SHADE, Vector3(0, 0.04, 0.07))
	k.part(head, "Teeth", ModelKit.box(Vector3(0.15, 0.025, 0.03)), BONE, Vector3(0, 0.085, 0.145))
	k.part(head, "Nose", ModelKit.prism(3, Vector2(0.025, 0.02), Vector2(0.01, 0.01), 0.05), VOID, Vector3(0, 0.15, 0.2))
	for side in [1, -1]:
		var tag := ".L" if side == 1 else ".R"
		k.part(head, "Socket" + tag, ModelKit.box(Vector3(0.085, 0.085, 0.05)), VOID, Vector3(0.085 * side, 0.22, 0.175))
		k.part(head, "Glow" + tag, ModelKit.blob(Vector3(0.022, 0.022, 0.02), 4, 2), GLOW, Vector3(0.085 * side, 0.22, 0.2), Vector3.ZERO, 1.2)
		k.part(hips, "Plate" + tag, ModelKit.blob(Vector3(0.12, 0.07, 0.12), 6, 3), STEEL, Vector3(0.25 * side, 0.45, 0))
		var arm := k.joint(hips, "Arm" + tag, Vector3(0.23 * side, 0.43, 0))
		k.part(arm, "Humerus", ModelKit.prism(4, Vector2(0.04, 0.04), Vector2(0.035, 0.035), 0.32), BONE, Vector3(0, -0.17, 0))
		k.part(arm, "Elbow", ModelKit.blob(Vector3(0.05, 0.045, 0.05), 6, 3), BONE, Vector3(0, -0.01, 0))
		var hand := k.joint(arm, "Hand" + tag, Vector3(0, -0.36, 0))
		k.part(hand, "Glove", ModelKit.blob(Vector3(0.07, 0.07, 0.07), 6, 3), LEATHER)
	k.joints["Arm.L"].rotation_degrees = Vector3(-30, 0, 4)
	k.joints["Arm.R"].rotation_degrees = Vector3(0, 0, -4)
	var player := BipedClips.animate(k, {"attack": &"shoot", "stride": 26.0, "bob": 0.04})
	_keep_upright(k, player, "Arm.L", "Hand.L")
	return k


## Adds to every clip a rotation track on `hand` that cancels `arm`'s pitch, so what the hand
## holds (a bow) stays upright however the arm swings.
static func _keep_upright(k: ModelKit, player: AnimationPlayer, arm: String, hand: String) -> void:
	var arm_path := "%s:rotation" % k.root.get_path_to(k.joints[arm])
	var hand_path := "%s:rotation" % k.root.get_path_to(k.joints[hand])
	for animation_name in player.get_animation_list():
		var animation := player.get_animation(animation_name)
		var source := animation.find_track(NodePath(arm_path), Animation.TYPE_VALUE)
		if source == -1:
			continue
		var track := animation.add_track(Animation.TYPE_VALUE)
		animation.track_set_path(track, NodePath(hand_path))
		animation.track_set_interpolation_type(track, animation.track_get_interpolation_type(source))
		animation.value_track_set_update_mode(track, Animation.UPDATE_CONTINUOUS)
		for key in animation.track_get_key_count(source):
			var value: Vector3 = animation.track_get_key_value(source, key)
			animation.track_insert_key(track, animation.track_get_key_time(source, key), Vector3(-value.x, 0, 0))
	k.joints[hand].rotation = Vector3(-k.joints[arm].rotation.x, 0, 0)
