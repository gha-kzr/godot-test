@tool
class_name LootTable
extends Resource
## What an enemy can drop when a battle is won: `rolls` tries, each dropping a rune with
## `drop_chance`; a dropped rune is picked from `runes`, weighted by rarity.

@export_range(0, 10) var rolls := 1
@export_range(0.0, 1.0) var drop_chance := 0.5
@export var runes: Array[RuneData] = []


## `extra_rolls` (e.g. from a preset) add tries; drops are at least `rarity_floor` rare
## (the whole table if nothing is that rare).
func roll(rng: RandomNumberGenerator, extra_rolls := 0, rarity_floor := RuneData.Rarity.COMMON) -> Array[RuneData]:
	var dropped: Array[RuneData] = []
	var pool := runes.filter(func(r: RuneData) -> bool: return r.rarity >= rarity_floor)
	if pool.is_empty():
		pool = runes
	if pool.is_empty():
		return dropped
	for i in rolls + extra_rolls:
		if rng.randf() < drop_chance:
			dropped.append(_pick(rng, pool))
	return dropped


## Probability that one roll drops each rune (for previews).
func drop_odds(rarity_floor := RuneData.Rarity.COMMON) -> Dictionary[RuneData, float]:
	var odds: Dictionary[RuneData, float] = {}
	var pool := runes.filter(func(r: RuneData) -> bool: return r.rarity >= rarity_floor)
	if pool.is_empty():
		pool = runes
	var total := 0
	for rune in pool:
		total += RuneData.RARITY_WEIGHTS[rune.rarity]
	for rune in pool:
		odds[rune] = drop_chance * RuneData.RARITY_WEIGHTS[rune.rarity] / float(total)
	return odds


static func _pick(rng: RandomNumberGenerator, pool: Array) -> RuneData:
	var total := 0
	for rune: RuneData in pool:
		total += RuneData.RARITY_WEIGHTS[rune.rarity]
	var pick := rng.randi_range(1, total)
	for rune: RuneData in pool:
		pick -= RuneData.RARITY_WEIGHTS[rune.rarity]
		if pick <= 0:
			return rune
	return pool.back()


func get_validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	if drop_chance < 0.0 or drop_chance > 1.0:
		errors.append("loot table drop_chance must be within 0-1")
	if rolls > 0 and drop_chance > 0.0 and runes.is_empty():
		errors.append("loot table can drop but has no runes")
	for rune in runes:
		if rune == null:
			errors.append("loot table: empty rune slot")
	return errors
