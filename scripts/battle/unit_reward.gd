@tool
class_name UnitReward
extends RefCounted
## What killing a unit gives in a won battle (enemies only): XP and loot rolls.

var xp := 0
var loot_table: LootTable
var extra_rolls := 0
var rarity_floor := RuneData.Rarity.COMMON
