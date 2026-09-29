@tool
class_name TowerConfig
extends Resource
## Everything the run loop needs: the tower's difficulty curve, presets, boons, map
## generation, the stalemate safety net and the stages.

## The same for every player, so floor N is the same everywhere.
@export var seed_salt := 20260929
## The tower's cap before any stage is cleared.
@export_range(1, 9999) var initial_cap := 10
## In floor order; a floor uses the last band starting at or below it.
@export var bands: Array[FloorBand] = []
@export var normal_preset: DifficultyPreset
@export var elite_preset: DifficultyPreset
@export var boss_preset: DifficultyPreset
## Enemies' AI profile (a preset's own profile, e.g. a boss's, wins).
@export var ai_profile: AIProfile
@export var boons: Array[BoonData] = []
## Boss floors at or above each value raise the boon tier by one (10: tier 1, 20: 2, 30: 3).
@export var boss_tier_floors: Array[int] = [10, 20, 30]
## How many boons a boss offers.
@export_range(1, 5) var boon_offer_size := 3
@export var map_settings: MapGenSettings
@export_range(0, 999) var sudden_death_round := 40
@export_range(1, 100) var sudden_death_percent := 10
@export var stages: Array[StageData] = []


func band_for(floor_number: int) -> FloorBand:
	var found: FloorBand = null
	for band in bands:
		if band != null and band.from_floor <= floor_number:
			found = band
	return found


static func is_boss_floor(floor_number: int) -> bool:
	return floor_number % 10 == 0


static func is_elite_floor(floor_number: int) -> bool:
	return floor_number % 10 == 5


func boon_tier(boss_floor: int) -> int:
	var tier := 0
	for threshold in boss_tier_floors:
		if boss_floor >= threshold:
			tier += 1
	return maxi(1, tier)


func get_validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	if bands.is_empty() or bands[0] == null or bands[0].from_floor != 1:
		errors.append("tower: the first band must start at floor 1")
	for band in bands:
		if band == null:
			errors.append("tower: empty band slot")
			continue
		errors.append_array(band.get_validation_errors())
	for preset in [normal_preset, elite_preset, boss_preset]:
		if preset == null:
			errors.append("tower: a preset is missing")
	if map_settings == null:
		errors.append("tower: no map settings")
	else:
		errors.append_array(map_settings.get_validation_errors())
	for tier in range(1, boss_tier_floors.size() + 1):
		var distinct: Array[BoonData] = []
		for boon in boons:
			if boon != null and boon.tier == tier and boon not in distinct:
				distinct.append(boon)
		if distinct.size() < boon_offer_size:
			errors.append("tower: fewer than %d boons in tier %d" % [boon_offer_size, tier])
	for boon in boons:
		if boon == null:
			errors.append("tower: empty boon slot")
			continue
		errors.append_array(boon.get_validation_errors())
	for stage in stages:
		if stage == null:
			errors.append("tower: empty stage slot")
			continue
		errors.append_array(stage.get_validation_errors())
	return errors
