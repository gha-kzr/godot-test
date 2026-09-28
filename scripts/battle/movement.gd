class_name Movement
extends RefCounted
## Movement rules: which cells a unit can reach with its MP, and by which path.
## Dijkstra flood fill over the 4-neighbour grid. Step cost depends on the height
## difference between the two cells, so costs live on edges, not on cells.

## A step can climb at most this many levels.
const MAX_CLIMB := 1
## A step can drop at most this many levels.
const MAX_DROP := 2
## Base MP cost of a step.
const STEP_COST := 1
## Extra MP per level climbed. Dropping is free.
const CLIMB_COST_PER_LEVEL := 1


## Result of a flood fill from one unit's cell. Read-only.
class Reach:
	var origin: Vector2i
	var _costs: Dictionary[Vector2i, int]
	var _came_from: Dictionary[Vector2i, Vector2i]

	func _init(start: Vector2i, costs: Dictionary[Vector2i, int], came_from: Dictionary[Vector2i, Vector2i]) -> void:
		origin = start
		_costs = costs
		_came_from = came_from

	## Reachable destination cells, excluding the origin.
	func cells() -> Array[Vector2i]:
		var result: Array[Vector2i] = []
		for cell in _costs:
			if cell != origin:
				result.append(cell)
		return result

	func can_reach(cell: Vector2i) -> bool:
		return cell != origin and _costs.has(cell)

	## MP needed to reach the cell, or -1 if unreachable.
	func cost_to(cell: Vector2i) -> int:
		return _costs.get(cell, -1)

	## Cells to walk through, excluding the origin and including the destination.
	## Empty if unreachable.
	func path_to(cell: Vector2i) -> Array[Vector2i]:
		var path: Array[Vector2i] = []
		if not can_reach(cell):
			return path
		var current := cell
		while current != origin:
			path.push_front(current)
			current = _came_from[current]
		return path


## MP cost of stepping between two adjacent cells, or -1 if the step is impossible
## because of terrain. Units are not considered here.
static func step_cost(grid: Grid, from: Vector2i, to: Vector2i) -> int:
	if not grid.is_walkable(to):
		return -1
	var rise := grid.height_at(to) - grid.height_at(from)
	if rise > MAX_CLIMB or -rise > MAX_DROP:
		return -1
	return STEP_COST + maxi(rise, 0) * CLIMB_COST_PER_LEVEL


## Every cell the unit can end its move on with its current MP.
## Living units block their cells, allies included.
## Takes a unit id, not a UnitState: the unit is looked up in `state`, so the same call
## works on the real state and on AI clones.
static func reach(state: BattleState, unit_id: int) -> Reach:
	var unit := state.units[unit_id]
	var costs: Dictionary[Vector2i, int] = {unit.cell: 0}
	var came_from: Dictionary[Vector2i, Vector2i] = {}
	var frontier: Array[Vector2i] = [unit.cell]

	while not frontier.is_empty():
		var current := _pop_cheapest(frontier, costs)
		for next in state.grid.neighbors(current):
			var step := step_cost(state.grid, current, next)
			if step < 0 or state.is_occupied(next):
				continue
			var cost := costs[current] + step
			if cost > unit.mp:
				continue
			if not costs.has(next) or cost < costs[next]:
				costs[next] = cost
				came_from[next] = current
				if next not in frontier:
					frontier.append(next)
	return Reach.new(unit.cell, costs, came_from)


## Linear scan is fine at battle-map sizes (~100 cells). First-in wins ties,
## which keeps paths deterministic.
static func _pop_cheapest(frontier: Array[Vector2i], costs: Dictionary[Vector2i, int]) -> Vector2i:
	var best := 0
	for i in range(1, frontier.size()):
		if costs[frontier[i]] < costs[frontier[best]]:
			best = i
	var cell := frontier[best]
	frontier.remove_at(best)
	return cell


## MP cost of walking from every cell to the nearest of `goals`, over several turns
## (a "Dijkstra map"). Units are ignored, since they move between turns.
## Cells that can't reach any goal are absent. Runs backwards from the goals, using
## the cost of the step *into* each cell, because climbing and dropping cost differently.
static func distances_to(grid: Grid, goals: Array[Vector2i]) -> Dictionary[Vector2i, int]:
	var costs: Dictionary[Vector2i, int] = {}
	var frontier: Array[Vector2i] = []
	for goal in goals:
		costs[goal] = 0
		frontier.append(goal)

	while not frontier.is_empty():
		var current := _pop_cheapest(frontier, costs)
		for previous in grid.neighbors(current):
			if not grid.is_walkable(previous):
				continue
			var step := step_cost(grid, previous, current)
			if step < 0:
				continue
			var cost := costs[current] + step
			if not costs.has(previous) or cost < costs[previous]:
				costs[previous] = cost
				if previous not in frontier:
					frontier.append(previous)
	return costs
