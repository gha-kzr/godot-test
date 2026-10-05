@tool
class_name RuneData
extends Resource
## An item a hero equips in one of its 6 rune slots. Hand-made, fixed stats, a rarity.
## Common and rare runes stack (a hero may wear copies); epic and legendary are unique
## per hero. Only stat modifiers for now; the resource can hold other effects later.

enum Rarity { COMMON, RARE, EPIC, LEGENDARY }

## Grey, green, blue, orange: distinct at a glance (playtest feedback).
const RARITY_COLORS: Array[Color] = [Color(0.6, 0.62, 0.66), Color(0.3, 0.72, 0.3), Color(0.25, 0.5, 0.95), Color(0.95, 0.55, 0.1)]
## Relative drop weights, by rarity.
const RARITY_WEIGHTS: Array[int] = [60, 25, 10, 5]
## Rune levels: an owned rune is a rune file at a level 1 to MAX_LEVEL; each level past the first adds
## LEVEL_STEP of the file's amounts (AP and MP stay flat: +1 AP is already the strongest stat).
const MAX_LEVEL := 10
const LEVEL_STEP := 0.2
## Essence a salvaged rune gives at level 1, by rarity (times its level).
const SALVAGE_ESSENCE: Array[int] = [1, 3, 8, 20]
## Essence a fuse costs per level of the result.
const FUSE_ESSENCE_PER_LEVEL := 5
## Runes needed to fuse (they are consumed; the result is one level higher).
const FUSE_COPIES := 3

@export var display_name := ""
@export var rarity := Rarity.COMMON
@export var modifiers: Array[StatModifier] = []

## The level of this rune (the file itself is level 1).
var level := 1
## For a rune above level 1: the file it is a leveled copy of (null on the file itself).
var base: RuneData


## The rune file this is (or a copy of).
func origin() -> RuneData:
	return base if base != null else self


## Whether levels change this rune: not when all its amounts are AP or MP (those stay flat, so
## a level would only be a number). Such a rune is always level 1 and can't be fused.
func can_level() -> bool:
	return modifiers.any(func(m: StatModifier) -> bool: return m != null and m.stat != StatModifier.Stat.AP and m.stat != StatModifier.Stat.MP)


## `rune` at `level_` (1 to MAX_LEVEL): the file itself at level 1 (or when levels change nothing for
## it), else a copy with the amounts scaled.
static func leveled(rune: RuneData, level_: int) -> RuneData:
	var source := rune.origin()
	level_ = clampi(level_, 1, MAX_LEVEL)
	if level_ == 1 or not source.can_level():
		return source
	var copy := RuneData.new()
	copy.display_name = source.display_name
	copy.rarity = source.rarity
	copy.base = source
	copy.level = level_
	for modifier in source.modifiers:
		if modifier == null:
			continue
		var scaled := modifier.duplicate() as StatModifier
		scaled.amount = scaled_amount(modifier, level_)
		copy.modifiers.append(scaled)
	return copy


## A modifier's amount at a rune level (rounded, never below the base amount's size).
static func scaled_amount(modifier: StatModifier, level_: int) -> int:
	if modifier.stat == StatModifier.Stat.AP or modifier.stat == StatModifier.Stat.MP:
		return modifier.amount
	var factor := 1.0 + LEVEL_STEP * (level_ - 1)
	return signi(modifier.amount) * maxi(absi(modifier.amount), roundi(absi(modifier.amount) * factor))


## Whether `other` is the same rune file at the same level (what fusing needs).
func is_same_kind(other: RuneData) -> bool:
	return other != null and origin() == other.origin() and level == other.level


## The name with its level, e.g. "Rune of Might (level 3)"; level 1 is just the name.
func title() -> String:
	return tr(display_name) if level <= 1 else tr("%s (level %d)") % [tr(display_name), level]


## Essence a salvage gives.
func salvage_value() -> int:
	return SALVAGE_ESSENCE[rarity] * level


## Essence a fuse into the next level costs (0 at the highest level, where it can't fuse).
func fuse_cost() -> int:
	return FUSE_ESSENCE_PER_LEVEL * (level + 1) if level < MAX_LEVEL else 0


## The level a drop gets from the enemy's level: 1 + level / 5, a fifth of the drops one higher.
static func level_for_enemy(enemy_level: int, rng: RandomNumberGenerator) -> int:
	var depth_level := 1 + maxi(enemy_level, 1) / 5
	return clampi(depth_level + (1 if rng.randf() < 0.2 else 0), 1, MAX_LEVEL)


func is_unique() -> bool:
	return rarity >= Rarity.EPIC


func color() -> Color:
	return RARITY_COLORS[rarity]


func rarity_name() -> String:
	match rarity:
		Rarity.COMMON: return tr("Common")
		Rarity.RARE: return tr("Rare")
		Rarity.EPIC: return tr("Epic")
		Rarity.LEGENDARY: return tr("Legendary")
	return Rarity.keys()[rarity].capitalize()


## e.g. "+10 Power, +5 HP".
func describe() -> String:
	var parts: Array[String] = []
	for modifier in modifiers:
		if modifier != null:
			parts.append(modifier.describe())
	return ", ".join(parts)


func get_validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	if display_name.is_empty():
		errors.append("rune has no display_name")
	if modifiers.is_empty():
		errors.append("%s: no modifiers" % display_name)
	for modifier in modifiers:
		if modifier == null:
			errors.append("%s: empty modifier slot" % display_name)
			continue
		for error in modifier.get_validation_errors():
			errors.append("%s: %s" % [display_name, error])
	return errors
