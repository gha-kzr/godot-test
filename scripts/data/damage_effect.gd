class_name DamageEffect
extends EffectData

@export_range(0, 999) var min_amount := 1
@export_range(0, 999) var max_amount := 1


func apply(state: BattleState, _caster_id: int, target_id: int) -> Array[BattleEvents.Event]:
	var target := state.units[target_id]
	var scaled := roundi(state.roll(min_amount, max_amount) * target.damage_taken_percent() / 100.0)
	var amount := mini(scaled, target.hp)
	target.hp -= amount
	return [BattleEvents.DamageDealt.new(target_id, amount, target.hp)]


func describe() -> String:
	return "%s damage" % amount_text(min_amount, max_amount)


func get_validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	if min_amount > max_amount:
		errors.append("damage min_amount (%d) > max_amount (%d)" % [min_amount, max_amount])
	return errors
