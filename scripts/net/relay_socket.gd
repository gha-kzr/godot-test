class_name RelaySocket
extends RefCounted
## One WebSocket to the relay server, as far as the transport needs it: connect, send text, receive text,
## closed. A real one wraps WebSocketPeer; tests use an in-memory fake (tests/fake_relay.gd).

signal opened
signal closed
signal text_received(text: String)

## The server's reason for closing, when it gave one (4000: another connection of this player replaced this one).
const CLOSE_REPLACED := 4000
## Room for the longest message there is (a whole match log, for a player catching up).
const BUFFER_BYTES := 4 * 1024 * 1024

var url := ""
var is_open := false
var close_code := -1


func connect_to(address: String) -> void:
	url = address


func send_text(_text: String) -> void:
	pass


func poll() -> void:
	pass


func close() -> void:
	pass


## The real thing: a WebSocketPeer polled every frame.
class Real extends RelaySocket:
	var _peer := WebSocketPeer.new()
	var _done := false

	func connect_to(address: String) -> void:
		url = address
		_peer.inbound_buffer_size = BUFFER_BYTES
		_peer.outbound_buffer_size = BUFFER_BYTES
		_peer.max_queued_packets = 4096
		if _peer.connect_to_url(address) != OK:
			_done = true
			closed.emit()

	func send_text(text: String) -> void:
		if is_open:
			_peer.send_text(text)

	func poll() -> void:
		if _done:
			return
		_peer.poll()
		match _peer.get_ready_state():
			WebSocketPeer.STATE_OPEN:
				if not is_open:
					is_open = true
					opened.emit()
				while _peer.get_available_packet_count() > 0:
					text_received.emit(_peer.get_packet().get_string_from_utf8())
			WebSocketPeer.STATE_CLOSED:
				_done = true
				is_open = false
				close_code = _peer.get_close_code()
				closed.emit()

	func close() -> void:
		if not _done:
			_peer.close()
			_done = true
			is_open = false
			closed.emit()
