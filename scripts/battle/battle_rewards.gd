@tool
class_name BattleRewards
extends RefCounted
## What a won battle gives: the XP of every enemy killed and the runes their loot tables
## drop. Resolved once, at the end of the fight; a lost fight (or a draw) gives nothing.

var xp := 0
var runes: Array[RuneData] = []


static func compute(state: BattleState) -> BattleRewards:
	var rewards := BattleRewards.new()
	if state.outcome() != BattleState.Outcome.PLAYER_WON:
		return rewards
	# Loot has its own dice, seeded from the battle: the same battle drops the same runes.
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([state.rng.seed, "loot"])
	for unit in state.units:
		if unit.team != UnitState.Team.ENEMY or unit.is_alive() or unit.reward == null:
			continue
		rewards.xp += unit.reward.xp
		if unit.reward.loot_table != null:
			rewards.runes.append_array(unit.reward.loot_table.roll(rng, unit.reward.extra_rolls, unit.reward.rarity_floor))
	return rewards
