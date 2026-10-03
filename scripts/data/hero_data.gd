@tool
class_name HeroData
extends Resource
## A playable hero: its base unit (stats and starting kit) and what each level brings.

@export var unit: UnitData
## Index 0 is reaching level 2, index 1 level 3, and so on.
@export var level_rewards: Array[LevelReward] = []
## What every level past the table brings (stats only: a very high level cap needs no authored
## rewards for each level). Spells in it are ignored.
@export var growth_reward: LevelReward
## Extra rewards at particular levels past the table (e.g. 15: +1 MP, 20: +1 AP, or a spell).
@export var milestone_rewards: Dictionary[int, LevelReward] = {}


func display_name() -> String:
	return unit.display_name if unit != null else "?"


## The reward for reaching `level`, or null (level 1; or past the table with no growth rule).
## Past the table it is the growth reward plus the milestone for that level, if any.
func reward_for(level: int) -> LevelReward:
	var index := level - 2
	if index < 0:
		return null
	if index < level_rewards.size():
		return level_rewards[index]
	if growth_reward == null and not milestone_rewards.has(level):
		return null
	var reward := LevelReward.new()
	if growth_reward != null:
		reward.modifiers.append_array(growth_reward.modifiers)
	var milestone: LevelReward = milestone_rewards.get(level)
	if milestone != null:
		reward.modifiers.append_array(milestone.modifiers)
		reward.spells.append_array(milestone.spells)
	return reward


func get_validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	if unit == null:
		return PackedStringArray(["hero has no unit"])
	for error in unit.get_validation_errors():
		errors.append(error)
	var spells: Array[SpellData] = unit.spells.duplicate()
	for i in level_rewards.size():
		var reward := level_rewards[i]
		if reward == null:
			errors.append("%s: empty reward for level %d" % [display_name(), i + 2])
			continue
		spells.append_array(reward.spells)
		for error in reward.get_validation_errors():
			errors.append("%s level %d: %s" % [display_name(), i + 2, error])
	if growth_reward != null:
		if not growth_reward.spells.is_empty():
			errors.append("%s: the growth reward can't unlock spells" % display_name())
		for error in growth_reward.get_validation_errors():
			errors.append("%s growth: %s" % [display_name(), error])
	for level: int in milestone_rewards:
		var milestone := milestone_rewards[level]
		if milestone == null:
			errors.append("%s: empty milestone at level %d" % [display_name(), level])
		elif level <= level_rewards.size() + 1:
			errors.append("%s: milestone at level %d is inside the reward table" % [display_name(), level])
		else:
			spells.append_array(milestone.spells)
			for error in milestone.get_validation_errors():
				errors.append("%s milestone %d: %s" % [display_name(), level, error])
	for i in spells.size():
		if spells[i] != null and spells.find(spells[i]) != i:
			errors.append("%s learns %s twice" % [display_name(), spells[i].display_name])
	for spell in spells:
		if spell != null and spell.ap_cost > unit.ap:
			errors.append("%s: %s costs %d AP but the hero has %d at level 1" % [display_name(), spell.display_name, spell.ap_cost, unit.ap])
	return errors
