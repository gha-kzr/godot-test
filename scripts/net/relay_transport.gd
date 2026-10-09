class_name RelayTransport
extends NetTransport
## Every player is connected to the relay server (server/relay.mjs) by one WebSocket, and the server passes messages
## between the players of a room: the network is a star, and every player can reach every other one.
##
## Opening: `open_host` makes a room, `open_join` enters one by its code; `welcomed` fires with the player's seat id
## once the server has let them in (until then the transport can't send anything). The server may sleep (a free
## service stops after a quiet quarter of an hour and takes about a minute to wake), so the first connection tries
## again for a good while before it gives up (`connect_failed`).
##
## A connection that drops in the middle of a match is reopened by itself with the same token, which gives the
## same seat back (the others see the player go and return). Meanwhile `is_online()` is false and nothing is said
## about the other players (who is still there is only known once the server answers again). If that doesn't work for
## a minute, `connect_failed`.
##
## On the wire, JSON text: {t:"host", token} {t:"join", room, token, resume?} {t:"msg", to?, b}, and from the
## server {t:"welcome", room, id, peers} {t:"peer", id} {t:"left", id} {t:"msg", from, b} {t:"error", why}.

## The first welcome: this player's seat id, the room's code and the seat ids already in it.
signal welcomed(id: int, room: String, peers: Array)
## The server said no to the host / join request (its reason: no_room, room_full, token_in_use, ...).
signal refused(why: String)
## The server can't be reached (for good: the transport has stopped trying).
signal connect_failed(reason: String)

enum State { IDLE, CONNECTING, WAITING, READY, RECONNECTING, CLOSED, FAILED }

## How long the first connection keeps trying (a sleeping server takes about a minute to wake).
const CONNECT_DEADLINE := 120.0
## How long a dropped connection keeps trying to come back.
const RECONNECT_WINDOW := 60.0
const FIRST_PAUSE := 1.0
const MAX_PAUSE := 5.0
## A connection that opened but gets no answer to its request in this time is given up (and tried again).
const WELCOME_TIMEOUT := 15.0

var url := ""
var room := ""
var state := State.IDLE
## Seconds since the first connection attempt (for "waking the server" messages).
var waited := 0.0

var _make_socket: Callable
var _socket: RelaySocket
var _id := 0
var _reachable: Array[int] = []
var _request := {}
var _pause := FIRST_PAUSE
var _retry_in := 0.0
var _attempt_age := 0.0
var _window_age := 0.0


## `make_socket`: a Callable returning a fresh RelaySocket (the real one, or a fake).
func _init(address: String, make_socket: Callable) -> void:
	url = address
	_make_socket = make_socket


## What the server is given instead of the player's secret token: it sees only this, never the token the match
## log's own hash is made from (every player in the match has that one, so it can't prove who someone is).
static func relay_token(secret: String) -> String:
	return ("rune-ascent-multiplayer/relay/" + secret).sha256_text()


func open_host(token: String) -> void:
	_request = {"t": "host", "token": relay_token(token)}
	_start()


func open_join(room_code: String, token: String) -> void:
	room = room_code
	_request = {"t": "join", "room": room_code, "token": relay_token(token)}
	_start()


## After a `token_in_use` refusal: asks again with another token (the connection stays open).
func retry_join(token: String) -> void:
	_request["token"] = relay_token(token)
	_send_raw(_request)


func local_id() -> int:
	return _id


## False while the connection is down (the last known peers stay in `reachable_ids`: it is not known yet who is still there).
func is_online() -> bool:
	return state == State.READY


func reachable_ids() -> Array[int]:
	return _reachable.duplicate()


func send(to_id: int, message: Dictionary) -> void:
	if state == State.READY and to_id in _reachable:
		_send_raw({"t": "msg", "to": to_id, "b": message})


## One message for the server to hand to everyone else in the room.
func broadcast(message: Dictionary) -> void:
	if state == State.READY and not _reachable.is_empty():
		_send_raw({"t": "msg", "b": message})


func close() -> void:
	if state == State.CLOSED:
		return
	state = State.CLOSED
	if _socket != null:
		_socket.close()
		_socket = null
	_forget_everyone()


## Called every frame.
func poll(delta: float) -> void:
	if state == State.IDLE or state == State.CLOSED or state == State.FAILED:
		return
	waited += delta
	_attempt_age += delta
	if _socket != null:
		_socket.poll()
		if state == State.CLOSED or state == State.FAILED:
			return
	if _socket == null:
		if state == State.RECONNECTING:
			_window_age += delta
			if _window_age > RECONNECT_WINDOW:
				_fail(TranslationServer.translate("The connection to the game server was lost."))
				return
		elif waited > CONNECT_DEADLINE:
			_fail(TranslationServer.translate("Could not reach the game server."))
			return
		_retry_in -= delta
		if _retry_in <= 0.0:
			_connect()
	elif state != State.READY and _attempt_age > WELCOME_TIMEOUT:
		_drop_socket()  # Never opened, or opened but never answered (a server still waking up): try again.


# --- Connecting -----------------------------------------------------------------------------

func _start() -> void:
	state = State.CONNECTING
	waited = 0.0
	_pause = FIRST_PAUSE
	_connect()


func _connect() -> void:
	_attempt_age = 0.0
	_socket = _make_socket.call()
	var socket := _socket
	socket.opened.connect(func() -> void: if socket == _socket: _on_opened())
	socket.closed.connect(func() -> void: if socket == _socket: _on_closed(socket))
	socket.text_received.connect(func(text: String) -> void: if socket == _socket: _on_text(text))
	socket.connect_to(url)


func _drop_socket() -> void:
	var socket := _socket
	_socket = null
	if socket != null:
		socket.close()
	_schedule_retry()


func _schedule_retry() -> void:
	_retry_in = _pause
	_pause = minf(_pause * 2.0, MAX_PAUSE)


func _on_opened() -> void:
	_attempt_age = 0.0
	if state == State.RECONNECTING:
		_send_raw({"t": "join", "room": room, "token": _request["token"], "resume": true})
	else:
		state = State.WAITING
		_send_raw(_request)


func _on_closed(socket: RelaySocket) -> void:
	_socket = null
	if state == State.CLOSED or state == State.FAILED:
		return
	if socket.close_code == RelaySocket.CLOSE_REPLACED:
		_fail(TranslationServer.translate("This player joined from another window or tab."))
		return
	if state == State.READY:
		state = State.RECONNECTING
		_window_age = 0.0
		_pause = FIRST_PAUSE
	_schedule_retry()


func _fail(reason: String) -> void:
	state = State.FAILED
	if _socket != null:
		_socket.close()
		_socket = null
	_forget_everyone()
	connect_failed.emit(reason)


func _forget_everyone() -> void:
	var gone := _reachable.duplicate()
	_reachable.clear()
	for id: int in gone:
		peer_disconnected.emit(id)


# --- Messages -------------------------------------------------------------------------------

func _send_raw(message: Dictionary) -> void:
	if _socket != null and _socket.is_open:
		_socket.send_text(NetJson.stringify(message))


func _on_text(text: String) -> void:
	var message: Variant = NetJson.parse(text)
	if message is not Dictionary:
		return
	match message.get("t"):
		"msg":
			var from: Variant = message.get("from")
			var body: Variant = message.get("b")
			if state == State.READY and from is int and from in _reachable and body is Dictionary:
				message_received.emit(from, body)
		"peer":
			var id: Variant = message.get("id")
			if state == State.READY and id is int and id != _id and id not in _reachable:
				_reachable.append(id)
				_reachable.sort()
				peer_connected.emit(id)
		"left":
			var id: Variant = message.get("id")
			if id is int and id in _reachable:
				_reachable.erase(id)
				peer_disconnected.emit(id)
		"welcome":
			_on_welcome(message)
		"error":
			var why := str(message.get("why", "error"))
			if state == State.RECONNECTING:
				_fail(TranslationServer.translate("The connection to the game server was lost."))
			elif state == State.WAITING:
				refused.emit(why)


func _on_welcome(message: Dictionary) -> void:
	var id: Variant = message.get("id")
	var code: Variant = message.get("room")
	var peers: Variant = message.get("peers")
	if id is not int or code is not String or peers is not Array:
		return
	var others: Array[int] = []
	for peer: Variant in peers:
		if peer is int and peer != id:
			others.append(peer)
	others.sort()
	if state == State.RECONNECTING:
		if id != _id:
			_fail(TranslationServer.translate("The connection to the game server was lost."))
			return
		state = State.READY
		var before := _reachable
		_reachable = others
		for peer in before:
			if peer not in others:
				peer_disconnected.emit(peer)  # Left while this player was cut off.
		for peer in others:
			peer_connected.emit(peer)  # Everyone present is heard from again (even those who never left).
		return
	if state != State.WAITING:
		return
	_id = id
	room = code
	_request = {"t": "join", "room": code, "token": _request["token"]}  # What a reconnection sends (with `resume`).
	state = State.READY
	_pause = FIRST_PAUSE
	_reachable = others
	welcomed.emit(id, code, others)
