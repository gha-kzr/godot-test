extends RefCounted
## A mage's staff, held at the origin (the hand), the pole along +Y, a crystal on top.


static func build() -> ModelKit:
	var k := ModelKit.new()
	var wood := Color(0.45, 0.3, 0.18)
	var gold := Color(0.9, 0.75, 0.3)
	k.part(null, "Pole", ModelKit.prism(6, Vector2(0.03, 0.03), Vector2(0.026, 0.026), 1.4), wood, Vector3(0, 0.35, 0))
	k.part(null, "Cap", ModelKit.prism(6, Vector2(0.05, 0.05), Vector2(0.03, 0.03), 0.07), gold, Vector3(0, 1.03, 0))
	for side in [1, -1]:
		k.part(null, "Prong%d" % side, ModelKit.prism(4, Vector2(0.025, 0.02), Vector2.ZERO, 0.2), gold, Vector3(0.07 * side, 1.12, 0), Vector3(0, 0, -18 * side))
	k.part(null, "Crystal", ModelKit.blob(Vector3(0.06, 0.09, 0.06), 6, 3), Color(0.55, 0.45, 1.0), Vector3(0, 1.14, 0), Vector3.ZERO, 0.9)
	return k
