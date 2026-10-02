@tool
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
	var signed := ("+" if amount > 0 else "") + str(amount)
	match stat:
		Stat.AP: return tr("%s AP") % signed
		Stat.MP: return tr("%s MP") % signed
		Stat.DAMAGE_TAKEN_PERCENT: return tr("%s%% damage taken") % signed
		Stat.POWER: return tr("%s Power") % signed
		Stat.RESISTANCE_PERCENT:
			var type_name := tr(damage_type.display_name) if damage_type != null else "?"
			return tr("%s%% %s resistance") % [signed, type_name]
		Stat.MAX_HP: return tr("%s HP") % signed
		Stat.INITIATIVE: return tr("%s initiative") % signed
	return "%s %s" % [signed, Stat.keys()[stat].to_lower()]  # A stat added later: no text to translate yet.


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
