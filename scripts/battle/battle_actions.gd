class_name BattleActions
extends RefCounted
## Player and AI commands (command pattern). An action names its actor by id and holds
## only its intent; validate() and apply() resolve everything against the state they're
## given, so the same action can be tried on an AI clone and then on the real battle.
## Apply only through Battle.perform(), which validates first and handles turn flow.


@abstract class Action extends RefCounted:
	var actor_id: int

	## Empty string if the action is legal in `state`, otherwise the reason it isn't.
	func validate(state: BattleState) -> String:
		if state.is_over():
			return "the battle is over"
		if actor_id < 0 or actor_id >= state.units.size():
			return "unknown unit %d" % actor_id
		if not state.units[actor_id].is_alive():
			return "unit %d is dead" % actor_id
		if state.turn_order.current_unit_id() != actor_id:
			return "it is not unit %d's turn" % actor_id
		return _validate(state)

	@abstract func _validate(state: BattleState) -> String

	## Mutates `state` and returns what happened. Assumes validate() passed.
	@abstract func apply(state: BattleState) -> Array[BattleEvents.Event]


class Move extends Action:
	var destination: Vector2i

	func _init(actor: int, cell: Vector2i) -> void:
		actor_id = actor
		destination = cell

	func _validate(state: BattleState) -> String:
		if not Movement.reach(state, actor_id).can_reach(destination):
			return "can't reach %s" % destination
		return ""

	func apply(state: BattleState) -> Array[BattleEvents.Event]:
		var reach := Movement.reach(state, actor_id)
		var unit := state.units[actor_id]
		var cost := reach.cost_to(destination)
		unit.cell = destination
		unit.mp -= cost
		return [BattleEvents.UnitMoved.new(actor_id, reach.path_to(destination), cost)]


class CastSpell extends Action:
	var spell_index: int
	var target: Vector2i

	func _init(actor: int, spell_slot: int, target_cell: Vector2i) -> void:
		actor_id = actor
		spell_index = spell_slot
		target = target_cell

	## Whether the unit has that spell and enough AP for it (range aside). Shared with the UI.
	static func can_afford(unit: UnitState, slot: int) -> bool:
		return slot >= 0 and slot < unit.data.spells.size() and unit.ap >= unit.data.spells[slot].ap_cost

	func _validate(state: BattleState) -> String:
		var unit := state.units[actor_id]
		if spell_index < 0 or spell_index >= unit.data.spells.size():
			return "unit %d has no spell %d" % [actor_id, spell_index]
		var spell := unit.data.spells[spell_index]
		if unit.ap < spell.ap_cost:
			return "%s needs %d AP, unit has %d" % [spell.display_name, spell.ap_cost, unit.ap]
		if not Targeting.can_target(state, actor_id, spell, target):
			return "%s can't target %s" % [spell.display_name, target]
		return ""

	func apply(state: BattleState) -> Array[BattleEvents.Event]:
		var caster := state.units[actor_id]
		var spell := caster.data.spells[spell_index]
		caster.ap -= spell.ap_cost
		var area := Targeting.area_cells(state.grid, spell.area, caster.cell, target)
		var events: Array[BattleEvents.Event] = [BattleEvents.SpellCast.new(actor_id, spell, target, area, spell.ap_cost)]
		# Targets are fixed before any effect lands, in area order.
		var targets: Array[int] = []
		for cell in area:
			var unit := state.unit_at(cell)
			if unit != null:
				targets.append(unit.id)
		for target_id in targets:
			for effect in spell.effects:
				if not state.units[target_id].is_alive():
					break  # A lethal effect skips the rest on that target.
				events.append_array(effect.apply(state, actor_id, target_id))
		return events


class EndTurn extends Action:
	func _init(actor: int) -> void:
		actor_id = actor

	func _validate(_state: BattleState) -> String:
		return ""

	func apply(_state: BattleState) -> Array[BattleEvents.Event]:
		return []  # Battle.perform() handles the turn change.
