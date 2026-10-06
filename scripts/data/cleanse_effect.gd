@tool
class_name CleanseEffect
extends EffectData
## Removes statuses from the target: the harmful ones (a cleanse, on allies) or the helpful ones (a dispel, on enemies).

enum Remove { HARMFUL, HELPFUL }

@export var remove := Remove.HARMFUL


func apply(state: BattleState, _caster_id: int, target_id: int) -> Array[BattleEvents.Event]:
	var target := state.units[target_id]
	var events: Array[BattleEvents.Event] = []
	var ap_before := target.max_ap()
	var mp_before := target.max_mp()
	for status in target.statuses.duplicate():
		if status.data.is_positive == (remove == Remove.HELPFUL):
			target.statuses.erase(status)
			events.append(BattleEvents.StatusExpired.new(target_id, status.data))
	# Current AP and MP follow the change in their maxima, as when a status is put on (a freed unit can act again).
	target.ap = maxi(0, target.ap + target.max_ap() - ap_before)
	target.mp = maxi(0, target.mp + target.max_mp() - mp_before)
	return events


func describe() -> String:
	return tr("Removes harmful effects") if remove == Remove.HARMFUL else tr("Removes helpful effects")
