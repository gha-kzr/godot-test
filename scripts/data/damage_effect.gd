@tool
class_name DamageEffect
extends EffectData

@export_range(0, 999) var min_amount := 1
@export_range(0, 999) var max_amount := 1
## Null: untyped, never resisted.
@export var damage_type: DamageType
## How much of the caster's Power applies, in percent (100: all of it; 150: a heavy hit
## that gains more from Power; 50: a light one).
@export_range(0, 500) var power_scaling := 100


func apply(state: BattleState, caster_id: int, target_id: int) -> Array[BattleEvents.Event]:
	var target := state.units[target_id]
	var amount := mini(roundi(scaled(state, caster_id, target_id, state.roll(min_amount, max_amount))), target.hp)
	target.hp -= amount
	return [BattleEvents.DamageDealt.new(target_id, amount, target.hp, damage_type)]


## A roll after the caster's power and the target's damage taken and resistance:
## roll x (100 + power) % x damage taken % x (100 - resistance) %.
func scaled(state: BattleState, caster_id: int, target_id: int, roll: float) -> float:
	var target := state.units[target_id]
	var power := state.units[caster_id].power() if caster_id >= 0 else 0
	return roll * power_multiplier(power) * target.damage_taken_percent() / 100.0 \
			* (100.0 - target.resistance_percent(damage_type)) / 100.0


## (100 + Power x power_scaling %) / 100, never below 0.
func power_multiplier(power: int) -> float:
	return maxf(0.0, 100.0 + power * power_scaling / 100.0) / 100.0


func average_roll() -> float:
	return (min_amount + max_amount) / 2.0


func describe() -> String:
	var type_text := damage_type.display_name.to_lower() + " " if damage_type != null else ""
	var scaling_text := " (%d%% Power)" % power_scaling if power_scaling != 100 else ""
	return "%s %sdamage%s" % [amount_text(min_amount, max_amount), type_text, scaling_text]


func get_validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	if min_amount > max_amount:
		errors.append("damage min_amount (%d) > max_amount (%d)" % [min_amount, max_amount])
	return errors
