class_name StatModifier
extends Resource
## One number a status (later: an item) changes while it's active. Units add up the
## modifiers of what they carry when asked (modifier stack); base values never change.

enum Stat {
	AP,  ## Max AP (the turn-start refill).
	MP,  ## Max MP (the turn-start refill).
	DAMAGE_TAKEN_PERCENT,  ## Added to the 100 % of damage a unit takes; total never below 0 %.
}

@export var stat := Stat.MP
@export var amount := 0


## e.g. "+2 MP", "-1 AP", "+25% damage taken".
func describe() -> String:
	var sign_text := "+" if amount > 0 else ""
	match stat:
		Stat.AP: return "%s%d AP" % [sign_text, amount]
		Stat.MP: return "%s%d MP" % [sign_text, amount]
		Stat.DAMAGE_TAKEN_PERCENT: return "%s%d%% damage taken" % [sign_text, amount]
	return "%s%d %s" % [sign_text, amount, Stat.keys()[stat].to_lower()]  # A stat added later.


func get_validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	if amount == 0:
		errors.append("modifier of %s has amount 0" % Stat.keys()[stat])
	return errors
