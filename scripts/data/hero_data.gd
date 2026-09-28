class_name HeroData
extends Resource
## A playable hero: its base unit (stats and starting kit) and what each level brings.

## Spells a hero can hold at most (base kit + unlocks).
const MAX_SPELLS := 4

@export var unit: UnitData
## Index 0 is reaching level 2, index 1 level 3, and so on.
@export var level_rewards: Array[LevelReward] = []


func display_name() -> String:
	return unit.display_name if unit != null else "?"


## The reward for reaching `level`, or null (level 1, or past the table).
func reward_for(level: int) -> LevelReward:
	var index := level - 2
	return level_rewards[index] if index >= 0 and index < level_rewards.size() else null


func get_validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	if unit == null:
		return PackedStringArray(["hero has no unit"])
	for error in unit.get_validation_errors():
		errors.append(error)
	var spell_count := unit.spells.size()
	for i in level_rewards.size():
		var reward := level_rewards[i]
		if reward == null:
			errors.append("%s: empty reward for level %d" % [display_name(), i + 2])
			continue
		spell_count += reward.spells.size()
		for error in reward.get_validation_errors():
			errors.append("%s level %d: %s" % [display_name(), i + 2, error])
	if spell_count > MAX_SPELLS:
		errors.append("%s: %d spells in total, at most %d" % [display_name(), spell_count, MAX_SPELLS])
	return errors
