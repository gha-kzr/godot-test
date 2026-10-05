extends RefCounted
## The Mushroom Sage's staff: a short gnarled pole with a small teal mushroom on top, held at the
## origin (the hand), the pole along +Y.


static func build() -> ModelKit:
	var k := ModelKit.new()
	var wood := Color(0.5, 0.36, 0.22)
	var cap := Color(0.28, 0.58, 0.78)
	k.part(null, "Pole", ModelKit.prism(6, Vector2(0.035, 0.035), Vector2(0.028, 0.028), 0.62), wood, Vector3(0, 0.11, 0))
	k.part(null, "Stem", ModelKit.prism(6, Vector2(0.05, 0.05), Vector2(0.04, 0.04), 0.1), Color(0.93, 0.88, 0.75), Vector3(0, 0.45, 0))
	k.part(null, "Cap", ModelKit.blob(Vector3(0.14, 0.09, 0.14), 8, 3), cap, Vector3(0, 0.53, 0))
	k.part(null, "Spot", ModelKit.blob(Vector3(0.04, 0.02, 0.04), 5, 2), Color(0.95, 0.95, 0.85), Vector3(0.03, 0.615, 0.04))
	return k
