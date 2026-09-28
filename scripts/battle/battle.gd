class_name Battle
extends RefCounted
## Single entry point that mutates a battle: validates an action, applies it, then
## handles deaths, victory and turn changes. Returns every event in order.
## Wrap a clone (Battle.new(state.clone())) to simulate without touching the real battle.

var state: BattleState
var _started := false


class Result:
	var error := ""  ## Empty on success.
	var events: Array[BattleEvents.Event] = []

	func ok() -> bool:
		return error.is_empty()


func _init(battle_state: BattleState) -> void:
	state = battle_state


## Starts the first unit's turn. Call once before the first action.
func start() -> Array[BattleEvents.Event]:
	if _started or state.is_over():
		push_error("Battle.start: already started or over")
		return []
	_started = true
	return _start_turn()


func perform(action: BattleActions.Action) -> Result:
	var result := Result.new()
	result.error = action.validate(state)
	if not result.ok():
		return result

	var alive_before := state.units.filter(func(unit: UnitState) -> bool: return unit.is_alive())
	result.events = action.apply(state)
	# Every death is detected here, whatever caused it (area hit, recoil, ...).
	for unit: UnitState in alive_before:
		if not unit.is_alive():
			result.events.append(BattleEvents.UnitDied.new(unit.id))
			state.turn_order.remove(unit.id)

	if state.is_over():
		result.events.append(BattleEvents.BattleEnded.new(state.outcome()))
		return result

	# A turn ends when asked, or when the acting unit died during its own turn.
	var actor_died := not state.units[action.actor_id].is_alive()
	if action is BattleActions.EndTurn or actor_died:
		if not actor_died:
			result.events.append(BattleEvents.TurnEnded.new(action.actor_id))
		state.turn_order.advance()
		result.events.append_array(_start_turn())
	return result


func _start_turn() -> Array[BattleEvents.Event]:
	var unit := state.current_unit()
	unit.start_turn()
	return [BattleEvents.TurnStarted.new(unit.id, state.turn_order.round_number)]
