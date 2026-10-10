class_name NetFlow
extends Node
## The multiplayer part of the game as one screen the Game root shows: the front page, joining, the lobby
## and the fight, and the network behind them (MultiplayerHub). It moves between them as the match does:
## a joined player lands in the lobby once caught up, the fight opens when the host starts the match, and
## "Back to the lobby" after it returns to the lobby for another one.

signal exit_requested
signal sound(event: StringName)
signal speed_changed
signal music_requested(track: StringName)
## A screen came or went (the fight in particular): the Game root's top buttons follow.
signal view_changed

const BATTLE_SCENE := preload("res://scenes/net/net_battle.tscn")

var settings := Settings.new()
var hub: MultiplayerHub
## Makes the sockets to the relay server (invalid: real WebSockets); tests give fakes.
var make_socket := Callable()

var _screen: Node
var _battle: NetBattleController
## The player left the results for the lobby while the match's state still says "battle".
var _after_battle := false
## The hero the player likes was put on their seat (once per match joined).
var _hero_preselected := false


## `fragment`: the page address's # part. A room link in it joins at once.
func start(fragment := "") -> void:
	WebPage.keep_running_when_hidden()
	hub = MultiplayerHub.new()
	hub.name = "Hub"
	if make_socket.is_valid():
		hub.make_socket = make_socket
	add_child(hub)
	hub.session_started.connect(_wire_session)
	hub.failed.connect(_on_failed)
	hub.warm_up()  # A sleeping server takes a minute to wake: start now, so it is ready when Host or Join is pressed.
	var code := _join_code_in(fragment)
	_show_menu()
	if not code.is_empty():
		(_screen as NetMenuScreen).prefill_code(code)
		_on_join(NetUi.saved_name(), code)


## The room code in the page address's # part, or "".
static func _join_code_in(fragment: String) -> String:
	if fragment.begins_with(RoomCode.LINK_KEY + "="):
		return RoomCode.normalize(fragment)
	return ""


## How long a joiner waits for the host to take them in once the server has let them into the room.
const HOST_TIMEOUT := 20.0

var _waiting_for_host := 0.0


func _process(delta: float) -> void:
	if not (_screen is NetJoinScreen) or hub == null:
		_waiting_for_host = 0.0
		return
	var join := _screen as NetJoinScreen
	if hub.session == null:
		join.show_status(hub.status())
	elif not hub.session.is_synced:
		_waiting_for_host += delta
		join.show_status(tr("In the room. Waiting for the host to take you in..."))
		if _waiting_for_host > HOST_TIMEOUT:
			_waiting_for_host = 0.0
			_on_failed(tr("The host did not answer."))


# --- Screens --------------------------------------------------------------------------------

func _swap(next: Node) -> void:
	if _screen != null:
		remove_child(_screen)
		_screen.queue_free()
	_screen = next
	add_child(next)
	view_changed.emit()
	if next is Screen:
		(next as Screen).focus_first.call_deferred()


func _show_menu(message := "") -> void:
	_battle = null
	music_requested.emit(&"hub")
	var menu := NetMenuScreen.new()
	_swap(menu)
	menu.back_pressed.connect(exit_requested.emit)
	menu.host_requested.connect(_on_host)
	menu.join_requested.connect(_on_join)
	if not message.is_empty():
		menu.show_message(message)


func _on_host(player_name: String) -> void:
	hub.host_room(player_name)  # The server makes the room: session_started comes, and the lobby with it.
	var opening := NetJoinScreen.new()
	_swap(opening)
	opening.show_opening()
	opening.cancelled.connect(_leave)


func _on_join(player_name: String, text: String) -> void:
	var error := hub.join(player_name, text)
	if not error.is_empty():
		if _screen is NetMenuScreen:
			(_screen as NetMenuScreen).show_message(error)
		return
	var join := NetJoinScreen.new()
	_swap(join)
	join.cancelled.connect(_leave)
	join.show_status(hub.status())


func _wire_session() -> void:
	hub.session.synced.connect(_on_synced)
	hub.session.changed.connect(_on_changed)
	if hub.session.is_synced:
		_on_synced()  # A host is in its own match from the start.


func _show_lobby() -> void:
	_preselect_hero()
	_battle = null
	music_requested.emit(&"hub")
	var lobby := NetLobbyScreen.new()
	_swap(lobby)
	lobby.bind(hub.session)
	if not hub.room_code.is_empty():
		lobby.show_room(hub.room_code, RoomCode.link_for(WebPage.url(), hub.room_code))
	lobby.leave_requested.connect(_leave)


## The lobby opens with the hero this player likes (chosen on the front page or last time).
func _preselect_hero() -> void:
	if _hero_preselected or hub.session == null:
		return
	var seat := hub.session.state.seats.get(hub.session.my_id) as MatchState.Seat
	if seat == null:
		return  # Not synced yet: the lobby is shown again when it is.
	_hero_preselected = true
	var wanted := NetUi.saved_hero()
	if seat.hero != wanted and hub.session.state.phase == MatchState.Phase.LOBBY:
		hub.session.set_field("hero", wanted)


func _show_battle() -> void:
	_after_battle = false
	music_requested.emit(&"battle")
	var battle := BATTLE_SCENE.instantiate() as NetBattleController
	battle.setup_net(hub.session)
	battle.settings = settings
	battle.sound.connect(sound.emit)
	battle.speed_changed.connect(speed_changed.emit)
	battle.left_battle.connect(_leave)
	battle.battle_finished.connect(_on_battle_finished)
	battle.menu_changed.connect(view_changed.emit)
	_swap(battle)
	_battle = battle


func _leave() -> void:
	hub.leave()
	_after_battle = false
	_hero_preselected = false
	_show_menu()


## Whether the lobby is on screen (the Game root's settings button is offered, as in the fight).
func in_lobby() -> bool:
	return _screen is NetLobbyScreen


## Whether the fight is on screen.
func in_battle() -> bool:
	return _screen is NetBattleController


## Whether the Game root's menu button is offered: in the fight, until its result shows.
func menu_available() -> bool:
	return _screen is NetBattleController and (_screen as NetBattleController).menu_available()


## The menu button (leaving the fight).
func open_menu() -> void:
	if _battle != null:
		_battle.open_menu()


# --- Events ---------------------------------------------------------------------------------

func _on_synced() -> void:
	if hub.session.state.phase == MatchState.Phase.BATTLE:
		_show_battle()
	else:
		_show_lobby()


func _on_changed() -> void:
	if hub.session == null or not hub.session.is_synced:
		return
	var phase := hub.session.state.phase
	if phase == MatchState.Phase.LOBBY:
		_after_battle = false
		if _battle != null and not _battle_is_showing_results():
			_show_lobby()  # The host sent everyone back to the lobby mid-fight (nothing to look at).
	elif _battle == null and not _after_battle and _screen is NetLobbyScreen:
		_show_battle()


func _battle_is_showing_results() -> bool:
	return _battle != null and _battle.input_state == BattleController.State.ENDED


func _on_battle_finished(_state: BattleState) -> void:
	_after_battle = true
	if hub.session.is_host():
		hub.session.back_to_lobby()
	_show_lobby()


func _on_failed(reason: String) -> void:
	hub.leave()
	_show_menu(reason)
