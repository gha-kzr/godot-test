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

const BATTLE_SCENE := preload("res://scenes/net/net_battle.tscn")

var settings := Settings.new()
var hub: MultiplayerHub
## Links to use (null: WebRTC); tests give fakes.
var link_factory: LinkFactory

var _screen: Node
var _battle: NetBattleController
## The player left the results for the lobby while the match's state still says "battle".
var _after_battle := false
## The hero the player likes was put on their seat (once per match joined).
var _hero_preselected := false


## `fragment`: the page address's # part. An invite link in it joins at once.
func start(fragment := "") -> void:
	WebPage.keep_running_when_hidden()
	hub = MultiplayerHub.new()
	hub.name = "Hub"
	if link_factory != null:
		hub.factory = link_factory
	add_child(hub)
	hub.session_started.connect(_wire_session)
	hub.invite_ready.connect(_on_invite_ready)
	hub.reply_ready.connect(_on_reply_ready)
	hub.failed.connect(_on_failed)
	var code := _join_code_in(fragment)
	_show_menu()
	if not code.is_empty():
		(_screen as NetMenuScreen).prefill_code(code)
		_on_join(NetUi.saved_name(), code)


## The invite or room code in the page address's # part, or "".
static func _join_code_in(fragment: String) -> String:
	if fragment.begins_with(InviteCodec.JOIN_KEY + "="):
		return InviteCodec.extract_code(fragment)
	if fragment.begins_with(RoomCode.LINK_KEY + "="):
		return RoomCode.normalize(fragment)
	return ""


## How long a joiner waits for the connection to the host to open once the host has answered.
const CONNECT_TIMEOUT := 45.0

var _connecting_for := 0.0


func _process(delta: float) -> void:
	if not (_screen is NetJoinScreen) or hub == null:
		_connecting_for = 0.0
		return
	var join := _screen as NetJoinScreen
	if hub.session == null:
		if hub.signaling != null:
			join.show_search(hub.status(), hub.join_details())
	elif not hub.session.is_synced and hub.joined_by_room():
		_connecting_for += delta
		join.show_connecting(hub.join_details())
		if _connecting_for > CONNECT_TIMEOUT:
			_connecting_for = 0.0
			var why := TranslationServer.translate("Could not open a connection to the host. Some networks (company, school, some phone connections) block direct connections between players.")
			if WebPage.is_brave():
				why += " " + TranslationServer.translate("Brave limits WebRTC: in Brave's settings (Privacy and security), set \"WebRTC IP handling policy\" to \"Default public and private interface\", or try Chrome or Firefox.")
			_on_failed(why)


# --- Screens --------------------------------------------------------------------------------

func _swap(next: Node) -> void:
	if _screen != null:
		remove_child(_screen)
		_screen.queue_free()
	_screen = next
	add_child(next)
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
	hub.host_room(player_name)  # Its session_started wires the session.
	_show_lobby()


func _on_join(player_name: String, text: String) -> void:
	var error := hub.join(player_name, text)
	if not error.is_empty():
		if _screen is NetMenuScreen:
			(_screen as NetMenuScreen).show_message(error)
		return
	var join := NetJoinScreen.new()
	_swap(join)
	join.cancelled.connect(_leave)
	if hub.session == null:
		join.show_search(hub.status())  # By room code: the trackers answer later.


func _wire_session() -> void:
	hub.session.synced.connect(_on_synced)
	hub.session.changed.connect(_on_changed)


func _show_lobby() -> void:
	_preselect_hero()
	_battle = null
	music_requested.emit(&"hub")
	var lobby := NetLobbyScreen.new()
	_swap(lobby)
	lobby.bind(hub.session)
	if not hub.room_code.is_empty():
		lobby.show_room(hub.room_code, RoomCode.link_for(WebPage.url(), hub.room_code))
	lobby.invite_requested.connect(hub.create_invite)
	lobby.reply_pasted.connect(_on_reply_pasted)
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
	_swap(battle)
	_battle = battle


func _leave() -> void:
	hub.leave()
	_after_battle = false
	_hero_preselected = false
	_show_menu()


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


func _on_invite_ready(code: String, link: String, _seat: int) -> void:
	if _screen is NetLobbyScreen:
		(_screen as NetLobbyScreen).show_invite(code, link)


func _on_reply_ready(code: String, link: String) -> void:
	if _screen is NetJoinScreen:
		(_screen as NetJoinScreen).show_reply(code, link)


func _on_reply_pasted(text: String) -> void:
	var error := hub.accept_reply(text)
	if _screen is NetLobbyScreen:
		(_screen as NetLobbyScreen).show_invite_message(error if not error.is_empty() else tr("Connecting... the player appears in the list when it works."))


func _on_failed(reason: String) -> void:
	hub.leave()
	_show_menu(reason)
