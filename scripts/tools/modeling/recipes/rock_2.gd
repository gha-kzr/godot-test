extends RefCounted
## A board rock: a cluster of tapering stone pillars with pointed tops (see rock_1 for how the
## board stretches it).

const FOOT := Color(0.38, 0.37, 0.4)
const SHAFT := Color(0.54, 0.53, 0.57)
const TIP := Color(0.74, 0.73, 0.78)


static func build() -> ModelKit:
	var k := ModelKit.new()
	k.part(null, "Base", ModelKit.prism(7, Vector2(0.5, 0.48), Vector2(0.4, 0.38), 0.22), FOOT, Vector3(0, 0.11, 0))
	k.part(null, "Pillar", ModelKit.prism(6, Vector2(0.3, 0.28), Vector2(0.2, 0.19), 0.6), SHAFT, Vector3(0.02, 0.5, 0.0))
	k.part(null, "PillarTip", ModelKit.prism(6, Vector2(0.2, 0.19), Vector2(0.0, 0.0), 0.3), TIP, Vector3(0.02, 0.95, 0.0))
	k.part(null, "Side", ModelKit.prism(5, Vector2(0.2, 0.2), Vector2(0.12, 0.12), 0.45), SHAFT, Vector3(-0.28, 0.42, 0.18), Vector3(8, 0, 12))
	k.part(null, "SideTip", ModelKit.prism(5, Vector2(0.12, 0.12), Vector2(0.0, 0.0), 0.22), TIP, Vector3(-0.3, 0.76, 0.19), Vector3(8, 0, 12))
	k.part(null, "Small", ModelKit.prism(5, Vector2(0.17, 0.17), Vector2(0.09, 0.09), 0.38), SHAFT, Vector3(0.3, 0.38, -0.2), Vector3(-6, 0, -10))
	k.part(null, "SmallTip", ModelKit.prism(5, Vector2(0.09, 0.09), Vector2(0.0, 0.0), 0.2), TIP, Vector3(0.31, 0.66, -0.21), Vector3(-6, 0, -10))
	return k
