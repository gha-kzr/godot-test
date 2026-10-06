@tool
class_name CleanseEffect
extends EffectData
## Removes statuses from the target: the harmful ones (a cleanse, on allies) or the helpful ones (a dispel, on enemies).

enum Remove { HARMFUL, HELPFUL }

@export var remove := Remove.HARMFUL


func apply(state: BattleState, _caster_id: int, target_id: int) -> Array[BattleEvents.Event]:
	var target := state.units[target_id]
	var events: Array[BattleEvents.Event] = []
	for status in target.statuses.duplicate():
		if status.data.is_positive == (remove == Remove.HELPFUL):
			target.statuses.erase(status)
			events.append(BattleEvents.StatusExpired.new(target_id, status.data))
	return events


func describe() -> String:
	return tr("Removes harmful effects") if remove == Remove.HARMFUL else tr("Removes helpful effects")
