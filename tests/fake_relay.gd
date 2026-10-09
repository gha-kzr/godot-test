class_name FakeRelay
extends RefCounted
## The relay server (server/relay.mjs) in memory, with the same rules: a room per code, member numbers tied to a
## token, messages stamped with their sender, `peer` / `left` events. Sockets deliver when `flush()` runs, so a test
## decides when the network moves. A test can also put the server to sleep (connections fail until `wake()`), drop
## a player's connection, or close it with a code.

const MAX_MEMBERS := 12

var asleep := false
## Rooms by code: {members: {id: Socket}, tokens: {token: id}, next_id: int}.
var rooms: Dictionary = {}
var connections_made := 0
var _sockets: Array = []
var _queue: Array = []
var _codes_made := 0


class Socket extends RelaySocket:
	var server: FakeRelay
	var room := ""
	var id := 0
	var _done := false

	func connect_to(address: String) -> void:
		url = address
		server._queue.append([self, "open"])

	func send_text(text: String) -> void:
		if is_open:
			server._queue.append([self, "in", text])

	func close() -> void:
		if not _done:
			_done = true
			var was_open := is_open
			is_open = false
			if was_open:
				server._leave(self)
			closed.emit()


func make_socket() -> RelaySocket:
	var socket := Socket.new()
	socket.server = self
	_sockets.append(socket)
	connections_made += 1
	return socket


func wake() -> void:
	asleep = false


## The server goes to sleep: every connection closes, and new ones fail until `wake()`.
func sleep() -> void:
	asleep = true
	for socket: Socket in _sockets.duplicate():
		if socket.is_open:
			_cut(socket, -1)


## The connection of the player that holds `seat_id` in `room_code` breaks (the network under it went away).
func drop(room_code: String, seat_id: int, code := -1) -> void:
	var socket: Socket = rooms[room_code]["members"].get(seat_id)
	if socket != null:
		_cut(socket, code)


func members(room_code: String) -> Array:
	var ids: Array = rooms[room_code]["members"].keys() if rooms.has(room_code) else []
	ids.sort()
	return ids


## Delivers what is queued, until nothing is left (a message sent while delivering is delivered too).
func flush() -> void:
	for round_index in 100:
		if _queue.is_empty():
			return
		var batch := _queue
		_queue = []
		for item: Array in batch:
			_deliver(item)


func _deliver(item: Array) -> void:
	var socket: Socket = item[0]
	match item[1]:
		"open":
			if socket._done:
				return
			if asleep:
				socket._done = true
				socket.closed.emit()
			else:
				socket.is_open = true
				socket.opened.emit()
		"in":
			if socket.is_open:
				_handle(socket, NetJson.parse(item[2]))
		"out":
			if socket.is_open:
				socket.text_received.emit(item[2])


func _cut(socket: Socket, code: int) -> void:
	if socket._done:
		return
	socket._done = true
	socket.is_open = false
	socket.close_code = code
	_leave(socket)
	socket.closed.emit()


func _to(socket: Socket, message: Dictionary) -> void:
	_queue.append([socket, "out", NetJson.stringify(message)])


func _handle(socket: Socket, message: Variant) -> void:
	if message is not Dictionary:
		return
	match message.get("t"):
		"host":
			if socket.room.is_empty():
				_codes_made += 1
				var code := _code(_codes_made)
				rooms[code] = {"members": {}, "tokens": {message["token"]: 1}, "next_id": 2}
				_enter(socket, code, 1)
		"join":
			if socket.room.is_empty():
				_join(socket, message)
		"msg":
			_relay(socket, message)


func _join(socket: Socket, message: Dictionary) -> void:
	var code := RoomCode.normalize(str(message.get("room", "")))
	if code.is_empty():
		_to(socket, {"t": "error", "why": "bad_request"})
		return
	if not rooms.has(code):
		_to(socket, {"t": "error", "why": "no_room"})
		return
	var room: Dictionary = rooms[code]
	var token: String = message["token"]
	var id: Variant = room["tokens"].get(token)
	if id != null:
		var holder: Socket = room["members"].get(id)
		if holder != null:
			if message.get("resume") != true:
				_to(socket, {"t": "error", "why": "token_in_use"})
				return
			room["members"].erase(id)
			holder.room = ""
			_cut_quietly(holder, 4000)
			for other: Socket in room["members"].values():
				_to(other, {"t": "left", "id": id})
	else:
		if room["members"].size() >= MAX_MEMBERS:
			_to(socket, {"t": "error", "why": "room_full"})
			return
		id = room["next_id"]
		room["next_id"] += 1
		room["tokens"][token] = id
	_enter(socket, code, id)


func _cut_quietly(socket: Socket, code: int) -> void:
	socket._done = true
	socket.is_open = false
	socket.close_code = code
	socket.closed.emit()


func _enter(socket: Socket, code: String, id: int) -> void:
	var room: Dictionary = rooms[code]
	var peers: Array = room["members"].keys()
	peers.sort()
	for other: Socket in room["members"].values():
		_to(other, {"t": "peer", "id": id})
	room["members"][id] = socket
	socket.room = code
	socket.id = id
	_to(socket, {"t": "welcome", "room": code, "id": id, "peers": peers})


func _leave(socket: Socket) -> void:
	if socket.room.is_empty() or not rooms.has(socket.room):
		return
	var room: Dictionary = rooms[socket.room]
	if room["members"].get(socket.id) != socket:
		return
	room["members"].erase(socket.id)
	var code := socket.room
	socket.room = ""
	for other: Socket in room["members"].values():
		_to(other, {"t": "left", "id": socket.id})
	if room["members"].is_empty():
		rooms.erase(code)


func _relay(socket: Socket, message: Dictionary) -> void:
	if socket.room.is_empty() or message.get("b") is not Dictionary:
		return
	var room: Dictionary = rooms[socket.room]
	var packet := {"t": "msg", "from": socket.id, "b": message["b"]}
	if message.has("to"):
		var target: Socket = room["members"].get(message["to"])
		if target != null and target != socket:
			_to(target, packet)
	else:
		for id: int in room["members"]:
			if id != socket.id:
				_to(room["members"][id], packet)


static func _code(number: int) -> String:
	var text := ""
	var value := number * 7919 + 13
	for i in RoomCode.LENGTH:
		text += RoomCode.ALPHABET[value % RoomCode.ALPHABET.length()]
		value = value / RoomCode.ALPHABET.length() + number + i
	return text
