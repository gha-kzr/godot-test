@tool
class_name Placement
extends RefCounted
## Where heroes start in their zone (the map's player spawns) before the player rearranges
## them: melee heroes on the cells closest to the enemies, ranged ones farther back. Pure logic.


## A cell per hero, in `heroes` order. When the zone has exactly one cell per hero (a
## hand-made map's authored spawns) the authored order is kept.
static func default_cells(grid: Grid, zone: Array[Vector2i], enemy_spawns: Array[Vector2i],
		heroes: Array[UnitData]) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	if zone.size() <= heroes.size():
		cells.assign(zone.slice(0, heroes.size()))
		return cells
	# Closest to the enemies first (walking distance; zone order breaks ties).
	var distances := Movement.distances_to(grid, enemy_spawns)
	var by_distance := range(zone.size())
	by_distance.sort_custom(func(a: int, b: int) -> bool:
		var da: int = distances.get(zone[a], 1 << 30)
		var db: int = distances.get(zone[b], 1 << 30)
		return da < db or (da == db and a < b))
	# Melee first (shortest reach; hero order breaks ties).
	var by_role := range(heroes.size())
	by_role.sort_custom(func(a: int, b: int) -> bool:
		var ra := reach_score(heroes[a])
		var rb := reach_score(heroes[b])
		return ra < rb or (ra == rb and a < b))
	# Spread over the zone by reach: the shortest reach on the closest cell, the longest on
	# the farthest, the others evenly between.
	cells.resize(heroes.size())
	var last := heroes.size() - 1
	for rank in by_role.size():
		var index := roundi(rank * (zone.size() - 1) / float(last)) if last > 0 else 0
		cells[by_role[rank]] = zone[by_distance[index]]
	return cells


## How far a hero hits: the average max range of its spells (lower = melee), ignoring
## self-only spells (range 0: Guard, Whirlwind), which say nothing about its reach.
static func reach_score(hero: UnitData) -> float:
	var total := 0
	var count := 0
	for spell in hero.spells:
		if spell != null and spell.max_range > 0:
			total += spell.max_range
			count += 1
	return float(total) / count if count > 0 else 0.0
