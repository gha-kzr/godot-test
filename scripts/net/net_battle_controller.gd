class_name NetBattleController
extends BattleController
## The multiplayer fight, on the same screen as every other battle. The battle itself lives in the
## MatchSession (the replicated log); this view keeps its own copy of the battle and animates what the
## log brings, one entry at a time: placement moves, the first turn, moves and casts, whoever made
## them. What the local player does becomes a proposal to the host; nothing changes on screen until
## the host's entry comes back. A hero played by the AI, or by a player who left, is simply a turn
## that is not mine: the screen waits and watches.

var session: MatchSession

var _queue: Array[Dictionary] = []
## The log entry (its number) this view has applied up to.
var _applied := 0
## Whether the local player's action is on its way to the host and back.
var _awaiting := false
## Whether an entry is being played (the next waits for it).
var _busy := false
## The player pressed Ready for their placement.
var _placed_pressed := false
## What the multiplayer fight plays at, for everyone: normal speed (the player's own battle speed setting is for solo
## battles; two players at different speeds would see the same match at different paces). Tests make it instant.
var play_speed := Settings.BattleSpeed.NORMAL
## The line about my own connection is shown once per loss.
var _lost_shown := false
## The button above End turn and the popup of quick messages it opens (a catcher for the clicks around, with the list).
var _say_button: Button
var _say_popup: Control

const SAY_ICON: Texture2D = preload("res://ui/icons/speech.svg")


## Call before the controller enters the tree.
func setup_net(match_session: MatchSession) -> void:
	session = match_session
	standalone = false
	sudden_death_round = MatchState.SUDDEN_DEATH_ROUND
	sudden_death_percent = MatchState.SUDDEN_DEATH_PERCENT
	battle_seed = int(session.state.settings["seed"])


func _ready() -> void:
	super._ready()
	hud.set_result_action_text("Back to the lobby")
	session.entry_applied.connect(_on_entry)
	session.rejected.connect(_on_rejected)
	session.emote_received.connect(_on_emote)
	session.changed.connect(_on_session_changed)
	hud.set_leave_available(false)  # The menu is a button in the top bar (NetTopBar), next to the settings.
	(hud.get_node("%SpeedButton") as Control).hide()  # Everyone plays at x1 here.
	_build_say_popup()
	_catch_up()


func apply_battle_speed() -> void:
	var kept := settings.battle_speed  # The setting stays as the player chose it (it is for solo battles).
	settings.battle_speed = play_speed
	super.apply_battle_speed()
	settings.battle_speed = kept


func cycle_battle_speed() -> void:
	pass  # No speed to choose in a multiplayer fight.


## The spell bar (or the hand) shows my own hero, whoever's turn it is: other players' spells aren't mine to look at.
func _spells_unit_id() -> int:
	var mine := _my_unit()
	return mine if mine >= 0 and mine < battle.state.units.size() else super._spells_unit_id()


## The seconds left on the turn (or on the placement), after the round at the top.
func _process(delta: float) -> void:
	super._process(delta)
	var left := session.placement_seconds_left()
	if left < 0.0:
		left = session.turn_seconds_left()
	hud.set_countdown(ceili(left) if left >= 0.0 else -1)


func _on_session_changed() -> void:
	if session.connection_lost and not _lost_shown:
		_lost_shown = true
		hud.show_banner(tr("Nobody else is connected: the others left, or your own connection broke."))
	elif not session.connection_lost:
		_lost_shown = false


func _create_battle_state() -> BattleState:
	var made := session.state.make_battle()
	return made.state if made != null else null


## The start zone the local player's hero places in (its side's), highlighted while placing.
func _placement_zone() -> Array[Vector2i]:
	return _zone_of(_my_unit())


func _placement_zone_for_camera(battle_state: BattleState) -> Array[Vector2i]:
	var mine := session.unit_of(session.my_id)
	if mine >= 0 and mine < battle_state.units.size() and battle_state.units[mine].team == UnitState.Team.ENEMY:
		return battle_state.zone_enemy
	return battle_state.zone


func _zone_of(unit_id: int) -> Array[Vector2i]:
	if unit_id < 0 or battle == null:
		return battle.state.zone if battle != null else []
	return battle.state.zone if battle.state.units[unit_id].team == UnitState.Team.PLAYER else battle.state.zone_enemy


func _viewer_team() -> UnitState.Team:
	var mine := _my_unit()
	if mine >= 0 and battle != null and mine < battle.state.units.size():
		return battle.state.units[mine].team
	return UnitState.Team.PLAYER


func _my_unit() -> int:
	return session.unit_of(session.my_id)


# --- The log, one entry at a time -----------------------------------------------------------

## A view that opens late (a returning player, or a late start) replays what already happened, without
## animation, then shows where things stand.
func _catch_up() -> void:
	var log := session.state.log
	var start := -1
	for index in log.size():
		if log[index]["k"] == "start":
			start = index
	_applied = start + 1
	for index in range(start + 1, log.size()):
		_apply_silently(log[index])
		_applied = index + 1
	_sync_labels()
	units_view.sync(battle.state)
	_begin_next()
	if battle.state.started:
		units_view.set_active(battle.state.current_unit().id if not battle.state.is_over() else -1)


func _apply_silently(entry: Dictionary) -> void:
	match entry["k"]:
		"act":
			var action := ActionCodec.decode(entry["a"])
			if action != null:
				battle.perform(action)
		"go":
			battle.start()


func _on_entry(entry: Dictionary) -> void:
	if int(entry["n"]) <= _applied or battle == null:
		return
	_queue.append(entry)
	_pump()


func _pump() -> void:
	if _busy:
		return
	while not _queue.is_empty():
		var entry: Dictionary = _queue.pop_front()
		_applied = int(entry["n"])
		if _play_entry(entry):
			return
	_begin_next()


## Applies one entry to this view's battle. True when events started playing (the next entry waits).
func _play_entry(entry: Dictionary) -> bool:
	match entry["k"]:
		"act":
			if entry.get("by") == session.my_id and entry.get("sys") != true:
				_awaiting = false
			var action := ActionCodec.decode(entry["a"])
			if action == null:
				return false
			var result := battle.perform(action)
			if not result.ok():
				push_error("NetBattle: the host's action doesn't fit this view: %s" % result.error)
				return false
			_busy = true
			_play(result.events)
			return true
		"go":
			_busy = true
			_play(battle.start())
			return true
		"ai", "join", "drop":
			_sync_labels()
			_refresh_hud()
	return false


func _sync_labels() -> void:
	for seat_id in session.state.seat_ids():
		var unit_id := session.unit_of(seat_id)
		if unit_id < 0 or unit_id >= battle.state.units.size():
			continue
		var seat := session.state.seats[seat_id]
		var tag := ""
		if seat.ai:
			tag = " " + tr("(AI)")
		elif not seat.connected:
			tag = " " + tr("(away)")
		battle.state.units[unit_id].label = seat.name + tag


## A quick message from a player: it floats above their hero's head.
func _on_emote(seat_id: int, emote_id: int) -> void:
	var unit_view := units_view.find_view(session.unit_of(seat_id))
	if unit_view != null:
		unit_view.say(Emotes.text(emote_id))


## The menu (leaving the fight): the top bar's hamburger button asks for it.
func open_menu() -> void:
	if input_state != State.ENDED:
		hud.open_leave_panel()


## A button above End turn opens the list of quick messages, in the middle of the screen.
func _build_say_popup() -> void:
	var actions := hud.get_node("Root/Actions") as Control
	_say_button = Button.new()
	_say_button.name = "SayButton"
	_say_button.text = tr("Say something")
	_say_button.icon = SAY_ICON
	_say_button.expand_icon = true
	_say_button.focus_mode = Control.FOCUS_NONE
	_say_button.pressed.connect(_toggle_say_popup)
	actions.add_child(_say_button)
	actions.move_child(_say_button, hud.get_node("%EndTurnButton").get_index())
	_say_popup = Control.new()
	_say_popup.name = "SayPopup"
	_say_popup.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_say_popup.visible = false
	_say_popup.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed:
			_say_popup.hide())  # A click anywhere else closes it.
	var panel := PanelContainer.new()
	panel.name = "SayPanel"
	panel.theme_type_variation = &"Chip"
	_say_popup.add_child(panel)
	var list := VBoxContainer.new()
	panel.add_child(list)
	for index in Emotes.count():
		var emote := Button.new()
		emote.name = "Emote%d" % index
		emote.text = Emotes.text(index)
		emote.focus_mode = Control.FOCUS_NONE
		emote.pressed.connect(func() -> void:
			session.send_emote(index)
			_say_popup.hide())
		list.add_child(emote)
	hud.get_node("Root").add_child(_say_popup)


func _toggle_say_popup() -> void:
	if _say_popup.visible:
		_say_popup.hide()
		return
	_say_popup.show()
	var panel := _say_popup.get_node("SayPanel") as Control
	panel.size = panel.get_combined_minimum_size()
	panel.position = ((_say_popup.size - panel.size) / 2.0).floor()  # In the middle of the screen.


func _on_rejected(reason: String) -> void:
	_awaiting = false
	push_warning("NetBattle: refused: %s" % reason)
	hud.show_banner(tr("That isn't possible right now."))
	if not _busy:
		_begin_next()


# --- Turns ----------------------------------------------------------------------------------

func _begin_next() -> void:
	_busy = false
	_refresh_hud()
	if not _queue.is_empty():
		_pump()
		return
	var battle_state := battle.state
	if not battle_state.started:
		_set_state(State.PLACING)
		return
	units_view.set_active(battle_state.current_unit().id if not battle_state.is_over() else -1)
	if battle_state.is_over():
		_finish()
	elif _awaiting:
		_set_state(State.ANIMATING)  # My action is on its way: nothing to do until it comes back.
	elif session.controls_unit(battle_state.current_unit().id):
		_enter_idle()
	else:
		_set_state(State.ENEMY_TURN)  # Someone else's turn (a player, or the AI): watch.


func _finish() -> void:
	var mine := session.state.seats.get(session.my_id) as MatchState.Seat
	var my_team := UnitState.Team.PLAYER if mine == null or mine.side == 0 else UnitState.Team.ENEMY
	var outcome := battle.state.outcome()
	_finish_battle((outcome == BattleState.Outcome.PLAYER_WON and my_team == UnitState.Team.PLAYER) \
			or (outcome == BattleState.Outcome.ENEMY_WON and my_team == UnitState.Team.ENEMY))


func _set_state(new_state: State) -> void:
	if new_state == State.PLACING:
		_placing_hero = _my_unit()
	super._set_state(new_state)
	if new_state == State.PLACING and _placed_pressed:
		hud.set_player_controls_enabled(false)  # Ready was pressed: nothing more to do but wait.


func _turn_banner_name(unit: UnitState) -> String:
	return unit.label


func _prompt_text() -> String:
	if input_state == State.PLACING:
		if _placed_pressed:
			return tr("Ready. Waiting for the other players...")
		return tr("Click a teal cell to place your hero, then press Ready (%s)") % SettingsApplier.key_text(&"end_turn")
	if input_state == State.ENEMY_TURN and battle.state.started and not battle.state.is_over():
		var seat_id := session.state.seat_of_unit(battle.state.current_unit().id)
		var seat := session.state.seats.get(seat_id) as MatchState.Seat
		if seat != null and not seat.connected and not seat.ai:
			return tr("%s is away: the AI takes over soon") % seat.name
	return super._prompt_text()


# --- What the local player does -------------------------------------------------------------

func _perform(action: BattleActions.Action) -> void:
	_awaiting = true
	session.act(action)
	if _awaiting and not _busy:  # It hasn't come back yet (it never does at once for a guest).
		_set_state(State.ANIMATING)


## Ready: tell the host my hero is placed, then wait for the others.
func _press_ready() -> void:
	if _placed_pressed:
		return
	_placed_pressed = true
	session.set_placed(true)
	_set_state(State.PLACING)


## Placement is my own hero only: a click in my side's zone puts it there.
func _click_placing(cell: Vector2i) -> void:
	if not _placed_pressed and cell in _zone_of(_my_unit()):
		_perform(BattleActions.Place.new(_my_unit(), cell))


func _placing_click_action(cell: Vector2i, _clicked: UnitState) -> int:
	return Tutorial.Action.PLACE if not _placed_pressed and cell in _zone_of(_my_unit()) else -1
