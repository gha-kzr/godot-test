@tool
class_name MoveEffect
extends EffectData
## Moves a unit: the caster (teleport, jump, charge, retreat) or each target (push, pull).
## Rules in docs/decisions/2026-10-03-hero-depth.md. A destination is always a free floor
## cell; a slide (push, pull, charge) follows the walking step rules (Movement.step_cost) and
## stops at the first cell it can't enter, without damage. Spells aimed with this effect only
## offer the cells it can use (allows_target).

enum Kind {
	TELEPORT,  ## The caster appears on the target cell: any free cell in range, any height.
	JUMP,  ## The caster leaps onto the target cell, over anything; climbs at most JUMP_CLIMB.
	CHARGE,  ## The caster dashes in a straight line to the cell next to the targeted unit.
	PUSH,  ## Each target slides `distance` cells straight away from the caster.
	PULL,  ## Each target slides `distance` cells straight toward the caster.
	RETREAT,  ## The caster leaps straight back from the target cell, up to `distance` cells.
}

## Levels a jump (or a retreat) can climb; it can drop any height.
const JUMP_CLIMB := 2

@export var kind := Kind.PUSH
## Cells for a push, a pull or a retreat (at most).
@export_range(1, 10) var distance := 2


func moves_caster() -> bool:
	return kind in [Kind.TELEPORT, Kind.JUMP, Kind.CHARGE, Kind.RETREAT]


## Needs the cast's target cell: a cast calls apply_cast(); apply() alone (a status tick)
## moves nobody.
func apply(_state: BattleState, _caster_id: int, _target_id: int) -> Array[BattleEvents.Event]:
	return []


func apply_cast(state: BattleState, caster_id: int, target_id: int, target_cell: Vector2i) -> Array[BattleEvents.Event]:
	var caster := state.units[caster_id]
	var path: Array[Vector2i] = []
	var mover := target_id
	match kind:
		Kind.TELEPORT, Kind.JUMP:
			mover = caster_id
			if _can_land(state, caster, target_cell):
				path = [target_cell]
		Kind.CHARGE:
			mover = caster_id
			path = _charge_path(state, caster, target_cell)
		Kind.RETREAT:
			mover = caster_id
			var landing := _retreat_cell(state, caster, target_cell)
			if landing != caster.cell:
				path = [landing]
		Kind.PUSH, Kind.PULL:
			if target_id == caster_id:
				return []  # Nobody pushes itself.
			path = _slide(state, caster, state.units[target_id])
	if path.is_empty():
		return []
	var unit := state.units[mover]
	var from := unit.cell
	unit.cell = path.back()
	return [BattleEvents.UnitDisplaced.new(mover, from, path, kind)]


func allows_target(state: BattleState, caster_id: int, cell: Vector2i) -> bool:
	var caster := state.units[caster_id]
	match kind:
		Kind.TELEPORT, Kind.JUMP:
			return _can_land(state, caster, cell)
		Kind.CHARGE:
			return state.is_occupied(cell) and _charge_reaches(state, caster, cell)
	return true


## A free floor cell; a jump also can't climb more than JUMP_CLIMB levels.
func _can_land(state: BattleState, caster: UnitState, cell: Vector2i) -> bool:
	if not state.grid.is_walkable(cell) or state.is_occupied(cell):
		return false
	return kind != Kind.JUMP or state.grid.height_at(cell) - state.grid.height_at(caster.cell) <= JUMP_CLIMB


## Same row or column, and every cell from the caster to the one next to the target is a
## free cell the caster could step into.
func _charge_reaches(state: BattleState, caster: UnitState, cell: Vector2i) -> bool:
	if cell.x != caster.cell.x and cell.y != caster.cell.y or cell == caster.cell:
		return false
	var direction := Vector2i(signi(cell.x - caster.cell.x), signi(cell.y - caster.cell.y))
	var previous := caster.cell
	var current := caster.cell + direction
	while current != cell:
		if state.is_occupied(current) or Movement.step_cost(state.grid, previous, current) < 0:
			return false
		previous = current
		current += direction
	return true


func _charge_path(state: BattleState, caster: UnitState, cell: Vector2i) -> Array[Vector2i]:
	var path: Array[Vector2i] = []
	if not _charge_reaches(state, caster, cell):
		return path
	var direction := Vector2i(signi(cell.x - caster.cell.x), signi(cell.y - caster.cell.y))
	var current := caster.cell + direction
	while current != cell:
		path.append(current)
		current += direction
	return path


## The farthest cell, straight away from `from`, up to `distance` cells, that the caster
## can land on without passing a cell it couldn't (it stops before the first one).
func _retreat_cell(state: BattleState, caster: UnitState, from: Vector2i) -> Vector2i:
	var direction := Targeting.dominant_direction(caster.cell - from)
	var landing := caster.cell
	if direction == Vector2i.ZERO:
		return landing
	for i in range(1, distance + 1):
		var cell := caster.cell + direction * i
		if not state.grid.is_walkable(cell) or state.is_occupied(cell) \
				or state.grid.height_at(cell) - state.grid.height_at(caster.cell) > JUMP_CLIMB:
			break
		landing = cell
	return landing


## The cells a pushed or pulled unit slides through, step by step until `distance` or the
## first cell it can't step into (a pull also stops next to the caster).
func _slide(state: BattleState, caster: UnitState, target: UnitState) -> Array[Vector2i]:
	var away := Targeting.dominant_direction(target.cell - caster.cell)
	var direction := away if kind == Kind.PUSH else -away
	var path: Array[Vector2i] = []
	if direction == Vector2i.ZERO:
		return path
	var current := target.cell
	for i in distance:
		var next := current + direction
		if state.is_occupied(next) or Movement.step_cost(state.grid, current, next) < 0:
			break
		path.append(next)
		current = next
	return path


func describe() -> String:
	match kind:
		Kind.TELEPORT:
			return tr("Teleports to the target cell")
		Kind.JUMP:
			return tr("Jumps to the target cell (climbs up to %d levels)") % JUMP_CLIMB
		Kind.CHARGE:
			return tr("Charges in a straight line next to the target")
		Kind.PUSH:
			return tr_n("Pushes back %d cell", "Pushes back %d cells", distance) % distance
		Kind.PULL:
			return tr_n("Pulls %d cell closer", "Pulls up to %d cells closer", distance) % distance
		Kind.RETREAT:
			return tr_n("Leaps back %d cell", "Leaps back up to %d cells", distance) % distance
	return ""


## No target filter suffix: who moves is in the description itself.
func full_description() -> String:
	return describe()


func get_validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	if moves_caster() and target_filter != TargetFilter.CASTER:
		errors.append("move effect %s moves the caster: its target_filter must be CASTER" % Kind.keys()[kind])
	if not moves_caster() and target_filter == TargetFilter.CASTER:
		errors.append("move effect %s moves its targets: its target_filter can't be CASTER" % Kind.keys()[kind])
	return errors
