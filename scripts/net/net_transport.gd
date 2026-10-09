class_name NetTransport
extends RefCounted
## What a MatchSession needs from the network, whatever carries it (an in-memory fake for tests, the relay server's
## WebSockets in the browser). Peers are the other players' seat ids. A peer is *reachable* when messages can get
## to it (directly, or through another peer or a server); a message is a JSON-safe dictionary.

signal peer_connected(peer_id: int)
signal peer_disconnected(peer_id: int)
signal message_received(from_id: int, message: Dictionary)


## This player's seat id.
func local_id() -> int:
	return 0


## Whether this player's own connection works. While it doesn't (a network that blinked, being reconnected), the
## session waits instead of judging the others: it is not that they left.
func is_online() -> bool:
	return true


## The peers messages can reach now.
func reachable_ids() -> Array[int]:
	return []


## Sends to one peer (silently dropped when it can't be reached).
func send(_to_id: int, _message: Dictionary) -> void:
	pass


## Sends to every reachable peer.
func broadcast(message: Dictionary) -> void:
	for id in reachable_ids():
		send(id, message)


## Leaves the network (no more messages either way).
func close() -> void:
	pass
