class_name LootTable
extends Resource
## What an enemy can drop when a battle is won: `rolls` tries, each dropping a rune with
## `drop_chance`; a dropped rune is picked from `runes`, weighted by rarity.

@export_range(0, 10) var rolls := 1
@export_range(0.0, 1.0) var drop_chance := 0.5
@export var runes: Array[RuneData] = []


func roll(rng: RandomNumberGenerator) -> Array[RuneData]:
	var dropped: Array[RuneData] = []
	if runes.is_empty():
		return dropped
	for i in rolls:
		if rng.randf() < drop_chance:
			dropped.append(_pick(rng))
	return dropped


func _pick(rng: RandomNumberGenerator) -> RuneData:
	var total := 0
	for rune in runes:
		total += RuneData.RARITY_WEIGHTS[rune.rarity]
	var pick := rng.randi_range(1, total)
	for rune in runes:
		pick -= RuneData.RARITY_WEIGHTS[rune.rarity]
		if pick <= 0:
			return rune
	return runes.back()


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
