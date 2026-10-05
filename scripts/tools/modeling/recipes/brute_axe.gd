extends RefCounted
## The Brute's axe, grip at the origin, haft along +Y, the blade edge toward +Z.


static func build() -> ModelKit:
	var k := ModelKit.new()
	var wood := Color(0.42, 0.27, 0.16)
	var steel := Color(0.72, 0.75, 0.82)
	k.part(null, "Haft", ModelKit.prism(6, Vector2(0.032, 0.032), Vector2(0.032, 0.032), 0.95), wood, Vector3(0, 0.25, 0))
	k.part(null, "Pommel", ModelKit.blob(Vector3(0.04, 0.035, 0.04), 6, 3), Color(0.25, 0.18, 0.12), Vector3(0, -0.24, 0))
	k.part(null, "Socket", ModelKit.box(Vector3(0.07, 0.24, 0.07)), Color(0.4, 0.42, 0.48), Vector3(0, 0.62, 0))
	k.part(null, "Body", ModelKit.box(Vector3(0.045, 0.22, 0.2)), steel, Vector3(0, 0.62, 0.13))
	k.part(null, "Edge", ModelKit.box(Vector3(0.03, 0.5, 0.06)), Color(0.88, 0.9, 0.95), Vector3(0, 0.62, 0.27))
	for side in [1, -1]:
		k.part(null, "Flare%d" % side, ModelKit.box(Vector3(0.04, 0.2, 0.06)), steel, Vector3(0, 0.62 + 0.15 * side, 0.2), Vector3(-38 * side, 0, 0))
	k.part(null, "Spike", ModelKit.prism(4, Vector2(0.03, 0.03), Vector2.ZERO, 0.14), steel, Vector3(0, 0.82, 0))
	k.part(null, "Back", ModelKit.prism(4, Vector2(0.03, 0.04), Vector2.ZERO, 0.12), steel, Vector3(0, 0.62, -0.11), Vector3(-90, 0, 0))
	return k
