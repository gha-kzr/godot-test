@tool
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


## Result of a flood fill from where a unit's move segment started. Read-only.
class Reach:
	## Where the flood started: the unit's cell, or where it stood before repositioning.
	var origin: Vector2i
	## Where the unit stands now (not a destination; the origin is one after a move).
	var standing: Vector2i
	## The MP the flood had from the origin (the unit's MP plus any repositioning refund).
	var origin_budget: int
	var _costs: Dictionary[Vector2i, int]
	var _came_from: Dictionary[Vector2i, Vector2i]
	## Cells walked through but not ends of a move (allies stand there).
	var _pass_only: Dictionary[Vector2i, bool]

	func _init(start: Vector2i, costs: Dictionary[Vector2i, int], came_from: Dictionary[Vector2i, Vector2i],
			pass_only: Dictionary[Vector2i, bool] = {}, standing_cell := start, budget := 0) -> void:
		origin = start
		standing = standing_cell
		origin_budget = budget
		_costs = costs
		_came_from = came_from
		_pass_only = pass_only

	## Reachable destination cells, excluding where the unit stands.
	func cells() -> Array[Vector2i]:
		var result: Array[Vector2i] = []
		for cell in _costs:
			if cell != standing and cell not in _pass_only:
				result.append(cell)
		return result

	func can_reach(cell: Vector2i) -> bool:
		return cell != standing and _costs.has(cell) and cell not in _pass_only

	## MP needed to reach the cell from the origin, or -1 if unreachable (or an ally stands there).
	func cost_to(cell: Vector2i) -> int:
		return _costs.get(cell, -1) if cell not in _pass_only else -1

	## Cells to walk through from the origin, excluding it and including the destination.
	## Empty if unreachable (or the origin itself).
	func path_to(cell: Vector2i) -> Array[Vector2i]:
		var path: Array[Vector2i] = []
		if not can_reach(cell) or cell == origin:
			return path
		var current := cell
		while current != origin:
			path.push_front(current)
			current = _came_from[current]
		return path


## The steps of `path` (from `origin`) that climb, each with its extra MP: cell → MP above
## the base step cost. For showing why a path costs what it does.
static func climbing_steps(grid: Grid, origin: Vector2i, path: Array[Vector2i]) -> Dictionary[Vector2i, int]:
	var steps: Dictionary[Vector2i, int] = {}
	var previous := origin
	for cell in path:
		var rise := grid.height_at(cell) - grid.height_at(previous)
		if rise > 0:
			steps[cell] = rise * CLIMB_COST_PER_LEVEL
		previous = cell
	return steps


## MP cost of stepping between two adjacent cells, or -1 if the step is impossible
## because of terrain. Units are not considered here.
static func step_cost(grid: Grid, from: Vector2i, to: Vector2i) -> int:
	if not grid.is_walkable(to):
		return -1
	var rise := grid.height_at(to) - grid.height_at(from)
	if rise > MAX_CLIMB or -rise > MAX_DROP:
		return -1
	return STEP_COST + maxi(rise, 0) * CLIMB_COST_PER_LEVEL


## Every cell the unit can end its move on: what its move segment's MP reaches from where
## the segment started (its cell, or where it stood before repositioning; see UnitState).
## Enemies block their cells; allies can be walked through but not stopped on.
## Takes a unit id, not a UnitState: the unit is looked up in `state`, so the same call
## works on the real state and on AI clones.
static func reach(state: BattleState, unit_id: int) -> Reach:
	var unit := state.units[unit_id]
	var start := unit.move_start()
	return _flood(state, unit_id, start, unit.move_budget(), unit.cell)


## The cells a unit would walk through from where it stands to `to` (excluding its cell,
## including `to`), with no MP limit: how a repositioning move is drawn. Empty if no walk
## leads there (e.g. back up a drop it can't climb).
static func walk_path(state: BattleState, unit_id: int, to: Vector2i) -> Array[Vector2i]:
	var unit := state.units[unit_id]
	return _flood(state, unit_id, unit.cell, 1 << 20, unit.cell).path_to(to)


static func _flood(state: BattleState, unit_id: int, start: Vector2i, budget: int, standing: Vector2i) -> Reach:
	var unit := state.units[unit_id]
	var costs: Dictionary[Vector2i, int] = {start: 0}
	var came_from: Dictionary[Vector2i, Vector2i] = {}
	var pass_only: Dictionary[Vector2i, bool] = {}
	var frontier: Array[Vector2i] = [start]

	while not frontier.is_empty():
		var current := _pop_cheapest(frontier, costs)
		for next in state.grid.neighbors(current):
			var step := step_cost(state.grid, current, next)
			if step < 0:
				continue
			var other := state.unit_at(next)
			if other != null and other.id != unit_id:
				if other.team != unit.team:
					continue
				pass_only[next] = true
			var cost := costs[current] + step
			if cost > budget:
				continue
			if not costs.has(next) or cost < costs[next]:
				costs[next] = cost
				came_from[next] = current
				if next not in frontier:
					frontier.append(next)
	return Reach.new(start, costs, came_from, pass_only, standing, budget)


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
