class_name StatusInstance
extends RefCounted
## A status on a unit: which one, how many of the unit's turns it has left, and who cast
## it (ticks act as if cast by them, even after they die). The StatusData is shared.

var data: StatusData
var turns_left: int
var caster_id: int
## True during a turn of the carrier that started with the status on (set at turn start,
## cleared by the countdown at its end). Only such turns count down, so a status applied
## during its carrier's own turn (a self-buff) doesn't lose that turn.
var counting := false


func _init(status: StatusData, caster: int, turns: int) -> void:
	data = status
	caster_id = caster
	turns_left = turns


func clone() -> StatusInstance:
	var copy := StatusInstance.new(data, caster_id, turns_left)
	copy.counting = counting
	return copy
