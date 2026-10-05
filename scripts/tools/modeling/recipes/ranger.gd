extends RefCounted
## The Ranger: a green tunic, a pointed green cap with a feather, a quiver on the back, a bow in
## the left hand (the left arm aims, the right one draws). The left arm rests half raised so the
## bow is held forward; the Attack clip is corrected so the aim itself stays level.

const TUNIC := Color(0.3, 0.72, 0.4)
const HOOD := Color(0.2, 0.5, 0.3)
const LEATHER := Color(0.42, 0.28, 0.17)
const DARK_LEATHER := Color(0.3, 0.2, 0.13)
const TROUSER := Color(0.5, 0.4, 0.26)
const SKIN := Color(0.98, 0.84, 0.7)
const FEATHER := Color(0.95, 0.4, 0.25)
const FLETCH := Color(0.95, 0.92, 0.8)
const DARK := Color(0.08, 0.07, 0.07)


static func build() -> ModelKit:
	var k := ModelKit.new()
	var rig := k.joint(null, "Rig")
	for side in [1, -1]:
		var tag := ".L" if side == 1 else ".R"
		var leg := k.joint(rig, "Leg" + tag, Vector3(0.095 * side, 0.4, 0))
		k.part(leg, "Trouser", ModelKit.prism(4, Vector2(0.07, 0.075), Vector2(0.065, 0.065), 0.26), TROUSER, Vector3(0, -0.14, 0))
		k.part(leg, "Boot", ModelKit.prism(4, Vector2(0.08, 0.115), Vector2(0.07, 0.08), 0.16), LEATHER, Vector3(0, -0.32, 0.02))
		k.part(leg, "Cuff", ModelKit.prism(4, Vector2(0.085, 0.09), Vector2(0.085, 0.09), 0.04), DARK_LEATHER, Vector3(0, -0.25, 0))
	var hips := k.joint(rig, "Hips", Vector3(0, 0.4, 0))
	k.part(hips, "Skirt", ModelKit.prism(4, Vector2(0.23, 0.16), Vector2(0.18, 0.13), 0.2), TUNIC, Vector3(0, 0.0, 0))
	k.part(hips, "Belt", ModelKit.prism(4, Vector2(0.185, 0.135), Vector2(0.185, 0.135), 0.05), LEATHER, Vector3(0, 0.12, 0))
	k.part(hips, "Buckle", ModelKit.box(Vector3(0.06, 0.06, 0.03)), FLETCH, Vector3(0, 0.12, 0.14))
	k.part(hips, "Torso", ModelKit.prism(4, Vector2(0.18, 0.125), Vector2(0.22, 0.14), 0.32), TUNIC, Vector3(0, 0.29, 0))
	k.part(hips, "Collar", ModelKit.prism(4, Vector2(0.17, 0.13), Vector2(0.2, 0.15), 0.07), HOOD, Vector3(0, 0.47, 0))
	k.part(hips, "Strap", ModelKit.box(Vector3(0.05, 0.4, 0.02)), LEATHER, Vector3(0.0, 0.3, 0.135), Vector3(0, 0, -32))
	k.part(hips, "Quiver", ModelKit.prism(6, Vector2(0.06, 0.06), Vector2(0.075, 0.075), 0.42), LEATHER, Vector3(-0.07, 0.34, -0.17), Vector3(8, 0, 16))
	for index in 3:
		k.part(hips, "Arrow%d" % index, ModelKit.wedge(0.035, 0.12, 0.05, 0.5), FLETCH, Vector3(-0.115 + 0.04 * index, 0.58 + 0.015 * index, -0.19), Vector3(8, 0, 16))
	var head := k.joint(hips, "Head", Vector3(0, 0.5, 0))
	k.part(head, "Face", ModelKit.blob(Vector3(0.17, 0.18, 0.17), 8, 4), SKIN, Vector3(0, 0.15, 0.01))
	k.part(head, "Nose", ModelKit.blob(Vector3(0.03, 0.035, 0.04), 4, 2), SKIN, Vector3(0, 0.12, 0.18))
	k.part(head, "Hood", ModelKit.blob(Vector3(0.21, 0.2, 0.2), 8, 4), HOOD, Vector3(0, 0.2, -0.05))
	k.part(head, "Fringe", ModelKit.wedge(0.3, 0.07, 0.1, 0.5), HOOD, Vector3(0, 0.3, 0.14), Vector3(-10, 0, 0))
	for side in [1, -1]:
		k.part(head, "Eye%d" % side, ModelKit.box(Vector3(0.04, 0.05, 0.02)), DARK, Vector3(0.075 * side, 0.17, 0.17))
	k.part(head, "Brim", ModelKit.prism(8, Vector2(0.26, 0.26), Vector2(0.23, 0.23), 0.035), HOOD, Vector3(0, 0.31, -0.02))
	k.part(head, "Cap", ModelKit.prism(6, Vector2(0.19, 0.19), Vector2(0.08, 0.08), 0.18), HOOD, Vector3(0, 0.42, -0.04), Vector3(-8, 0, 0))
	k.part(head, "Peak", ModelKit.prism(6, Vector2(0.08, 0.08), Vector2.ZERO, 0.15), HOOD, Vector3(0, 0.56, -0.08), Vector3(-38, 0, 0))
	k.part(head, "Feather", ModelKit.wedge(0.035, 0.26, 0.1, 0.8), FEATHER, Vector3(0.16, 0.42, -0.1), Vector3(-30, 0, -22))
	for side in [1, -1]:
		var tag := ".L" if side == 1 else ".R"
		var arm := k.joint(hips, "Arm" + tag, Vector3(0.265 * side, 0.43, 0))
		k.part(arm, "Sleeve", ModelKit.prism(4, Vector2(0.075, 0.075), Vector2(0.065, 0.065), 0.2), TUNIC, Vector3(0, -0.1, 0))
		k.part(arm, "Bracer", ModelKit.prism(4, Vector2(0.062, 0.062), Vector2(0.056, 0.056), 0.15), LEATHER, Vector3(0, -0.27, 0))
		var hand := k.joint(arm, "Hand" + tag, Vector3(0, -0.35, 0))
		k.part(hand, "Fist", ModelKit.blob(Vector3(0.055, 0.055, 0.055), 6, 3), SKIN)
	# The bow hangs from Grip.L: hanging it stands upright whatever the arm's tilt; aiming it
	# turns upright again once the arm is level (see _aim_the_bow).
	k.joint(k.joints["Hand.L"], "Grip.L", Vector3.ZERO, Vector3(35, 0, 0))
	k.joints["Arm.L"].rotation_degrees = Vector3(-35, 0, 4)
	k.joints["Arm.R"].rotation_degrees = Vector3(0, 0, -4)
	BipedClips.animate(k, {"attack": &"shoot", "stride": 30.0})
	_keep_aim_level(k)
	_aim_the_bow(k)
	return k


## The left arm aims forward whatever its rest pose: in the Attack clip the keys that raise it
## (more than 40 degrees from rest) lose the rest angle, so the bow ends level, not raised.
static func _keep_aim_level(k: ModelKit) -> void:
	var player := k.root.get_node("AnimationPlayer") as AnimationPlayer
	var rest := k.joints["Arm.L"].rotation.x
	for clip in ["Attack", "Shoot"]:
		var animation := player.get_animation(clip)
		var track := animation.find_track(NodePath("%s:rotation" % k.root.get_path_to(k.joints["Arm.L"])), Animation.TYPE_VALUE)
		for index in animation.track_get_key_count(track):
			var value: Vector3 = animation.track_get_key_value(track, index)
			if absf(value.x - rest) > deg_to_rad(40.0):
				value.x -= rest
				animation.track_set_key_value(track, index, value)


## The bow (held on Grip.L) stands upright at rest (the grip is turned 35 degrees to cancel the
## arm's tilt); during the shot the arm is level, and the grip turns 90 degrees so the limbs
## stay upright.
static func _aim_the_bow(k: ModelKit) -> void:
	var player := k.root.get_node("AnimationPlayer") as AnimationPlayer
	var grip := k.joints["Grip.L"]
	var aimed := Vector3(deg_to_rad(90.0), 0, 0)
	for clip in [["Attack", 0.25, 0.52], ["Shoot", 0.1, 0.5]]:
		var animation := player.get_animation(clip[0])
		var track := animation.add_track(Animation.TYPE_VALUE)
		animation.track_set_path(track, NodePath("%s:rotation" % k.root.get_path_to(grip)))
		animation.track_set_interpolation_type(track, Animation.INTERPOLATION_LINEAR)
		animation.value_track_set_update_mode(track, Animation.UPDATE_CONTINUOUS)
		for key in [[0.0, grip.rotation], [clip[1], aimed], [clip[2], aimed], [animation.length, grip.rotation]]:
			animation.track_insert_key(track, key[0], key[1])
