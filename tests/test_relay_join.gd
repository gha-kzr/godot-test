extends TestCase
## Hosting and joining through the relay (in memory): the host's room code, joiners landing in the host's lobby, wrong
## codes, a match that is full or started, a player who comes back to their own seat (with a new page, or after a
## dropped connection), two tabs of one browser, and a host swap with new players still joining.

const TEST_FILE := "user://test_net_session.cfg"

var _relay := FakeRelay.new()


func _init() -> void:
	MultiplayerHub.session_file = TEST_FILE
	DirAccess.remove_absolute(TEST_FILE)


func after_each_clean() -> void:
	MultiplayerHub.session_file = TEST_FILE
	DirAccess.remove_absolute(TEST_FILE)


func _hub() -> MultiplayerHub:
	var hub := MultiplayerHub.new()
	hub.make_socket = _relay.make_socket
	return hub


func _run(hubs: Array, seconds: float, step := 0.25) -> void:
	var elapsed := 0.0
	_relay.flush()
	while elapsed < seconds - 0.00001:
		for hub: MultiplayerHub in hubs:
			if hub != null:
				hub._process(step)
		_relay.flush()
		elapsed += step


func _write_token(room: String, seat: int, token: String) -> void:
	var file := ConfigFile.new()
	file.set_value("seat", "room", room)
	file.set_value("seat", "id", seat)
	file.set_value("seat", "token", token)
	file.save(MultiplayerHub.session_file)


## Host and guest in a lobby; the match started when `start` is true (both ready, one hero on each side).
func _match(start := false) -> Array:
	var host := _hub()
	host.host_room("Alice")
	_run([host], 1.0)
	var bob := _hub()
	bob.join("Bob", host.room_code)
	_run([host, bob], 2.0)
	if start:
		host.session.configure("grace", 100)
		host.session.set_field("side", 0)
		host.session.set_ready(true)
		bob.session.set_field("side", 1)
		_run([host, bob], 1.0)
		bob.session.set_ready(true)
		_run([host, bob], 1.0)
		host.session.start_match()
		_run([host, bob], 1.0)
	return [host, bob]


func test_a_host_gets_a_room_code_from_the_server() -> void:
	var host := _hub()
	var started := []
	host.session_started.connect(func() -> void: started.append(true))
	host.host_room("Alice")
	assert_true(host.session == null, "the server has not answered yet")
	assert_eq(host.status(), "Connecting to the game server...")
	_run([host], 1.0)
	assert_eq(started.size(), 1)
	assert_true(host.session.is_host() and host.session.is_synced)
	assert_eq(host.session.my_id, 1)
	assert_true(RoomCode.is_valid(host.room_code), "six letters and numbers")
	assert_eq(host.status(), "")


func test_a_player_joins_with_the_room_code_and_lands_in_the_hosts_lobby() -> void:
	var host := _hub()
	host.host_room("Alice")
	_run([host], 1.0)
	var guest := _hub()
	assert_eq(guest.join("Bob", RoomCode.pretty(host.room_code).to_upper()), "", "typed the way it was shown")
	assert_true(guest.session == null, "the server has not answered yet")
	_run([host, guest], 2.0)
	assert_true(guest.session != null and guest.session.is_synced, "joined")
	assert_eq(host.session.state.seat_ids(), [1, 2] as Array[int])
	assert_eq(guest.session.state.seats[1].name, "Alice")
	assert_eq(guest.room_code, host.room_code)
	assert_eq(guest.session.host_id, 1)
	assert_true(host.session.state.fingerprint() == guest.session.state.fingerprint())


func test_three_players_are_in_the_same_match() -> void:
	var pair := _match()
	var carol := _hub()
	carol.join("Carol", pair[0].room_code)
	_run([pair[0], pair[1], carol], 2.0)
	assert_eq(pair[0].session.state.seat_ids(), [1, 2, 3] as Array[int])
	assert_eq(carol.session.my_id, 3)
	assert_true(carol.session.state.fingerprint() == pair[0].session.state.fingerprint())


func test_a_wrong_room_code_is_told_at_once_and_something_that_is_not_a_code_is_refused() -> void:
	var guest := _hub()
	var told := []
	guest.failed.connect(func(why: String) -> void: told.append(why))
	assert_eq(guest.join("Eve", "zzzzzz"), "", "a code the server doesn't know")
	_run([guest], 1.0)
	assert_eq(told, ["No match has that code. Check it: the host may have left."])
	assert_true(guest.session == null)
	assert_ne(guest.join("Bob", "hello"), "")
	assert_ne(guest.join("Bob", ""), "")
	assert_ne(guest.join("Bob", "abc-de"), "")
	assert_ne(guest.join("Bob", "abc-de0"), "", "no look-alike characters")


func test_nobody_joins_a_full_lobby_or_a_match_that_started_unless_they_left_it() -> void:
	var pair := _match(true)
	assert_eq(pair[0].session.state.phase, MatchState.Phase.BATTLE)
	var late := _hub()
	var told := []
	late.failed.connect(func(why: String) -> void: told.append(why))
	late.join("Late", pair[0].room_code)
	_run([pair[0], pair[1], late], 3.0)
	assert_true(late.session.halted_now(), "stopped (the screen then goes back to the front page)")
	assert_eq(told, ["The match has started"], "the host's answer, so the joiner is told instead of left waiting")
	assert_eq(pair[0].session.state.seat_ids(), [1, 2] as Array[int])


func test_the_lobby_is_full_at_twelve_players() -> void:
	var host := _hub()
	host.host_room("Alice")
	_run([host], 1.0)
	var guests: Array = []
	for index in 11:
		var guest := _hub()
		guest.join("Guest %d" % index, host.room_code)
		guests.append(guest)
		_run([host] + guests, 1.0)
	assert_eq(host.session.state.seat_ids().size(), 12)
	var thirteenth := _hub()
	var told := []
	thirteenth.failed.connect(func(why: String) -> void: told.append(why))
	thirteenth.join("Thirteenth", host.room_code)
	_run([host, thirteenth] + guests, 3.0)
	assert_true(thirteenth.session == null, "never seated: the relay's room holds twelve")
	assert_eq(told, ["The match is full."])


func test_a_player_who_left_comes_back_to_their_own_seat_with_their_token() -> void:
	var pair := _match(true)
	var host: MultiplayerHub = pair[0]
	var bob: MultiplayerHub = pair[1]
	var bobs_token := bob.token
	bob.leave()  # Bob's tab closes.
	_run([host], 3.0)
	assert_false(host.session.state.seats[2].connected)
	_write_token(host.room_code, 2, bobs_token)  # His browser still has it.
	var back := _hub()
	back.join("Bob", host.room_code)
	_run([host, back], 4.0)
	assert_true(back.session != null and back.session.is_synced, "back in the fight")
	assert_eq(back.session.my_id, 2, "the same seat")
	assert_true(host.session.state.seats[2].connected)


func test_a_dropped_connection_comes_back_to_the_seat_without_a_new_page() -> void:
	var pair := _match(true)
	var host: MultiplayerHub = pair[0]
	var bob: MultiplayerHub = pair[1]
	_relay.drop(host.room_code, 2)
	_run([host, bob], 0.5)
	assert_false(host.session.state.seats[2].connected, "the host saw Bob go")
	assert_eq(bob.status(), "Connection lost: trying to come back...")
	assert_true(bob.session.connection_lost, "and the screen says so")
	assert_eq(bob.session.host_id, 1, "Bob does not decide he is the host: it is his own connection that is down")
	_run([host, bob], 6.0)
	assert_true(host.session.state.seats[2].connected, "back in the host's match")
	assert_eq(bob.status(), "")
	assert_false(bob.session.connection_lost)
	assert_eq(bob.session.host_id, 1)
	assert_true(bob.session.state.seats[2].connected, "Bob knows it too")
	assert_true(host.session.state.fingerprint() == bob.session.state.fingerprint())


func test_a_host_whose_connection_blinks_comes_back_as_a_guest_of_the_new_host() -> void:
	var pair := _match(true)
	var host: MultiplayerHub = pair[0]
	var bob: MultiplayerHub = pair[1]
	_relay.drop(host.room_code, 1)
	_run([host, bob], 0.5)
	assert_eq(bob.session.host_id, 2, "the others chose a new host")
	assert_eq(host.session.host_id, 1, "the old host does not know yet: it is offline")
	_run([host, bob], 6.0)
	assert_eq(host.session.host_id, 2, "it asked and was told: it is a guest now")
	assert_eq(bob.session.host_id, 2)
	assert_true(bob.session.state.seats[1].connected and bob.session.state.seats[2].connected)
	assert_true(host.session.state.fingerprint() == bob.session.state.fingerprint())
	assert_eq(host.session.state.entry_count(), bob.session.state.entry_count())


func test_two_tabs_of_one_browser_are_two_players() -> void:
	var host := _hub()
	host.host_room("Alice")
	_run([host], 1.0)
	_write_token(host.room_code, 1, host.token)  # This browser remembers Alice's token: another tab of hers.
	var second := _hub()
	second.join("Bob", host.room_code)
	_run([host, second], 3.0)
	assert_true(second.session != null and second.session.is_synced, "joined as a new player, not as Alice")
	assert_eq(second.session.my_id, 2)
	assert_ne(second.token, host.token, "with a token of their own")
	assert_eq(host.session.state.seat_ids(), [1, 2] as Array[int])


func test_after_a_host_swap_new_players_still_join_the_same_room() -> void:
	var pair := _match()
	var host: MultiplayerHub = pair[0]
	var bob: MultiplayerHub = pair[1]
	var code := host.room_code
	host.leave()
	_run([bob], 6.0)
	assert_eq(bob.session.host_id, 2, "Bob is the host now")
	var carol := _hub()
	carol.join("Carol", code)
	_run([bob, carol], 3.0)
	assert_true(carol.session != null and carol.session.is_synced, "Carol got into Bob's match")
	assert_eq(carol.session.host_id, 2)
	assert_eq(bob.session.state.seat_ids(), [2, 3] as Array[int], "Bob and Carol (the first host left the lobby)")


func test_a_server_that_cannot_be_reached_ends_with_a_message() -> void:
	_relay.asleep = true
	var host := _hub()
	var told := []
	host.failed.connect(func(why: String) -> void: told.append(why))
	host.host_room("Alice")
	_run([host], RelayTransport.CONNECT_DEADLINE + 10.0, 1.0)
	assert_eq(told, ["Could not reach the game server."])
	assert_true(host.transport == null)


func test_a_waiting_player_is_told_the_server_is_waking_up() -> void:
	_relay.asleep = true
	var guest := _hub()
	guest.join("Bob", "abcdef")
	_run([guest], 2.0)
	assert_eq(guest.status(), "Connecting to the game server...")
	_run([guest], 6.0)
	assert_true(guest.status().begins_with("Waking the game server up"))
