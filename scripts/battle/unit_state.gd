class_name UnitState
extends RefCounted
## Per-battle values of one unit. The UnitData template is shared and never mutated.
## Statuses change numbers through modifiers that are added up when asked (max_ap(),
## max_mp(), damage_taken_percent()); nothing is stored, so expiry has nothing to undo.

enum Team { PLAYER, ENEMY }

var id: int
var data: UnitData
var team: Team
var cell: Vector2i
var hp: int
var ap: int
var mp: int
## In application order, which is also tick order.
var statuses: Array[StatusInstance] = []


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


## Refills AP and MP, modifiers included. Called when the unit's turn starts.
func start_turn() -> void:
	ap = max_ap()
	mp = max_mp()


## Sum of the active statuses' modifiers for one stat.
func stat_bonus(stat: StatModifier.Stat) -> int:
	var total := 0
	for status in statuses:
		for modifier in status.data.modifiers:
			if modifier.stat == stat:
				total += modifier.amount
	return total


func max_ap() -> int:
	return maxi(0, data.ap + stat_bonus(StatModifier.Stat.AP))


func max_mp() -> int:
	return maxi(0, data.mp + stat_bonus(StatModifier.Stat.MP))


## Percent of incoming damage the unit takes (100 = normal), never below 0.
func damage_taken_percent() -> int:
	return maxi(0, 100 + stat_bonus(StatModifier.Stat.DAMAGE_TAKEN_PERCENT))


func find_status(status: StatusData) -> StatusInstance:
	for instance in statuses:
		if instance.data == status:
			return instance
	return null


## Puts a status on the unit for its full duration. If the unit already has it, the new
## one replaces it (keeping its place in tick order). Current AP and MP shift at once by
## the change in their maxima, so a replaced status only shifts by the difference.
func add_status(status: StatusData, caster_id: int) -> StatusInstance:
	var ap_before := max_ap()
	var mp_before := max_mp()
	var instance := StatusInstance.new(status, caster_id, status.duration)
	var previous := find_status(status)
	if previous != null:
		statuses[statuses.find(previous)] = instance
	else:
		statuses.append(instance)
	ap = maxi(0, ap + max_ap() - ap_before)
	mp = maxi(0, mp + max_mp() - mp_before)
	return instance


func clone() -> UnitState:
	var copy := UnitState.new(id, data, team, cell)
	copy.hp = hp
	copy.ap = ap
	copy.mp = mp
	for status in statuses:
		copy.statuses.append(status.clone())
	return copy
