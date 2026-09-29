@tool
class_name DifficultyPreset
extends Resource
## How much harder an enemy is than normal (normal / elite / boss): stat boosts, better
## rewards, optionally a sharper AI and a visual cue. Applied by EnemyData.build().

@export var display_name := "Normal"
## Shown after the enemy's name and level, e.g. "Elite" in "Brute Lv 5 · Elite"; empty for none.
@export var tag := ""
@export var tag_color := Color.WHITE
@export_range(0.1, 10.0) var hp_multiplier := 1.0
@export_range(-100, 500) var power_bonus := 0
## Extra modifiers (e.g. resistances) on top of the enemy's own.
@export var extra_modifiers: Array[StatModifier] = []
@export_range(0.0, 20.0) var xp_multiplier := 1.0
@export_range(0, 10) var extra_loot_rolls := 0
## Drops are at least this rare (falls back to the whole table if it has nothing that rare).
@export var rarity_floor := RuneData.Rarity.COMMON
## Replaces the encounter's AI profile for enemies with this preset (null: keep it).
@export var ai_profile: AIProfile
@export_range(0.5, 3.0) var visual_scale := 1.0


func get_validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	if display_name.is_empty():
		errors.append("preset has no display_name")
	for modifier in extra_modifiers:
		if modifier == null:
			errors.append("%s: empty modifier slot" % display_name)
			continue
		for error in modifier.get_validation_errors():
			errors.append("%s: %s" % [display_name, error])
	return errors
