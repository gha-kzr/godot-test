class_name Battle
extends RefCounted
## Single entry point that mutates a battle: validates an action, applies it, then
## handles deaths, victory and turn changes. Returns every event in order.
## Wrap a clone (Battle.new(state.clone())) to simulate without touching the real battle.
##
## Turn end: the unit's statuses count down (expired ones are removed), then TurnEnded.
## Turn start: TurnStarted, the unit's statuses tick, deaths are checked; a unit killed by
## its own ticks is skipped and the next one starts; otherwise it refills AP and MP.

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
	return _start_turns(false)


func perform(action: BattleActions.Action) -> Result:
	var result := Result.new()
	result.error = action.validate(state)
	if not result.ok():
		return result

	var alive_before := _alive_ids()
	result.events = action.apply(state)
	result.events.append_array(_report_deaths(alive_before))
	if state.is_over():
		return result

	# A turn ends when asked, or when the acting unit died during its own turn.
	var actor := state.units[action.actor_id]
	if action is BattleActions.EndTurn or not actor.is_alive():
		if actor.is_alive():
			result.events.append_array(_end_turn(actor))
		result.events.append_array(_start_turns(true))
	return result


## Statuses count down on the turns that started with them on; expired ones are removed.
func _end_turn(unit: UnitState) -> Array[BattleEvents.Event]:
	var events: Array[BattleEvents.Event] = []
	for status in unit.statuses.duplicate():
		if not status.counting:
			continue
		status.counting = false
		status.turns_left -= 1
		if status.turns_left <= 0:
			unit.statuses.erase(status)
			events.append(BattleEvents.StatusExpired.new(unit.id, status.data))
	events.append(BattleEvents.TurnEnded.new(unit.id))
	return events


## Starts the next living unit's turn (or the current one's, for the first turn). Loops
## past units that die to their own ticks; stops if the battle ends. Always terminates:
## each pass either starts a living unit's turn or removes a unit from the turn order.
func _start_turns(advance_first: bool) -> Array[BattleEvents.Event]:
	var events: Array[BattleEvents.Event] = []
	var advance := advance_first
	while true:
		if advance:
			state.turn_order.advance()
		advance = true
		var unit := state.current_unit()
		events.append(BattleEvents.TurnStarted.new(unit.id, state.turn_order.round_number))
		var alive_before := _alive_ids()
		events.append_array(_tick_statuses(unit))
		events.append_array(_report_deaths(alive_before))
		if state.is_over():
			break
		if unit.is_alive():
			unit.start_turn()
			break
	return events


## Fires each status's tick effects on its carrier, in application order, as if cast by
## the status's caster (even a dead one). Every status on at turn start counts this turn.
func _tick_statuses(unit: UnitState) -> Array[BattleEvents.Event]:
	var events: Array[BattleEvents.Event] = []
	for status in unit.statuses.duplicate():
		status.counting = true
		if status.data.tick_effects.is_empty() or not unit.is_alive():
			continue
		events.append(BattleEvents.StatusTicked.new(unit.id, status.data))
		for effect in status.data.tick_effects:
			if unit.is_alive():
				events.append_array(effect.apply(state, status.caster_id, unit.id))
	return events


## Every unit that died since `alive_before` leaves the turn order (UnitDied each); if a
## team is wiped out, BattleEnded follows. Deaths are detected here whatever caused them.
func _report_deaths(alive_before: Array[int]) -> Array[BattleEvents.Event]:
	var events: Array[BattleEvents.Event] = []
	for id in alive_before:
		if not state.units[id].is_alive():
			events.append(BattleEvents.UnitDied.new(id))
			state.turn_order.remove(id)
	if not events.is_empty() and state.is_over():
		events.append(BattleEvents.BattleEnded.new(state.outcome()))
	return events


func _alive_ids() -> Array[int]:
	var ids: Array[int] = []
	for unit in state.units:
		if unit.is_alive():
			ids.append(unit.id)
	return ids
