class_name UnitsView
extends Node3D
## Holds one UnitView per unit, looked up by unit id.

const UNIT_VIEW_SCENE := preload("res://scenes/battle/unit_view.tscn")

var _views: Dictionary[int, UnitView] = {}
## The team of the player looking at the board: a unit in stealth is not drawn for the other team, and is see-through for
## its own.
var viewer_team := UnitState.Team.PLAYER


func build(state: BattleState, board: BoardView) -> void:
	for child in get_children():
		remove_child(child)  # Out of the tree now, freed at the end of the frame.
		child.queue_free()
	_views.clear()
	for unit in state.units:
		var view := UNIT_VIEW_SCENE.instantiate() as UnitView
		add_child(view)  # Before setup(), so its @onready nodes are set.
		view.setup(unit, board)
		_views[unit.id] = view
	# Everyone starts facing the nearest unit of the other team.
	for unit in state.units:
		var nearest: UnitState = null
		for other in state.units:
			if other.team != unit.team and (nearest == null or Targeting.distance(unit.cell, other.cell) < Targeting.distance(unit.cell, nearest.cell)):
				nearest = other
		if nearest != null:
			_views[unit.id].face_cell(nearest.cell)


## Snaps every view to the state (see UnitView.sync).
func sync(state: BattleState) -> void:
	for unit in state.units:
		if _views.has(unit.id):
			_views[unit.id].sync(unit, state.is_hidden_from(unit, viewer_team))


## Shows or hides units that went into or out of stealth (or were found), without moving anything; a hero in stealth
## that the viewer can see (its own team's) is drawn see-through.
func refresh_visibility(state: BattleState) -> void:
	for unit in state.units:
		if _views.has(unit.id):
			var hidden := state.is_hidden_from(unit, viewer_team)
			_views[unit.id].set_hidden_from_viewer(hidden)
			_views[unit.id].set_ghost(unit.is_alive() and unit.is_stealthed() and not hidden)


## Marks the unit whose turn it is (-1 for none).
func set_active(unit_id: int) -> void:
	for id in _views:
		_views[id].set_active(id == unit_id)


## Shows a damage preview badge on each entry's unit and none on the others.
func show_previews(entries: Array[DamagePreview.Entry]) -> void:
	clear_previews()
	for entry in entries:
		if _views.has(entry.unit_id):
			_views[entry.unit_id].show_preview(entry)


func clear_previews() -> void:
	for id in _views:
		_views[id].clear_preview()


## Whether a living unit is drawn on the cell.
func has_unit_at(cell: Vector2i) -> bool:
	for id in _views:
		if _views[id].picked_cell() == cell:
			return true
	return false


## The view of a unit, or null (without an error) for -1 or an unknown id.
func find_view(unit_id: int) -> UnitView:
	return _views.get(unit_id)


func view(unit_id: int) -> UnitView:
	if not _views.has(unit_id):
		push_error("UnitsView: no view for unit %d" % unit_id)
		return null
	return _views[unit_id]
