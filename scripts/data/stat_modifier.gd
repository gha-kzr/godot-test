class_name StatModifier
extends Resource
## One number a status, a level or a rune changes while it's active. Units add up the
## modifiers of what they carry when asked (modifier stack); base values never change.

enum Stat {
	AP,  ## Max AP (the turn-start refill).
	MP,  ## Max MP (the turn-start refill).
	DAMAGE_TAKEN_PERCENT,  ## Added to the 100 % of damage a unit takes; total never below 0 %.
	POWER,  ## Percent added to the damage and heals the unit deals.
	RESISTANCE_PERCENT,  ## Percent less damage of `damage_type` taken (capped, see UnitState).
	MAX_HP,
	INITIATIVE,
}

@export var stat := Stat.MP
@export var amount := 0
## For per-type stats (RESISTANCE_PERCENT; later a per-type power).
@export var damage_type: DamageType


## e.g. "+2 MP", "-1 AP", "+25% damage taken", "+10 Power", "+15% Fire resistance".
func describe() -> String:
	var sign_text := "+" if amount > 0 else ""
	match stat:
		Stat.AP: return "%s%d AP" % [sign_text, amount]
		Stat.MP: return "%s%d MP" % [sign_text, amount]
		Stat.DAMAGE_TAKEN_PERCENT: return "%s%d%% damage taken" % [sign_text, amount]
		Stat.POWER: return "%s%d Power" % [sign_text, amount]
		Stat.RESISTANCE_PERCENT:
			var type_name := damage_type.display_name if damage_type != null else "?"
			return "%s%d%% %s resistance" % [sign_text, amount, type_name]
		Stat.MAX_HP: return "%s%d HP" % [sign_text, amount]
		Stat.INITIATIVE: return "%s%d initiative" % [sign_text, amount]
	return "%s%d %s" % [sign_text, amount, Stat.keys()[stat].to_lower()]  # A stat added later.


## Stats that exist per damage type (they need a damage_type; the others must not have one).
## A later per-type power gets its own Stat value here, next to general POWER.
const PER_TYPE_STATS: Array[Stat] = [Stat.RESISTANCE_PERCENT]


## Whether the modifier counts for `wanted` (a stat and, for per-type stats, a type).
## Types match exactly: a general stat never counts for a typed query or the reverse.
func applies_to(wanted: Stat, wanted_type: DamageType) -> bool:
	return stat == wanted and damage_type == wanted_type


func get_validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	if amount == 0:
		errors.append("modifier of %s has amount 0" % Stat.keys()[stat])
	if stat in PER_TYPE_STATS and damage_type == null:
		errors.append("%s modifier has no damage_type" % Stat.keys()[stat])
	elif stat not in PER_TYPE_STATS and damage_type != null:
		errors.append("%s isn't a per-type stat; remove its damage_type" % Stat.keys()[stat])
	return errors
