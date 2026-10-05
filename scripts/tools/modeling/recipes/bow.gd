extends RefCounted
## A wooden bow held at the grip (the origin): the limbs along +Y, curving back toward -Z (the
## archer), the string on that side. The arrow flies toward +Z.


static func build() -> ModelKit:
	var k := ModelKit.new()
	var wood := Color(0.5, 0.33, 0.2)
	var string := Color(0.9, 0.88, 0.8)
	k.part(null, "Grip", ModelKit.box(Vector3(0.05, 0.14, 0.06)), Color(0.35, 0.22, 0.14))
	for side in [1, -1]:
		k.part(null, "Limb%d" % side, ModelKit.prism(4, Vector2(0.03, 0.025), Vector2(0.02, 0.018), 0.3), wood, Vector3(0, 0.2 * side, -0.02), Vector3(-12 * side, 0, 0))
		k.part(null, "Tip%d" % side, ModelKit.prism(4, Vector2(0.02, 0.018), Vector2(0.012, 0.012), 0.2), wood, Vector3(0, 0.42 * side, -0.09), Vector3(-34 * side, 0, 0))
	k.part(null, "String", ModelKit.box(Vector3(0.012, 0.8, 0.012)), string, Vector3(0, 0, -0.16))
	return k
