@tool
class_name DamagePreview
extends RefCounted
## What a cast would do to each unit, without doing it: the exact damage and heal bounds,
## whether it can kill, and the statuses it would apply. Read-only: the cast is played on
## two clones of the state (every roll at its lowest, then at its highest), so the numbers
## come from the battle's own formula (power, resistances, damage taken, HP caps, effects
## in order, filters) and can't drift from it.


## One unit's outcome. Damage and heal are after caps (no more than the HP it has or misses).
class Entry extends RefCounted:
	var unit_id := -1
	var min_damage := 0
	var max_damage := 0
	var min_heal := 0
	var max_heal := 0
	## Whether the highest roll leaves the unit dead.
	var can_kill := false
	var statuses: Array[StatusData] = []

	## "8-11" for damage, "+6-10" for a heal, both joined by " / "; empty when neither.
	func amount_text() -> String:
		var parts: Array[String] = []
		if max_damage > 0:
			parts.append(EffectData.amount_text(min_damage, max_damage))
		if max_heal > 0:
			parts.append("+" + EffectData.amount_text(min_heal, max_heal))
		return " / ".join(parts)


## The entries (in unit id order) of `caster_id` casting its spell `spell_index` on
## `target`; empty if the cast isn't legal.
static func for_cast(state: BattleState, caster_id: int, spell_index: int, target: Vector2i) -> Array[Entry]:
	var entries: Dictionary[int, Entry] = {}
	var action := BattleActions.CastSpell.new(caster_id, spell_index, target)
	if not action.validate(state).is_empty():
		return []
	for bound: BattleState.RollBound in [BattleState.RollBound.LOWEST, BattleState.RollBound.HIGHEST]:
		var simulated := state.clone()
		simulated.roll_bound = bound
		var highest := bound == BattleState.RollBound.HIGHEST
		for event in action.apply(simulated):
			if event is BattleEvents.DamageDealt:
				var hit := event as BattleEvents.DamageDealt
				if hit.amount == 0:
					continue  # Fully resisted: nothing to show.
				var entry := _entry(entries, hit.unit_id)
				if highest:
					entry.max_damage += hit.amount
					entry.can_kill = entry.can_kill or hit.hp_after == 0
				else:
					entry.min_damage += hit.amount
			elif event is BattleEvents.Healed:
				var healed := event as BattleEvents.Healed
				if healed.amount == 0:
					continue
				var entry := _entry(entries, healed.unit_id)
				if highest:
					entry.max_heal += healed.amount
				else:
					entry.min_heal += healed.amount
			elif event is BattleEvents.StatusApplied:
				var applied := event as BattleEvents.StatusApplied
				var entry := _entry(entries, applied.unit_id)
				if applied.status not in entry.statuses:
					entry.statuses.append(applied.status)
	var ids := entries.keys()
	ids.sort()
	var result: Array[Entry] = []
	for id: int in ids:
		result.append(entries[id])
	return result


static func _entry(entries: Dictionary[int, Entry], unit_id: int) -> Entry:
	if not entries.has(unit_id):
		var entry := Entry.new()
		entry.unit_id = unit_id
		entries[unit_id] = entry
	return entries[unit_id]
