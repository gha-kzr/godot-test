extends TestCase
## The transport to the relay server (with the relay in memory): opening and joining a room, messages between
## players, a sleeping server, a connection that drops and comes back, and the ways it gives up.

var _relay := FakeRelay.new()


func _transport() -> RelayTransport:
	return RelayTransport.new("ws://fake", _relay.make_socket)


## `seconds` of time for every transport, delivering what the relay holds between small steps.
func _run(transports: Array, seconds: float, step := 0.25) -> void:
	var elapsed := 0.0
	_relay.flush()
	while elapsed < seconds - 0.00001:
		for transport: RelayTransport in transports:
			transport.poll(step)
		_relay.flush()
		elapsed += step


## A host and a guest, both in the room.
func _pair() -> Array:
	var host := _transport()
	host.open_host("host-token-1")
	_run([host], 1.0)
	var guest := _transport()
	guest.open_join(host.room, "guest-token-1")
	_run([host, guest], 1.0)
	return [host, guest]


func test_a_host_opens_a_room_and_a_guest_joins_it_with_the_code() -> void:
	var host := _transport()
	var welcomes := []
	host.welcomed.connect(func(id: int, room: String, peers: Array) -> void: welcomes.append([id, room.length(), peers]))
	host.open_host("host-token-1")
	_run([host], 1.0)
	assert_eq(welcomes, [[1, 6, []]], "seat 1 in a room with a code of six characters")
	assert_eq(host.state, RelayTransport.State.READY)
	var connected := []
	host.peer_connected.connect(func(id: int) -> void: connected.append(id))
	var guest := _transport()
	var guest_welcome := []
	guest.welcomed.connect(func(id: int, _room: String, peers: Array) -> void: guest_welcome.append([id, peers]))
	guest.open_join(host.room, "guest-token-1")
	_run([host, guest], 1.0)
	assert_eq(guest_welcome, [[2, [1]]], "the guest is 2 and finds the host there")
	assert_eq(connected, [2])
	assert_eq(host.reachable_ids(), [2] as Array[int])
	assert_eq(guest.reachable_ids(), [1] as Array[int])
	assert_eq(guest.local_id(), 2)


func test_messages_go_to_one_player_or_to_all_with_the_senders_number() -> void:
	var pair := _pair()
	var host: RelayTransport = pair[0]
	var guest: RelayTransport = pair[1]
	var third := _transport()
	third.open_join(host.room, "third-token-1")
	_run([host, guest, third], 1.0)
	var heard := {1: [], 2: [], 3: []}
	host.message_received.connect(func(from: int, message: Dictionary) -> void: heard[1].append([from, message]))
	guest.message_received.connect(func(from: int, message: Dictionary) -> void: heard[2].append([from, message]))
	third.message_received.connect(func(from: int, message: Dictionary) -> void: heard[3].append([from, message]))
	guest.send(3, {"m": "private", "n": 7})
	guest.broadcast({"m": "all"})
	host.send(99, {"m": "nobody"})
	_run([host, guest, third], 1.0)
	assert_eq(heard[3], [[2, {"m": "private", "n": 7}], [2, {"m": "all"}]], "numbers come back as numbers")
	assert_eq(heard[1], [[2, {"m": "all"}]])
	assert_eq(heard[2], [])


func test_a_player_who_leaves_is_gone_for_the_others() -> void:
	var pair := _pair()
	var host: RelayTransport = pair[0]
	var guest: RelayTransport = pair[1]
	var gone := []
	host.peer_disconnected.connect(func(id: int) -> void: gone.append(id))
	guest.close()
	_run([host], 0.5)
	assert_eq(gone, [2])
	assert_eq(host.reachable_ids(), [] as Array[int])
	assert_eq(_relay.members(host.room), [1])


func test_a_wrong_code_is_refused_and_the_connection_waits_for_what_comes_next() -> void:
	var guest := _transport()
	var told := []
	guest.refused.connect(func(why: String) -> void: told.append(why))
	guest.open_join("zzzzzz", "guest-token-1")
	_run([guest], 1.0)
	assert_eq(told, ["no_room"])


func test_the_server_never_sees_the_token_the_match_log_keeps() -> void:
	assert_ne(RelayTransport.relay_token("secret-token-1"), MatchState.token_hash("secret-token-1"), "everyone in the match has the second one")
	assert_eq(RelayTransport.relay_token("secret-token-1"), RelayTransport.relay_token("secret-token-1"))


func test_a_sleeping_server_is_tried_again_until_it_wakes() -> void:
	_relay.asleep = true
	var host := _transport()
	host.open_host("host-token-1")
	_run([host], 12.0)
	assert_eq(host.state, RelayTransport.State.CONNECTING, "still trying")
	assert_true(_relay.connections_made >= 3, "with a growing pause between tries")
	assert_true(_relay.connections_made < 12, "but not at every frame")
	_relay.wake()
	_run([host], 8.0)
	assert_eq(host.state, RelayTransport.State.READY)
	assert_eq(host.local_id(), 1)


func test_a_server_that_never_wakes_ends_with_an_error() -> void:
	_relay.asleep = true
	var host := _transport()
	var errors := []
	host.connect_failed.connect(func(reason: String) -> void: errors.append(reason))
	host.open_host("host-token-1")
	_run([host], RelayTransport.CONNECT_DEADLINE + 10.0, 1.0)
	assert_eq(host.state, RelayTransport.State.FAILED)
	assert_eq(errors.size(), 1)
	assert_ne(errors[0], "")


func test_a_connection_that_drops_comes_back_to_the_same_seat() -> void:
	var pair := _pair()
	var host: RelayTransport = pair[0]
	var guest: RelayTransport = pair[1]
	var room: String = host.room
	var host_saw := []
	var guest_saw := []
	host.peer_disconnected.connect(func(id: int) -> void: host_saw.append("lost %d" % id))
	host.peer_connected.connect(func(id: int) -> void: host_saw.append("back %d" % id))
	guest.peer_disconnected.connect(func(id: int) -> void: guest_saw.append("lost %d" % id))
	guest.peer_connected.connect(func(id: int) -> void: guest_saw.append("back %d" % id))
	_relay.drop(room, 2)
	_run([host, guest], 0.25)
	assert_eq(guest.state, RelayTransport.State.RECONNECTING)
	assert_false(guest.is_online(), "the guest knows its own connection is down")
	assert_eq(guest_saw, [], "and says nothing about the others: it can't know who is still there")
	assert_eq(host_saw, ["lost 2"])
	_run([host, guest], 3.0)
	assert_eq(guest.state, RelayTransport.State.READY)
	assert_eq(guest.local_id(), 2, "the same seat: the token says who it is")
	assert_eq(host_saw, ["lost 2", "back 2"])
	assert_true(guest.is_online())
	assert_eq(guest_saw, ["back 1"], "everyone present is heard from again")
	var heard := []
	host.message_received.connect(func(from: int, message: Dictionary) -> void: heard.append([from, message["m"]]))
	guest.send(1, {"m": "hello again"})
	_run([host, guest], 0.5)
	assert_eq(heard, [[2, "hello again"]])


func test_a_player_who_left_while_the_connection_was_down_is_lost_when_it_comes_back() -> void:
	var pair := _pair()
	var host: RelayTransport = pair[0]
	var guest: RelayTransport = pair[1]
	var third := _transport()
	third.open_join(host.room, "third-token-1")
	_run([host, guest, third], 1.0)
	var guest_saw := []
	guest.peer_disconnected.connect(func(id: int) -> void: guest_saw.append("lost %d" % id))
	guest.peer_connected.connect(func(id: int) -> void: guest_saw.append("back %d" % id))
	_relay.drop(host.room, 2)
	_run([host, guest, third], 0.25)
	third.close()
	_run([host, guest], 4.0)
	assert_eq(guest_saw, ["lost 3", "back 1"] if guest_saw.find("lost 3") < guest_saw.find("back 1") else ["back 1", "lost 3"])
	assert_eq(guest.reachable_ids(), [1] as Array[int])


func test_a_connection_that_cannot_come_back_ends_with_an_error() -> void:
	var pair := _pair()
	var host: RelayTransport = pair[0]
	var guest: RelayTransport = pair[1]
	var errors := []
	guest.connect_failed.connect(func(reason: String) -> void: errors.append(reason))
	_relay.sleep()
	_run([host, guest], RelayTransport.RECONNECT_WINDOW + 10.0, 1.0)
	assert_eq(guest.state, RelayTransport.State.FAILED)
	assert_eq(errors.size(), 1)


func test_a_player_replaced_by_another_window_does_not_fight_for_the_seat() -> void:
	var pair := _pair()
	var host: RelayTransport = pair[0]
	var guest: RelayTransport = pair[1]
	var errors := []
	guest.connect_failed.connect(func(reason: String) -> void: errors.append(reason))
	_relay.drop(host.room, 2, RelaySocket.CLOSE_REPLACED)
	_run([host, guest], 5.0)
	assert_eq(guest.state, RelayTransport.State.FAILED)
	assert_eq(errors.size(), 1)
	assert_eq(_relay.connections_made, 2, "it did not try to take the seat back")


func test_garbage_and_messages_from_strangers_are_ignored() -> void:
	var pair := _pair()
	var host: RelayTransport = pair[0]
	var heard := []
	host.message_received.connect(func(from: int, message: Dictionary) -> void: heard.append([from, message]))
	host._on_text("not json")
	host._on_text("[1, 2]")
	host._on_text(NetJson.stringify({"t": "msg", "from": 77, "b": {"m": "x"}}))
	host._on_text(NetJson.stringify({"t": "msg", "from": 2, "b": "text"}))
	host._on_text(NetJson.stringify({"t": "welcome", "room": "abcdef", "id": 5, "peers": []}))
	assert_eq(heard, [])
	assert_eq(host.local_id(), 1, "a second welcome changes nothing")
