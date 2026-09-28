extends EffectData
## Test-only effect: damages the caster, not the target. Proves deaths outside a
## spell's area are detected.

var amount := 1


func apply(state: BattleState, caster_id: int, _target_id: int) -> Array[BattleEvents.Event]:
	var caster := state.units[caster_id]
	var dealt := mini(amount, caster.hp)
	caster.hp -= dealt
	return [BattleEvents.DamageDealt.new(caster_id, dealt, caster.hp)]


func describe() -> String:
	return "%d recoil damage to the caster" % amount
