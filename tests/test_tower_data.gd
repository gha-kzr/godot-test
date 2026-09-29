extends TestCase
## The tower's data: difficulty bands, floor kinds, boon tiers, stages, validation.

const TOWER := "res://data/tower/tower.tres"


func _tower() -> TowerConfig:
	return load(TOWER) as TowerConfig


func test_the_shipped_tower_is_valid() -> void:
	assert_eq(_tower().get_validation_errors(), PackedStringArray())
	assert_eq(_tower().stages.size(), 3)
	assert_eq(_tower().initial_cap, 10)


func test_floor_kinds() -> void:
	for floor_number in [5, 15, 25, 35]:
		assert_true(TowerConfig.is_elite_floor(floor_number), "%d is an elite floor" % floor_number)
		assert_false(TowerConfig.is_boss_floor(floor_number))
	for floor_number in [10, 20, 30]:
		assert_true(TowerConfig.is_boss_floor(floor_number))
		assert_false(TowerConfig.is_elite_floor(floor_number))
	assert_false(TowerConfig.is_elite_floor(1) or TowerConfig.is_boss_floor(1))


func test_bands_and_levels_follow_the_floor() -> void:
	var tower := _tower()
	assert_eq(tower.band_for(1).from_floor, 1)
	assert_eq(tower.band_for(4).from_floor, 1)
	assert_eq(tower.band_for(5).from_floor, 5)
	assert_eq(tower.band_for(99).from_floor, 30)
	assert_eq(tower.band_for(1).level_on(1), 1, "floor 1 starts easy")
	assert_true(tower.band_for(35).level_on(35) > tower.band_for(12).level_on(12), "levels rise")


func test_boon_tiers_by_boss_floor() -> void:
	var tower := _tower()
	assert_eq(tower.boon_tier(10), 1)
	assert_eq(tower.boon_tier(20), 2)
	assert_eq(tower.boon_tier(30), 3)
	assert_eq(tower.boon_tier(90), 3, "the last tier stays")
	for tier in [1, 2, 3]:
		assert_true(tower.boons.filter(func(b: BoonData) -> bool: return b.tier == tier).size() >= 3, "3 boons in tier %d" % tier)


func test_validation_catches_broken_data() -> void:
	var tower := TowerConfig.new()
	var errors := Array(tower.get_validation_errors())
	assert_true(errors.any(func(e: String) -> bool: return "first band must start at floor 1" in e))
	assert_true(errors.any(func(e: String) -> bool: return "preset is missing" in e))
	assert_true(errors.any(func(e: String) -> bool: return "fewer than 3 boons in tier 1" in e))
	var band := FloorBand.new()
	band.min_enemies = 3
	band.max_enemies = 1
	errors = Array(band.get_validation_errors())
	assert_true(errors.any(func(e: String) -> bool: return "min_enemies > max_enemies" in e))
	var stage := StageData.new()
	stage.display_name = "S"
	stage.unlocks_cap = 10
	stage.unlocks_start_floor = 11
	assert_true(Array(stage.get_validation_errors()).any(func(e: String) -> bool: return "above the cap" in e))
	assert_eq((load("res://data/boons/surge.tres") as BoonData).describe(), "+20 Power")
