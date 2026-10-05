extends RefCounted
## A board rock: a stack of three faceted boulders, dark and wide at the foot, lighter at the top.
## The board stretches a rock to the obstacle's cube (one cell wide and deep, as tall as the
## obstacle), so each rock fills a 1 x 1 x 1 box and keeps its shape under a stretch in height.

const FOOT := Color(0.4, 0.38, 0.37)
const MIDDLE := Color(0.55, 0.53, 0.51)
const TOP := Color(0.72, 0.7, 0.66)


static func build() -> ModelKit:
	var k := ModelKit.new()
	k.part(null, "Foot", ModelKit.blob(Vector3(0.5, 0.34, 0.5), 7, 3), FOOT, Vector3(0, 0.3, 0))
	k.part(null, "Middle", ModelKit.blob(Vector3(0.4, 0.3, 0.38), 7, 3), MIDDLE, Vector3(-0.04, 0.6, 0.02), Vector3(0, 25, 0))
	k.part(null, "Top", ModelKit.blob(Vector3(0.26, 0.22, 0.25), 6, 3), TOP, Vector3(0.06, 0.82, -0.03), Vector3(0, -15, 0))
	return k
