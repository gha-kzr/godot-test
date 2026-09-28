class_name TurnOrder
extends RefCounted
## Initiative order of unit ids: highest initiative first, ties broken by lower id.
## Dead units are removed; the order wraps around into a new round.

var round_number := 1
var _order: Array[int] = []
var _index := 0
## True between removing the current unit and the next advance().
var _current_removed := false


static func from_units(units: Array[UnitState]) -> TurnOrder:
	var sorted := units.duplicate()
	sorted.sort_custom(func(a: UnitState, b: UnitState) -> bool:
		if a.initiative() != b.initiative():
			return a.initiative() > b.initiative()
		return a.id < b.id)
	var turn_order := TurnOrder.new()
	for unit in sorted:
		turn_order._order.append(unit.id)
	return turn_order


func current_unit_id() -> int:
	if _current_removed or _order.is_empty():
		return -1
	return _order[_index]


## Moves to the next unit and returns its id. Wrapping past the end starts a new round.
func advance() -> int:
	_current_removed = false
	if _order.is_empty():
		return -1
	_index += 1
	if _index >= _order.size():
		_index = 0
		round_number += 1
	return current_unit_id()


## Removes a unit (e.g. on death). Whose turn it is doesn't change; if the removed unit
## was the current one, current_unit_id() is -1 until advance() moves to the next unit.
func remove(unit_id: int) -> void:
	var position := _order.find(unit_id)
	if position == -1:
		return
	_order.remove_at(position)
	if position == _index:
		_current_removed = true
	if position <= _index:
		_index -= 1


## Unit ids in the order they'll act, starting with the current unit.
func upcoming() -> Array[int]:
	var result: Array[int] = []
	if _order.is_empty():
		return result
	var start := posmod(_index + 1, _order.size()) if _current_removed else _index
	for offset in _order.size():
		result.append(_order[(start + offset) % _order.size()])
	return result


func clone() -> TurnOrder:
	var copy := TurnOrder.new()
	copy.round_number = round_number
	copy._order = _order.duplicate()
	copy._index = _index
	copy._current_removed = _current_removed
	return copy
