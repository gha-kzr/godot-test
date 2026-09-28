@abstract
class_name EffectData
extends Resource
## Base class for what a spell does to each unit in its area (strategy pattern).
## New effect kinds are new subclasses; spells and actions don't change.


## Applies the effect to one living target and returns the resulting events.
## Mutates `state`; units are looked up by id so this works on AI clones too.
@abstract func apply(state: BattleState, caster_id: int, target_id: int) -> Array[BattleEvents.Event]


## Short player-facing text, e.g. "5-7 damage". Every effect kind describes itself.
@abstract func describe() -> String


## "5" or "5-7", for describe().
static func amount_text(low: int, high: int) -> String:
	return str(low) if low == high else "%d-%d" % [low, high]


func get_validation_errors() -> PackedStringArray:
	return PackedStringArray()
