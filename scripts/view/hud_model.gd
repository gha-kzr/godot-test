class_name HudModel
extends RefCounted
## What the HUD displays, kept up to date from the event stream instead of read from the
## battle state: the state is already final while events play, so showing it would jump
## ahead of the animations. The model starts from the state (from_state), follows each
## played event (apply), and the controller re-syncs it from the state after a playback
## (the state stays the source of truth; this only mirrors it in between).

## Displayed info per unit id.
var infos: Dictionary[int, UnitInfo] = {}
var round_number := 1
## The unit whose turn it is, or -1 (before the battle starts, once it's over).
var current_id := -1
## Living units in turn order (a cycle; `current_id` marks where it is).
var _order: Array[int] = []
## Where the next unit sits in `_order` once the current unit died on its own turn.
var _resume_index := 0


## `levels`: the heroes' levels by unit id (players come first), as the controller has them.
static func from_state(state: BattleState, levels: Array = []) -> HudModel:
	var model := HudModel.new()
	for unit in state.units:
		var level := int(levels[unit.id]) if unit.team == UnitState.Team.PLAYER and unit.id < levels.size() else 0
		model.infos[unit.id] = UnitInfo.from_unit(unit, level, state.pvp)
	model.round_number = state.turn_order.round_number
	model._order.assign(state.turn_order.upcoming())
	if state.started and not state.is_over():
		model.current_id = state.current_unit().id
	return model


## Unit infos in the order they'll act, the current one first (all living units).
func upcoming() -> Array[UnitInfo]:
	var result: Array[UnitInfo] = []
	var start := _order.find(current_id)
	if start == -1 and not _order.is_empty():
		start = _resume_index % _order.size()
	for offset in _order.size():
		result.append(infos[_order[(maxi(start, 0) + offset) % _order.size()]])
	return result


## The info of the unit whose turn it is, or null.
func current() -> UnitInfo:
	return infos.get(current_id)


## Updates the displayed values for one played event.
func apply(event: BattleEvents.Event) -> void:
	if event is BattleEvents.TurnStarted:
		var started := event as BattleEvents.TurnStarted
		current_id = started.unit_id
		round_number = started.round_number
		var info := infos[started.unit_id]
		info.ap = started.ap
		info.mp = started.mp
		for slot in info.cooldowns.size():
			info.cooldowns[slot] = maxi(0, info.cooldowns[slot] - 1)
		for status in info.statuses:
			status.counting = true
	elif event is BattleEvents.TurnEnded:
		var info := infos[(event as BattleEvents.TurnEnded).unit_id]
		for status in info.statuses:
			if status.counting:
				status.counting = false
				status.turns_left -= 1
	elif event is BattleEvents.UnitMoved:
		var moved := event as BattleEvents.UnitMoved
		infos[moved.unit_id].mp -= moved.mp_spent
	elif event is BattleEvents.SpellCast:
		var cast := event as BattleEvents.SpellCast
		var caster := infos[cast.caster_id]
		caster.ap -= cast.ap_spent
		var slot := caster.spells.find(cast.spell)
		if slot != -1 and cast.spell.cooldown > 0:
			caster.cooldowns[slot] = cast.spell.cooldown
	elif event is BattleEvents.DamageDealt:
		var hit := event as BattleEvents.DamageDealt
		infos[hit.unit_id].hp = hit.hp_after
	elif event is BattleEvents.Healed:
		var healed := event as BattleEvents.Healed
		infos[healed.unit_id].hp = healed.hp_after
	elif event is BattleEvents.StatusApplied:
		_apply_status(event as BattleEvents.StatusApplied)
	elif event is BattleEvents.StatusTicked:
		var ticked := event as BattleEvents.StatusTicked
		var status := _find_status(infos[ticked.unit_id], ticked.status)
		if status != null:
			status.turns_left = ticked.turns_left
	elif event is BattleEvents.StatusExpired:
		var expired := event as BattleEvents.StatusExpired
		var info := infos[expired.unit_id]
		var status := _find_status(info, expired.status)
		if status != null:
			info.statuses.erase(status)
			info.max_ap -= status.ap_bonus
			info.max_mp -= status.mp_bonus
	elif event is BattleEvents.UnitDied:
		var id := (event as BattleEvents.UnitDied).unit_id
		infos[id].hp = 0
		if id == current_id:
			_resume_index = _order.find(id)
		_order.erase(id)
	elif event is BattleEvents.BattleEnded:
		current_id = -1


## Mirrors UnitState.add_status: a recast replaces the old one in place, and current AP
## and MP shift by the change in their maxima.
func _apply_status(applied: BattleEvents.StatusApplied) -> void:
	var info := infos[applied.unit_id]
	var fresh := StatusInfo.from_data(applied.status, applied.turns_left)
	var previous := _find_status(info, applied.status)
	var ap_delta := fresh.ap_bonus
	var mp_delta := fresh.mp_bonus
	if previous != null:
		ap_delta -= previous.ap_bonus
		mp_delta -= previous.mp_bonus
		info.statuses[info.statuses.find(previous)] = fresh
	else:
		info.statuses.append(fresh)
	info.max_ap += ap_delta
	info.max_mp += mp_delta
	info.ap = maxi(0, info.ap + ap_delta)
	info.mp = maxi(0, info.mp + mp_delta)


static func _find_status(info: UnitInfo, data: StatusData) -> StatusInfo:
	for status in info.statuses:
		if status.data == data:
			return status
	return null
