class_name E2eHook
extends Node
## Dev-only: lets a script drive the game from the browser's JavaScript, for end-to-end tests of the real
## network in several tabs (`?e2e=1` in the page address turns it on; `&relay=ws://127.0.0.1:8787` points the game at a
## relay server on this machine). JS calls `window.e2e_cmd(JSON.stringify({id, name, args}))`; the answer appears in
## `window.e2e_out[id]`, and a refusal in `window.e2e_out.failed`.

var game: Game
var _callback: JavaScriptObject
var _wired: MultiplayerHub


func _ready() -> void:
	if not WebPage.is_web():
		return
	var window := JavaScriptBridge.get_interface("window")
	_callback = JavaScriptBridge.create_callback(_on_command)
	window.e2e_cmd = _callback
	JavaScriptBridge.eval("window.e2e_out = {}; window.e2e_ready = true;", true)


## JSON numbers arrive as floats; the match wants whole numbers as ints (the screens send ints).
static func _whole(value: Variant) -> Variant:
	return int(value) if value is float and is_equal_approx(value, roundf(value)) else value


func _flow() -> NetFlow:
	return game.screen as NetFlow


func _hub() -> MultiplayerHub:
	return _flow().hub if _flow() != null else null


func _on_command(args: Array) -> void:
	var request: Variant = JSON.parse_string(str(args[0]))
	if request is not Dictionary:
		return
	var result: Variant = _run(str(request.get("name")), request.get("args", []))
	JavaScriptBridge.eval("window.e2e_out[%d] = %s;" % [int(request.get("id", 0)), JSON.stringify(result)], true)


func _run(command: String, args: Array) -> Variant:
	match command:
		"open":
			game.show_multiplayer()  # A room link in the page's address joins from here.
			_listen()
			return true
		"host":
			_flow()._on_host(str(args[0]))
			_listen()
			return true
		"join":
			var flow := _flow()
			flow._on_join(str(args[0]), str(args[1]))
			_listen()
			return _hub().transport != null
		"status":
			return _status()
		"set":
			_hub().session.set_field(str(args[0]), _whole(args[1]))
		"cfg":
			_hub().session.configure(str(args[0]), _whole(args[1]))
		"ready":
			_hub().session.set_ready(bool(args[0]))
		"start":
			_hub().session.start_match()
		"placed":
			_hub().session.set_placed(true)
		"end_turn":
			var session := _hub().session
			if session.is_my_turn():
				session.act(BattleActions.EndTurn.new(session.unit_of(session.my_id)))
				return true
			return false
		"ai":
			_hub().session.hand_to_ai(bool(args[0]))
		"lobby":
			_hub().session.back_to_lobby()
		"leave":
			_flow()._leave()
		"center":
			# Where a control of the current screen is on the page (to click it with a real mouse event).
			var found := _flow()._screen.find_child(str(args[0]), true, false) as Control
			if found == null or not found.is_visible_in_tree():
				return null
			# From the game's own units to the page's pixels (the canvas is scaled to the window).
			var to_page := found.get_viewport().get_screen_transform() * found.get_global_transform_with_canvas()
			var origin := to_page * Vector2.ZERO
			var size := to_page.basis_xform(found.size)
			return [origin.x, origin.y, size.x, size.y]
		"ghost":
			# For a screenshot: puts the stealth status on my hero in this screen's own copy of the battle (nothing is sent).
			var fight := _flow()._battle as NetBattleController
			var mine := fight.battle.state.units[_hub().session.unit_of(_hub().session.my_id)]
			mine.add_status(load("res://data/pvp/statuses/stealth.tres") as StatusData, 0)
			fight.units_view.refresh_visibility(fight.battle.state)
		"emote":
			_hub().session.send_emote(int(args[0]))
		"settings":
			_flow()._open_settings()
		"blink":
			_hub().transport._socket.close()  # The connection to the server breaks (the transport reconnects).
	return true


## Hands a refusal to JS.
func _listen() -> void:
	var hub := _hub()
	if hub == null or hub == _wired:
		return
	_wired = hub
	hub.failed.connect(func(reason: String) -> void:
		JavaScriptBridge.eval("window.e2e_out.failed = %s;" % JSON.stringify(reason), true))


func _status() -> Dictionary:
	var hub := _hub()
	if hub == null or hub.session == null:
		return {"in_match": false, "room": hub.room_code if hub != null else "", "connection": hub.status() if hub != null else "",
				"screen": game.screen.get_class() if game.screen != null else ""}
	var session := hub.session
	var seats := []
	for id in session.state.seat_ids():
		var seat := session.state.seats[id]
		seats.append({"id": id, "name": seat.name, "connected": seat.connected, "ai": seat.ai, "side": seat.side, "hero": seat.hero, "ready": seat.ready})
	return {"in_match": true, "room": hub.room_code, "connection": hub.status(), "my_id": session.my_id, "host_id": session.host_id, "synced": session.is_synced, "halted": session.halt_reason,
			"phase": session.state.phase, "entries": session.state.entry_count(), "settings": session.state.settings, "fingerprint": session.state.fingerprint(),
			"peers": session.peers(), "seats": seats, "my_turn": session.is_my_turn(),
			"started": session.state.battle != null and session.state.battle.state.started,
			"over": session.state.is_over(), "screen": game.screen.get_class() if game.screen != null else "",
			"current_seat": session.state.current_seat()}
