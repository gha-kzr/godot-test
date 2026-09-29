@tool
class_name StatusData
extends Resource
## A status a unit can carry for a few of its turns: effects fired at each of its turn
## starts (damage over time, heal over time) and stat modifiers active the whole time.
## New kinds of status are new EffectData / StatModifier kinds, not new battle code.

## Stats a status can't change yet: HP isn't re-clamped when a status comes or goes, and
## the turn order is fixed when a battle starts. Levels and runes may use them.
const UNSUPPORTED_STATS: Array[StatModifier.Stat] = [StatModifier.Stat.MAX_HP, StatModifier.Stat.INITIATIVE]

## Tags above units are spaced for labels this short.
const MAX_SHORT_LABEL := 2

@export var display_name := ""
## Icon text until there's art, e.g. "P" for Poison.
@export var short_label := ""
@export var color := Color.WHITE
## Positive statuses help the unit carrying them (for a later dispel).
@export var is_positive := false
## In the affected unit's turns: it ticks at each of its turn starts and expires at the
## end of the last one.
@export_range(1, 10) var duration := 2
## Fired at each of the unit's turn starts, on the unit, as if cast by the status's caster.
@export var tick_effects: Array[EffectData] = []
@export var modifiers: Array[StatModifier] = []


## e.g. "3-4 damage per turn, -2 MP".
func describe() -> String:
	var parts: Array[String] = []
	for effect in tick_effects:
		if effect != null:
			parts.append("%s per turn" % effect.describe())
	for modifier in modifiers:
		if modifier != null:
			parts.append(modifier.describe())
	return ", ".join(parts)


func get_validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	if display_name.is_empty():
		errors.append("status has no display_name")
	if short_label.is_empty():
		errors.append("%s: no short_label" % display_name)
	elif short_label.length() > MAX_SHORT_LABEL:
		errors.append("%s: short_label longer than %d characters" % [display_name, MAX_SHORT_LABEL])
	if duration < 1:
		errors.append("%s: duration must be >= 1" % display_name)
	if tick_effects.is_empty() and modifiers.is_empty():
		errors.append("%s: no tick effects and no modifiers" % display_name)
	for effect in tick_effects:
		if effect == null:
			errors.append("%s: empty tick effect slot" % display_name)
			continue
		if effect is ApplyStatusEffect:
			errors.append("%s: a tick can't apply a status" % display_name)
		if effect.target_filter != EffectData.TargetFilter.ALL:
			errors.append("%s: tick effects always hit the unit carrying the status; leave target_filter at ALL" % display_name)
		for error in effect.get_validation_errors():
			errors.append("%s: %s" % [display_name, error])
	for modifier in modifiers:
		if modifier == null:
			errors.append("%s: empty modifier slot" % display_name)
			continue
		if modifier.stat in UNSUPPORTED_STATS:
			errors.append("%s: statuses can't change %s yet" % [display_name, StatModifier.Stat.keys()[modifier.stat]])
		for error in modifier.get_validation_errors():
			errors.append("%s: %s" % [display_name, error])
	return errors
