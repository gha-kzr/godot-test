class_name ApplyStatusEffect
extends EffectData
## Puts a status on the target, or refreshes it (the new one replaces the old). Two
## statuses are "the same" when they are the same StatusData resource.

@export var status: StatusData


func apply(state: BattleState, caster_id: int, target_id: int) -> Array[BattleEvents.Event]:
	var instance := state.units[target_id].add_status(status, caster_id)
	return [BattleEvents.StatusApplied.new(target_id, status, instance.turns_left)]


## e.g. "Poison for 3 turns (3-4 damage per turn)".
func describe() -> String:
	if status == null:
		return "no status"
	var turns := "1 turn" if status.duration == 1 else "%d turns" % status.duration
	return "%s for %s (%s)" % [status.display_name, turns, status.describe()]


func get_validation_errors() -> PackedStringArray:
	if status == null:
		return PackedStringArray(["apply status effect has no status"])
	return status.get_validation_errors()
