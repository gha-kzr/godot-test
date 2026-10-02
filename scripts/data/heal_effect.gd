@tool
class_name HealEffect
extends EffectData

@export_range(0, 999) var min_amount := 1
@export_range(0, 999) var max_amount := 1
## How much of the caster's Power applies, in percent (see DamageEffect).
@export_range(0, 500) var power_scaling := 100


func apply(state: BattleState, caster_id: int, target_id: int) -> Array[BattleEvents.Event]:
	var target := state.units[target_id]
	var amount := clampi(roundi(scaled(state, caster_id, state.roll(min_amount, max_amount))), 0, maxi(0, target.max_hp() - target.hp))
	target.hp += amount
	return [BattleEvents.Healed.new(target_id, amount, target.hp)]


## A roll after the caster's power: roll x (100 + power) %.
func scaled(state: BattleState, caster_id: int, roll: float) -> float:
	var power := state.units[caster_id].power() if caster_id >= 0 else 0
	return roll * maxf(0.0, 100.0 + power * power_scaling / 100.0) / 100.0


func average_roll() -> float:
	return (min_amount + max_amount) / 2.0


func describe() -> String:
	var amount := amount_text(min_amount, max_amount)
	if power_scaling == 100:
		return tr("heals %s") % amount
	return tr("heals %s (%d%% Power)") % [amount, power_scaling]


func get_validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	if min_amount > max_amount:
		errors.append("heal min_amount (%d) > max_amount (%d)" % [min_amount, max_amount])
	return errors
