extends RefCounted
## The Orc Guard's spiked club, grip at the origin, along +Y.


static func build() -> ModelKit:
	var k := ModelKit.new()
	var wood := Color(0.45, 0.3, 0.18)
	var steel := Color(0.7, 0.72, 0.78)
	k.part(null, "Handle", ModelKit.prism(6, Vector2(0.035, 0.035), Vector2(0.045, 0.045), 0.5), wood, Vector3(0, 0.1, 0))
	k.part(null, "Head", ModelKit.prism(6, Vector2(0.06, 0.06), Vector2(0.12, 0.12), 0.45), wood, Vector3(0, 0.55, 0))
	k.part(null, "Band", ModelKit.prism(6, Vector2(0.125, 0.125), Vector2(0.125, 0.125), 0.04), Color(0.3, 0.3, 0.34), Vector3(0, 0.48, 0))
	for index in 6:
		var angle := TAU * index / 6.0
		var outward := Vector3(sin(angle), 0.0, cos(angle))
		k.part(null, "Spike%d" % index, ModelKit.prism(4, Vector2(0.03, 0.03), Vector2.ZERO, 0.12), steel,
				outward * 0.13 + Vector3(0, 0.57, 0), Quaternion(Vector3.UP, outward).get_euler() * (180.0 / PI))
	k.part(null, "Tip", ModelKit.prism(4, Vector2(0.04, 0.04), Vector2.ZERO, 0.14), steel, Vector3(0, 0.84, 0))
	return k
