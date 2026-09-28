@abstract
class_name EffectData
extends Resource
## Base class for what a spell does to each unit in its area (strategy pattern).
## New effect kinds are new subclasses; spells and actions don't change.

## Which units in the spell's area the effect applies to.
enum TargetFilter {
	ALL,  ## Every unit in the area, allies and the caster included.
	ALLIES,  ## Units of the caster's team in the area (the caster too, if inside).
	ENEMIES,  ## Units of the other team in the area.
	CASTER,  ## Only the caster, once, whether or not it stands in the area.
}

@export var target_filter := TargetFilter.ALL


## Applies the effect to one living target and returns the resulting events.
## Mutates `state`; units are looked up by id so this works on AI clones too.
@abstract func apply(state: BattleState, caster_id: int, target_id: int) -> Array[BattleEvents.Event]


## Short player-facing text, e.g. "5-7 damage". Every effect kind describes itself.
@abstract func describe() -> String


## describe() plus who it applies to, e.g. "6-10 heal (allies only)".
func full_description() -> String:
	match target_filter:
		TargetFilter.ALLIES: return describe() + " (allies only)"
		TargetFilter.ENEMIES: return describe() + " (enemies only)"
		TargetFilter.CASTER: return describe() + " (caster only)"
	return describe()


## "5" or "5-7", for describe().
static func amount_text(low: int, high: int) -> String:
	return str(low) if low == high else "%d-%d" % [low, high]


func get_validation_errors() -> PackedStringArray:
	return PackedStringArray()
