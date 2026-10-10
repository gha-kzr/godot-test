@tool
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


## A cast applies its effects through this, with the cell the spell was aimed at; effects that
## need it (a teleport's destination) override it. Status ticks call apply() directly.
func apply_cast(state: BattleState, caster_id: int, target_id: int, _target_cell: Vector2i) -> Array[BattleEvents.Event]:
	return apply(state, caster_id, target_id)


## Whether a spell with this effect may be aimed at `cell`, beyond its range and sight (a
## teleport needs a free cell). Targeting asks every effect, so the highlights, the AI and
## validation agree.
func allows_target(_state: BattleState, _caster_id: int, _cell: Vector2i) -> bool:
	return true


## Whether the effect hurts the unit it lands on (damage, a harmful status). With friendly fire off
## (BattleState.friendly_fire) a harmful effect skips the caster's own team.
func is_harmful() -> bool:
	return false


## Short player-facing text, e.g. "5-7 damage". Every effect kind describes itself.
@abstract func describe() -> String


## describe() plus who it applies to, e.g. "6-10 heal (allies only)".
func full_description() -> String:
	match target_filter:
		TargetFilter.ALLIES: return tr("%s (allies only)") % describe()
		TargetFilter.ENEMIES: return tr("%s (enemies only)") % describe()
		TargetFilter.CASTER: return tr("%s (caster only)") % describe()
	return describe()


## "5" or "5-7", for describe().
static func amount_text(low: int, high: int) -> String:
	return str(low) if low == high else "%d-%d" % [low, high]


func get_validation_errors() -> PackedStringArray:
	return PackedStringArray()
