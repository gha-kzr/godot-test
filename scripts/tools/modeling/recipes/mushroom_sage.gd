extends RefCounted
## The Mushroom Sage: a stubby mushroom folk. A cream stem body on short legs, a face under a huge
## teal cap with pale spots (the silhouette piece), a mossy green skirt, and a staff.

const CAP := Color(0.28, 0.58, 0.78)
const CAP_DARK := Color(0.2, 0.42, 0.6)
const STEM := Color(0.93, 0.88, 0.75)
const STEM_DARK := Color(0.78, 0.7, 0.55)
const GILLS := Color(0.72, 0.62, 0.48)
const SPOT := Color(0.96, 0.96, 0.86)
const MOSS := Color(0.38, 0.58, 0.26)
const EYE := Color(0.08, 0.06, 0.1)


static func build() -> ModelKit:
	var k := ModelKit.new()
	var rig := k.joint(null, "Rig")
	for side in [1, -1]:
		var tag := ".L" if side == 1 else ".R"
		var leg := k.joint(rig, "Leg" + tag, Vector3(0.1 * side, 0.28, 0))
		k.part(leg, "Leg", ModelKit.prism(4, Vector2(0.075, 0.075), Vector2(0.065, 0.065), 0.2), STEM, Vector3(0, -0.12, 0))
		k.part(leg, "Foot", ModelKit.blob(Vector3(0.1, 0.06, 0.14), 6, 3), STEM_DARK, Vector3(0, -0.23, 0.03))
	var hips := k.joint(rig, "Hips", Vector3(0, 0.28, 0))
	k.part(hips, "Moss", ModelKit.prism(6, Vector2(0.24, 0.21), Vector2(0.19, 0.17), 0.08), MOSS, Vector3(0, 0.03, 0))
	k.part(hips, "Stem", ModelKit.prism(6, Vector2(0.18, 0.16), Vector2(0.22, 0.19), 0.34), STEM, Vector3(0, 0.22, 0))
	k.part(hips, "Ring", ModelKit.prism(8, Vector2(0.27, 0.25), Vector2(0.2, 0.19), 0.05), STEM_DARK, Vector3(0, 0.34, 0))
	k.part(hips, "MossTuft", ModelKit.wedge(0.1, 0.12, 0.08, 0.5), MOSS, Vector3(0.2, 0.06, 0.12), Vector3(0, 30, 20))
	var head := k.joint(hips, "Head", Vector3(0, 0.4, 0))
	k.part(head, "Face", ModelKit.blob(Vector3(0.18, 0.2, 0.17), 8, 4), STEM, Vector3(0, 0.07, 0))
	for side in [1, -1]:
		var tag := ".L" if side == 1 else ".R"
		k.part(head, "Eye" + tag, ModelKit.blob(Vector3(0.042, 0.058, 0.025), 5, 3), EYE, Vector3(0.075 * side, 0.08, 0.158))
		k.part(head, "Cheek" + tag, ModelKit.blob(Vector3(0.04, 0.025, 0.02), 5, 2), Color(0.95, 0.62, 0.5), Vector3(0.12 * side, 0.0, 0.14))
	k.part(head, "Gills", ModelKit.prism(8, Vector2(0.35, 0.31), Vector2(0.35, 0.31), 0.03), GILLS, Vector3(0, 0.25, 0))
	k.part(head, "Brim", ModelKit.prism(8, Vector2(0.4, 0.34), Vector2(0.34, 0.29), 0.07), CAP_DARK, Vector3(0, 0.29, 0))
	k.part(head, "Dome", ModelKit.blob(Vector3(0.34, 0.24, 0.29), 8, 4), CAP, Vector3(0, 0.38, 0))
	# Pale spots, each tilted to lie on the dome (centers on the ellipsoid, slightly sunk).
	k.part(head, "SpotTop", ModelKit.blob(Vector3(0.09, 0.035, 0.09), 6, 2), SPOT, Vector3(0, 0.615, -0.01))
	k.part(head, "SpotFront", ModelKit.blob(Vector3(0.08, 0.035, 0.08), 6, 2), SPOT, Vector3(0, 0.56, 0.15), Vector3(38, 0, 0))
	k.part(head, "SpotLeft", ModelKit.blob(Vector3(0.08, 0.035, 0.08), 6, 2), SPOT, Vector3(0.2, 0.54, -0.02), Vector3(0, 0, -40))
	k.part(head, "SpotRight", ModelKit.blob(Vector3(0.07, 0.03, 0.07), 6, 2), SPOT, Vector3(-0.17, 0.56, 0.07), Vector3(20, 0, 32))
	k.part(head, "SpotBack", ModelKit.blob(Vector3(0.08, 0.035, 0.08), 6, 2), SPOT, Vector3(-0.05, 0.55, -0.18), Vector3(-40, 0, 5))
	for side in [1, -1]:
		var tag := ".L" if side == 1 else ".R"
		var arm := k.joint(hips, "Arm" + tag, Vector3(0.21 * side, 0.36, 0))
		k.part(arm, "Arm", ModelKit.prism(4, Vector2(0.055, 0.055), Vector2(0.048, 0.048), 0.24), STEM, Vector3(0, -0.12, 0))
		var hand := k.joint(arm, "Hand" + tag, Vector3(0, -0.27, 0))
		k.part(hand, "Hand", ModelKit.blob(Vector3(0.065, 0.06, 0.065), 6, 3), STEM_DARK)
	k.joints["Arm.R"].rotation_degrees = Vector3(-30, 0, -6)
	k.joints["Arm.L"].rotation_degrees = Vector3(0, 0, 5)
	BipedClips.animate(k, {"attack": &"punch", "stride": 36.0, "bob": 0.06, "lie": 0.36})
	return k
