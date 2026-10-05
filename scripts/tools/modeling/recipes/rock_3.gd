extends RefCounted
## A board rock: broken slabs, a wide dark block with a tilted lighter slab and a ridge on top
## (see rock_1 for how the board stretches it).

const FOOT := Color(0.41, 0.39, 0.36)
const SLAB := Color(0.56, 0.54, 0.5)
const TOP := Color(0.7, 0.68, 0.62)


static func build() -> ModelKit:
	var k := ModelKit.new()
	k.part(null, "Block", ModelKit.prism(5, Vector2(0.5, 0.46), Vector2(0.42, 0.38), 0.5), FOOT, Vector3(0, 0.25, 0), Vector3(0, 18, 0))
	k.part(null, "Slab", ModelKit.prism(4, Vector2(0.4, 0.34), Vector2(0.3, 0.26), 0.36), SLAB, Vector3(-0.04, 0.66, 0.04), Vector3(4, 30, -7))
	k.part(null, "Ridge", ModelKit.wedge(0.5, 0.26, 0.34, 0.35), TOP, Vector3(0.0, 0.87, 0.0), Vector3(0, 55, 0))
	k.part(null, "Chip", ModelKit.wedge(0.24, 0.2, 0.22, 0.5), SLAB, Vector3(0.3, 0.1, 0.32), Vector3(0, -30, 0))
	return k
