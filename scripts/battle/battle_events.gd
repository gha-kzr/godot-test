@tool
class_name BattleEvents
extends RefCounted
## What happened during an action, in order. The display replays these; tests assert on them.
## Events are data records: set once in the constructor and never modified by convention
## (GDScript has no read-only fields). Units are ids. Deaths are reported by Battle, after
## the events that caused them, for every unit that died.


@abstract class Event extends RefCounted:
	## The unit the event is about (the one it animates), or -1.
	func subject_id() -> int:
		return -1


## Base for events about one unit.
@abstract class UnitEvent extends Event:
	var unit_id: int

	func subject_id() -> int:
		return unit_id


## `ap` and `mp` are what the unit has for this turn (refilled, modifiers included).
class TurnStarted extends UnitEvent:
	var round_number: int
	var ap: int
	var mp: int

	func _init(unit: int, round_value: int, turn_ap := 0, turn_mp := 0) -> void:
		unit_id = unit
		round_number = round_value
		ap = turn_ap
		mp = turn_mp


class TurnEnded extends UnitEvent:
	func _init(unit: int) -> void:
		unit_id = unit


class UnitMoved extends UnitEvent:
	var path: Array[Vector2i]  ## Excludes the start cell, ends on the destination.
	var mp_spent: int

	func _init(unit: int, cells: Array[Vector2i], cost: int) -> void:
		unit_id = unit
		path = cells
		mp_spent = cost


## Before the battle: a hero set on another start cell (instantly, no MP).
class UnitPlaced extends UnitEvent:
	var cell: Vector2i

	func _init(unit: int, placed_on: Vector2i) -> void:
		unit_id = unit
		cell = placed_on


## A unit moved by a spell (MoveEffect), not by walking: no MP spent. `path` excludes `from`
## and ends on the new cell (one cell for a teleport or a jump; every cell for a slide).
class UnitDisplaced extends UnitEvent:
	var from: Vector2i
	var path: Array[Vector2i]
	var kind: MoveEffect.Kind

	func _init(unit: int, from_cell: Vector2i, cells: Array[Vector2i], move_kind: MoveEffect.Kind) -> void:
		unit_id = unit
		from = from_cell
		path = cells.duplicate()
		kind = move_kind

	func to() -> Vector2i:
		return path.back()


class SpellCast extends Event:
	var caster_id: int
	var spell: SpellData
	var target: Vector2i
	var area: Array[Vector2i]
	var ap_spent: int

	func _init(caster: int, cast_spell: SpellData, target_cell: Vector2i, cells: Array[Vector2i], cost: int) -> void:
		caster_id = caster
		spell = cast_spell
		target = target_cell
		area = cells.duplicate()
		ap_spent = cost

	func subject_id() -> int:
		return caster_id


## Card mode: a card was thrown away (nothing to play: the hand is what the screen shows).
class CardDiscarded extends UnitEvent:
	var spell: SpellData

	func _init(unit: int, thrown: SpellData) -> void:
		unit_id = unit
		spell = thrown


class DamageDealt extends UnitEvent:
	var amount: int
	var hp_after: int
	## What kind of damage it was (null: untyped), for the view to pick its effect.
	var damage_type: DamageType

	func _init(unit: int, damage: int, hp: int, type: DamageType = null) -> void:
		unit_id = unit
		amount = damage
		hp_after = hp
		damage_type = type


class Healed extends UnitEvent:
	var amount: int
	var hp_after: int

	func _init(unit: int, healed: int, hp: int) -> void:
		unit_id = unit
		amount = healed
		hp_after = hp


class StatusApplied extends UnitEvent:
	var status: StatusData
	var turns_left: int

	func _init(unit: int, applied: StatusData, turns: int) -> void:
		unit_id = unit
		status = applied
		turns_left = turns


## At the carrier's turn start; the tick effects' own events (damage, heal) follow.
class StatusTicked extends UnitEvent:
	var status: StatusData
	## The turns the status has left, this one included.
	var turns_left: int

	func _init(unit: int, ticked: StatusData, turns := 0) -> void:
		unit_id = unit
		status = ticked
		turns_left = turns


## At the carrier's turn end, after its last counted turn.
class StatusExpired extends UnitEvent:
	var status: StatusData

	func _init(unit: int, expired: StatusData) -> void:
		unit_id = unit
		status = expired


class UnitDied extends UnitEvent:
	func _init(unit: int) -> void:
		unit_id = unit


class BattleEnded extends Event:
	var outcome: BattleState.Outcome

	func _init(result: BattleState.Outcome) -> void:
		outcome = result
