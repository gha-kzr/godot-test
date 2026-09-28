class_name UnitState
extends RefCounted
## Per-battle values of one unit. The UnitData template is shared and never mutated.

enum Team { PLAYER, ENEMY }

var id: int
var data: UnitData
var team: Team
var cell: Vector2i
var hp: int
var ap: int
var mp: int


func _init(unit_id: int, unit_data: UnitData, unit_team: Team, start_cell: Vector2i) -> void:
	id = unit_id
	data = unit_data
	team = unit_team
	cell = start_cell
	hp = unit_data.max_hp
	ap = unit_data.ap
	mp = unit_data.mp


func is_alive() -> bool:
	return hp > 0


## Refills AP and MP. Called when the unit's turn starts.
func start_turn() -> void:
	ap = data.ap
	mp = data.mp


func clone() -> UnitState:
	var copy := UnitState.new(id, data, team, cell)
	copy.hp = hp
	copy.ap = ap
	copy.mp = mp
	return copy
