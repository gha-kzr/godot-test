class_name BattleFx
extends Resource
## The battle's default effects: a hit that has no damage type, a heal. Damage types carry their
## own (`DamageType.impact_effect`) and a spell can override (`SpellData.impact_effect`).

@export var default_impact: PackedScene
@export var heal: PackedScene
## A burst on a unit a status was just put on (tinted with the status color); none when empty.
@export var status_applied: PackedScene


## The effect on a cell of a spell's area where no unit stands (the spell still lands): its own
## impact effect, else its first typed damage's, else the heal effect for a healing spell, else
## the default.
func cell_effect_for(spell: SpellData) -> PackedScene:
	if spell.impact_effect != null:
		return spell.impact_effect
	for effect in spell.effects:
		if effect is DamageEffect and (effect as DamageEffect).damage_type != null \
				and (effect as DamageEffect).damage_type.impact_effect != null:
			return (effect as DamageEffect).damage_type.impact_effect
	for effect in spell.effects:
		if effect is DamageEffect:
			return default_impact
	for effect in spell.effects:
		if effect is HealEffect and heal != null:
			return heal
	return default_impact


## The effect for a hit: the spell's own, else the damage type's, else the default (or null).
func impact_for(damage_type: DamageType, spell: SpellData) -> PackedScene:
	if spell != null and spell.impact_effect != null:
		return spell.impact_effect
	if damage_type != null and damage_type.impact_effect != null:
		return damage_type.impact_effect
	return default_impact
