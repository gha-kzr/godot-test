@tool
class_name EnemyData
extends Resource
## An enemy type: its base unit (stats, spells, innate resistances) and how it scales with
## its level; XP and loot it gives. build() turns "level 5, elite" into battle input: level
## growth and preset bonuses become permanent modifiers, like a hero's levels and runes.

## Everything a battle needs to field one enemy.
class Build:
	var unit: UnitData
	var modifiers: Array[StatModifier] = []
	var reward: UnitReward
	var ai_profile: AIProfile  ## Null: the encounter's.
	var label := ""  ## e.g. "Brute Lv 5 · Elite".
	var visual_scale := 1.0


@export var unit: UnitData
@export_range(0, 100) var hp_per_level := 5
@export_range(0, 50) var power_per_level := 3
@export_range(0, 9999) var xp_base := 10
@export_range(0, 999) var xp_per_level := 3
@export var loot_table: LootTable


func display_name() -> String:
	return unit.display_name if unit != null else "?"


## The enemy at `level` (1 or more) with `preset` (null: normal).
## Null (with an error) when the enemy has no unit.
func build(level: int, preset: DifficultyPreset = null) -> Build:
	if unit == null:
		push_error("EnemyData %s: no unit" % resource_path)
		return null
	var result := Build.new()
	level = maxi(1, level)
	result.unit = unit
	var hp_bonus := hp_per_level * (level - 1)
	var power_bonus := power_per_level * (level - 1)
	var xp := float(xp_base + xp_per_level * (level - 1))
	result.reward = UnitReward.new()
	result.reward.loot_table = loot_table
	result.label = tr("%s Lv %d") % [tr(display_name()), level]
	if preset != null:
		# The multiplier applies to the levelled HP; it becomes a flat MAX_HP bonus.
		hp_bonus += roundi((unit.max_hp + hp_bonus) * (preset.hp_multiplier - 1.0))
		power_bonus += preset.power_bonus
		xp *= preset.xp_multiplier
		result.reward.extra_rolls = preset.extra_loot_rolls
		result.reward.rarity_floor = preset.rarity_floor
		result.ai_profile = preset.ai_profile
		result.visual_scale = preset.visual_scale
		result.modifiers.append_array(preset.extra_modifiers)
		if not preset.tag.is_empty():
			result.label += " · %s" % tr(preset.tag)
	if hp_bonus != 0:
		result.modifiers.append(_modifier(StatModifier.Stat.MAX_HP, hp_bonus))
	if power_bonus != 0:
		result.modifiers.append(_modifier(StatModifier.Stat.POWER, power_bonus))
	result.reward.xp = roundi(xp)
	return result


func get_validation_errors() -> PackedStringArray:
	if unit == null:
		return PackedStringArray(["enemy has no unit"])
	var errors := unit.get_validation_errors()
	if loot_table != null:
		for error in loot_table.get_validation_errors():
			errors.append("%s: %s" % [display_name(), error])
	return errors


static func _modifier(stat: StatModifier.Stat, amount: int) -> StatModifier:
	var modifier := StatModifier.new()
	modifier.stat = stat
	modifier.amount = amount
	return modifier
