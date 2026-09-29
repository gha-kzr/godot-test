@tool
class_name EnemyPreview
extends RefCounted
## An enemy's stats at several levels and presets, its XP and its loot odds, computed for
## the editor preview (and tests) with the battle rules' own accessors.

const LEVELS: Array[int] = [1, 3, 5, 10]
const PRESET_PATHS: Array[String] = ["res://data/presets/normal.tres", "res://data/presets/elite.tres", "res://data/presets/boss.tres"]


class Row:
	var level := 1
	var preset_name := ""
	var hp := 0
	var power := 0
	var xp := 0
	var resistances := ""  ## e.g. "Physical +20%".


static func rows(enemy: EnemyData, presets: Array[DifficultyPreset] = []) -> Array[Row]:
	if presets.is_empty():
		for path in PRESET_PATHS:
			if ResourceLoader.exists(path):
				presets.append(load(path))
	var result: Array[Row] = []
	for preset in presets:
		for level in LEVELS:
			var build := enemy.build(level, preset)
			var unit := UnitState.new(0, build.unit, UnitState.Team.ENEMY, Vector2i.ZERO)
			unit.permanent_modifiers.assign(build.modifiers)
			var row := Row.new()
			row.level = level
			row.preset_name = preset.display_name
			row.hp = unit.max_hp()
			row.power = unit.power()
			row.xp = build.reward.xp
			var parts: Array[String] = []
			for type in unit.resistance_types():
				parts.append("%s %+d%%" % [type.display_name, unit.resistance_percent(type)])
			row.resistances = ", ".join(parts) if not parts.is_empty() else "none"
			result.append(row)
	return result


static func summary(enemy: EnemyData) -> PackedStringArray:
	var lines := PackedStringArray()
	if enemy.unit == null:
		return PackedStringArray(["No unit set."])
	lines.append("%s — +%d HP and +%d Power per level; XP %d + %d per level" % [
			enemy.display_name(), enemy.hp_per_level, enemy.power_per_level, enemy.xp_base, enemy.xp_per_level])
	lines.append("Preset   Lv    HP  Power   XP  Resist")
	for row in rows(enemy):
		lines.append("%-7s %3d %5d %6d %4d  %s" % [row.preset_name, row.level, row.hp, row.power, row.xp, row.resistances])
	if enemy.loot_table != null and not enemy.loot_table.runes.is_empty():
		lines.append("Loot: %d roll(s) at %d%% (elite/boss add rolls):" % [enemy.loot_table.rolls, roundi(enemy.loot_table.drop_chance * 100)])
		var odds := enemy.loot_table.drop_odds()
		var runes := odds.keys()
		runes.sort_custom(func(a: RuneData, b: RuneData) -> bool: return odds[a] > odds[b])
		for rune: RuneData in runes:
			lines.append("  %-22s %s  %4.1f%% per roll" % [rune.display_name, rune.rarity_name(), odds[rune] * 100.0])
	return lines
