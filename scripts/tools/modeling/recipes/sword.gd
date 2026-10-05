extends RefCounted
## A knight's sword, grip at the origin, blade along +Y.


static func build() -> ModelKit:
	var k := ModelKit.new()
	var steel := Color(0.82, 0.86, 0.92)
	k.part(null, "Grip", ModelKit.box(Vector3(0.035, 0.14, 0.035)), Color(0.35, 0.22, 0.14))
	k.part(null, "Pommel", ModelKit.blob(Vector3(0.04, 0.035, 0.04), 6, 3), Color(0.9, 0.75, 0.3), Vector3(0, -0.085, 0))
	k.part(null, "Guard", ModelKit.box(Vector3(0.24, 0.035, 0.05)), Color(0.9, 0.75, 0.3), Vector3(0, 0.085, 0))
	k.part(null, "Blade", ModelKit.box(Vector3(0.07, 0.5, 0.022)), steel, Vector3(0, 0.355, 0))
	k.part(null, "Tip", ModelKit.prism(4, Vector2(0.035, 0.011), Vector2.ZERO, 0.12), steel, Vector3(0, 0.67, 0))
	return k
