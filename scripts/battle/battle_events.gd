class_name BattleEvents
extends RefCounted
## What happened during an action, in order. The display replays these; tests assert on them.
## Events are data records: set once in the constructor and never modified by convention
## (GDScript has no read-only fields). Units are ids. Deaths are reported by Battle, after
## the action's own events, for every unit that died during it.


@abstract class Event extends RefCounted:
	pass


class TurnStarted extends Event:
	var unit_id: int
	var round_number: int

	func _init(unit: int, round_value: int) -> void:
		unit_id = unit
		round_number = round_value


class TurnEnded extends Event:
	var unit_id: int

	func _init(unit: int) -> void:
		unit_id = unit


class UnitMoved extends Event:
	var unit_id: int
	var path: Array[Vector2i]  ## Excludes the start cell, ends on the destination.
	var mp_spent: int

	func _init(unit: int, cells: Array[Vector2i], cost: int) -> void:
		unit_id = unit
		path = cells
		mp_spent = cost


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


class DamageDealt extends Event:
	var unit_id: int
	var amount: int
	var hp_after: int

	func _init(unit: int, damage: int, hp: int) -> void:
		unit_id = unit
		amount = damage
		hp_after = hp


class Healed extends Event:
	var unit_id: int
	var amount: int
	var hp_after: int

	func _init(unit: int, healed: int, hp: int) -> void:
		unit_id = unit
		amount = healed
		hp_after = hp


class UnitDied extends Event:
	var unit_id: int

	func _init(unit: int) -> void:
		unit_id = unit


class BattleEnded extends Event:
	var outcome: BattleState.Outcome

	func _init(result: BattleState.Outcome) -> void:
		outcome = result
