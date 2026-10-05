extends TestCase
## Map and floor generation: deterministic per floor, always playable.

const TOWER := "res://data/tower/tower.tres"


func _tower() -> TowerConfig:
	return load(TOWER) as TowerConfig


func _labels(encounter: Encounter) -> Array:
	return encounter.builds().map(func(b: EnemyData.Build) -> String: return b.label)


func test_a_floor_is_the_same_every_time() -> void:
	var a := FloorGenerator.encounter(_tower(), 1)
	var b := FloorGenerator.encounter(_tower(), 1)
	assert_eq(a.map.layout, b.map.layout, "same map")
	assert_eq(_labels(a), _labels(b), "same enemies")
	assert_ne(FloorGenerator.encounter(_tower(), 2).map.layout, a.map.layout, "another floor differs")


func test_the_first_hundred_floors_are_valid_and_playable() -> void:
	var tower := _tower()
	for floor_number in range(1, 101):
		var encounter := FloorGenerator.encounter(tower, floor_number)
		var errors := encounter.get_validation_errors()
		if not errors.is_empty():
			assert_eq(errors, PackedStringArray(), "floor %d" % floor_number)
			return
		assert_true(MapGenerator.is_playable(encounter.map, encounter.spawns.size(), tower.map_settings.min_enemy_distance),
				"floor %d is connected, its zone far enough from the enemies" % floor_number)
		assert_eq(encounter.map.parse().player_spawns.size(), 9, "floor %d has a 3 x 3 start zone" % floor_number)


func test_elite_and_boss_floors() -> void:
	var tower := _tower()
	assert_true(_labels(FloorGenerator.encounter(tower, 5))[0].ends_with("Elite"), "floor 5: an elite")
	assert_false(_labels(FloorGenerator.encounter(tower, 4)).any(func(l: String) -> bool: return l.ends_with("Elite") or l.ends_with("Boss")))
	var boss := FloorGenerator.encounter(tower, 10)
	assert_true(_labels(boss)[0].ends_with("Boss"), "floor 10: a boss")
	assert_true(boss.spawns.size() >= 2, "with escorts")
	var band := tower.band_for(10)
	var side := band.map_max_size + FloorBand.BOSS_SIZE_BONUS
	assert_true(boss.map.parse().grid.size.x >= side, "a bigger map than the band's (%s)" % boss.map.parse().grid.size)


func test_enemies_get_stronger_with_depth() -> void:
	var tower := _tower()
	assert_eq(FloorGenerator.encounter(tower, 1).spawns[0].level, 1)
	assert_true(FloorGenerator.encounter(tower, 41).spawns[0].level > FloorGenerator.encounter(tower, 11).spawns[0].level)
	assert_true(FloorGenerator.encounter(tower, 1).spawns.size() <= 2, "floor 1: one or two enemies")


func test_stages_are_deterministic_boss_fights() -> void:
	var tower := _tower()
	var stage := tower.stages[0]
	var a := FloorGenerator.stage_encounter(tower, stage)
	assert_eq(a.map.layout, FloorGenerator.stage_encounter(tower, stage).map.layout)
	assert_eq(a.display_name, "Ruined Gate")
	assert_true(_labels(a)[0].ends_with("Boss"))
	assert_ne(a.map.layout, FloorGenerator.encounter(tower, 10).map.layout, "not the same as floor 10")


func test_generated_maps_obey_the_climbing_rule() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	for i in 20:
		var map := MapGenerator.generate(rng, _tower().map_settings, 3)
		var grid := map.parse().grid
		for y in grid.size.y:
			for x in grid.size.x:
				var cell := Vector2i(x, y)
				if not grid.is_walkable(cell):
					continue
				for next in grid.neighbors(cell):
					if grid.is_walkable(next):
						assert_true(absi(grid.height_at(cell) - grid.height_at(next)) <= 1, "neighbours differ by at most one level")


func _zone_is_a_square(zone: Array[Vector2i]) -> bool:
	var low := zone[0]
	for cell in zone:
		low = Vector2i(mini(low.x, cell.x), mini(low.y, cell.y))
	for dy in 3:
		for dx in 3:
			if low + Vector2i(dx, dy) not in zone:
				return false
	return true


func test_each_layout_places_a_square_zone_away_from_the_enemies() -> void:
	var settings := _tower().map_settings
	for layout: int in MapGenerator.Layout.values():
		var rng := RandomNumberGenerator.new()
		rng.seed = 7 + layout
		for i in 10:
			var map := MapGenerator.generate(rng, settings, 3, false, layout)
			var parsed := map.parse()
			assert_true(_zone_is_a_square(parsed.player_spawns), "layout %d: a 3 x 3 zone" % layout)
			assert_true(MapGenerator.is_playable(map, 3, settings.min_enemy_distance), "layout %d, map %d" % [layout, i])
			var center := parsed.player_spawns[4]
			var size := parsed.grid.size
			match layout:
				MapGenerator.Layout.EDGE:
					assert_eq(center.y, size.y - 2, "EDGE: at the bottom")
				MapGenerator.Layout.CORNER:
					assert_true(center == Vector2i(1, size.y - 2) or center == Vector2i(size.x - 2, size.y - 2), "CORNER: %s" % center)
					var far_side := 1 if center.x == 1 else -1
					for spawn in parsed.enemy_spawns:
						assert_true((spawn.x - center.x) * far_side >= 1, "CORNER: %s toward the far corner from %s" % [spawn, center])
				MapGenerator.Layout.AMBUSH:
					assert_true(absi(center.x - size.x / 2) <= 1 and absi(center.y - size.y / 2) <= 1, "AMBUSH: in the middle")


func test_layouts_follow_the_weights_and_ambushes_wait() -> void:
	var settings := _tower().map_settings.duplicate() as MapGenSettings
	settings.edge_weight = 0
	settings.corner_weight = 0
	settings.ambush_weight = 1
	var rng := RandomNumberGenerator.new()
	assert_eq(MapGenerator.pick_layout(rng, settings, settings.ambush_from_floor), MapGenerator.Layout.AMBUSH)
	assert_eq(MapGenerator.pick_layout(rng, settings, settings.ambush_from_floor - 1), MapGenerator.Layout.EDGE, "too early: no ambush")
	var ambushes: Array[int] = []
	for floor_number in range(1, 101):
		var parsed := FloorGenerator.encounter(_tower(), floor_number).map.parse()
		if parsed.player_spawns[4].y < parsed.grid.size.y - 2:
			ambushes.append(floor_number)
	assert_false(ambushes.is_empty(), "some ambushes")
	assert_true(ambushes.size() < 30, "but rare: %s" % [ambushes])
	assert_true(ambushes.min() >= _tower().map_settings.ambush_from_floor, "not before floor %d" % _tower().map_settings.ambush_from_floor)


func test_too_many_enemies_are_reported_not_hung() -> void:
	var rng := RandomNumberGenerator.new()
	expect_error("7 enemies")
	var map := MapGenerator.generate(rng, _tower().map_settings, 7, false, MapGenerator.Layout.AMBUSH)
	assert_eq(map.parse().enemy_spawns.size(), MapGenerator.MAX_ENEMIES, "clamped")


func test_generated_blocks_stand_on_their_plateau() -> void:
	var raised := 0
	var pattern := RegEx.create_from_string("^[1-9][0-9]*#$")
	for floor_number in range(1, 40):
		var map := FloorGenerator.encounter(_tower(), floor_number).map
		assert_true(map.parse().errors.is_empty(), "floor %d parses" % floor_number)
		for token in map.layout.split(" ", false):
			if pattern.search(token.strip_edges()) != null:
				raised += 1
	assert_true(raised > 0, "some generated blocks sit on raised ground, not sunk to level 0")


func test_a_floor_has_at_most_one_ghost_and_it_is_never_the_boss() -> void:
	var tower := load("res://data/tower/tower.tres") as TowerConfig
	var ghost := load("res://data/enemies/ghost.tres") as EnemyData
	assert_eq(ghost.max_per_floor, 1)
	var seen := 0
	for floor_number in range(25, 125):
		var encounter := FloorGenerator.encounter(tower, floor_number)
		var ghosts := encounter.spawns.filter(func(s: EncounterSpawn) -> bool: return s.enemy == ghost).size()
		assert_true(ghosts <= 1, "floor %d: %d ghosts" % [floor_number, ghosts])
		seen += ghosts
		if TowerConfig.is_boss_floor(floor_number):
			assert_ne(encounter.spawns[0].enemy, ghost, "floor %d: the boss isn't a ghost" % floor_number)
	assert_true(seen > 10, "ghosts do appear (%d)" % seen)
	for band in tower.bands:
		assert_false(ghost in band.boss_pool, "no ghost boss from floor %d" % band.from_floor)


func test_the_cap_holds_even_when_the_pool_draws_it_every_time() -> void:
	var tower := (load("res://data/tower/tower.tres") as TowerConfig).duplicate(true) as TowerConfig
	var ghost := load("res://data/enemies/ghost.tres") as EnemyData
	var brute := load("res://data/enemies/brute.tres") as EnemyData
	for band in tower.bands:
		band.enemy_pool = [ghost, ghost, ghost, ghost, brute] as Array[EnemyData]
	for floor_number in range(1, 40):
		var encounter := FloorGenerator.encounter(tower, floor_number)
		assert_true(encounter.spawns.filter(func(s: EncounterSpawn) -> bool: return s.enemy == ghost).size() <= 1, "floor %d" % floor_number)


func test_floors_are_built_from_the_bands_compositions() -> void:
	var tower := load("res://data/tower/tower.tres") as TowerConfig
	for floor_number in range(1, 130):
		var encounter := FloorGenerator.encounter(tower, floor_number)
		var band := tower.band_for(floor_number)
		var boss := TowerConfig.is_boss_floor(floor_number)
		var sizes := (band.boss_compositions if boss else band.compositions).map(func(c: CompositionData) -> int: return c.slots.size())
		assert_true(encounter.spawns.size() in sizes, "floor %d: %d enemies, a composition's size" % [floor_number, encounter.spawns.size()])
		assert_eq(encounter.get_validation_errors(), PackedStringArray(), "floor %d" % floor_number)
		var roles := encounter.spawns.map(func(s: EncounterSpawn) -> EnemyData.Role: return s.enemy.role)
		var matched := (band.boss_compositions if boss else band.compositions).any(func(c: CompositionData) -> bool:
			return c.slots.map(func(slot: CompositionSlot) -> EnemyData.Role: return slot.enemy.role if slot.enemy != null else slot.role) == roles)
		assert_true(matched, "floor %d: the roles follow a composition (%s)" % [floor_number, roles])
		if boss:
			assert_eq(encounter.spawns[0].preset, tower.boss_preset, "floor %d: the first slot is the boss" % floor_number)
		elif TowerConfig.is_elite_floor(floor_number):
			assert_eq(encounter.spawns[0].preset, tower.elite_preset, "floor %d: the first slot is the elite" % floor_number)


func test_a_fixed_enemy_slot_and_the_weights() -> void:
	var tower := (load("res://data/tower/tower.tres") as TowerConfig).duplicate(true) as TowerConfig
	var pack := load("res://data/compositions/wolf_pack.tres") as CompositionData
	var warg := load("res://data/enemies/warg.tres") as EnemyData
	tower.bands[2].compositions = [pack] as Array[CompositionData]  # The band from floor 10.
	var encounter := FloorGenerator.encounter(tower, 11)
	assert_eq(encounter.spawns.slice(0, 2).map(func(s: EncounterSpawn) -> EnemyData: return s.enemy), [warg, warg], "two Wargs")
	assert_eq(encounter.spawns[2].enemy.role, EnemyData.Role.RANGED)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var heavy := CompositionData.new()
	heavy.weight = 9
	var light := CompositionData.new()
	var counts := {heavy: 0, light: 0}
	for i in 1000:
		counts[FloorGenerator._pick_composition([heavy, light] as Array[CompositionData], rng)] += 1
	assert_true(counts[heavy] > 800 and counts[light] > 50, "about 9 to 1: %s" % [counts.values()])


func test_a_band_without_compositions_still_draws_at_random() -> void:
	var tower := (load("res://data/tower/tower.tres") as TowerConfig).duplicate(true) as TowerConfig
	var band := tower.bands[2]
	band.compositions = [] as Array[CompositionData]
	band.boss_compositions = [] as Array[CompositionData]
	var encounter := FloorGenerator.encounter(tower, 11)
	assert_true(encounter.spawns.size() >= band.min_enemies and encounter.spawns.size() <= band.max_enemies)


func test_a_composition_needing_a_role_the_pool_lacks_is_reported() -> void:
	var band := (load("res://data/tower/tower.tres") as TowerConfig).bands[0].duplicate() as FloorBand
	band.compositions = [load("res://data/compositions/shield_line.tres")] as Array[CompositionData]  # Tank, support: not before floor 10.
	assert_true(Array(band.get_validation_errors()).any(func(e: String) -> bool: return "needs a tank" in e), str(band.get_validation_errors()))


func _has_error(errors: PackedStringArray, part: String) -> bool:
	return Array(errors).any(func(e: String) -> bool: return part in e)


func test_compositions_maps_cant_hold_or_caps_they_break_are_reported() -> void:
	var composition := CompositionData.new()
	composition.label = "horde"
	for i in MapGenerator.MAX_ENEMIES + 1:
		composition.slots.append(CompositionSlot.new())
	assert_true(_has_error(composition.get_validation_errors(), "at most %d enemies" % MapGenerator.MAX_ENEMIES))
	var ghost := load("res://data/enemies/ghost.tres") as EnemyData
	composition.slots = [] as Array[CompositionSlot]
	for i in ghost.max_per_floor + 1:
		var slot := CompositionSlot.new()
		slot.enemy = ghost
		composition.slots.append(slot)
	assert_true(_has_error(composition.get_validation_errors(), "per floor"), str(composition.get_validation_errors()))
	composition.weight = 0
	assert_true(_has_error(composition.get_validation_errors(), "weight"))


func test_band_map_sizes_and_weights_are_checked() -> void:
	var band := _tower().bands[0].duplicate() as FloorBand
	band.map_min_size = 0
	band.map_max_size = 14
	assert_true(_has_error(band.get_validation_errors(), "or neither"))
	band.map_min_size = 6
	assert_true(_has_error(band.get_validation_errors(), "map sizes must be"))
	band.map_min_size = 12
	band.map_max_size = 24
	assert_true(_has_error(band.get_validation_errors(), "map sizes must be"))
	band.map_max_size = 14
	var typologies := band.map_typologies.duplicate()
	typologies[typologies.keys()[0]] = 0
	band.map_typologies = typologies
	assert_true(_has_error(band.get_validation_errors(), "weight below 1"))


func test_a_positioning_past_a_heros_reach_is_reported() -> void:
	var positioning := Positioning.new()
	positioning.max_distance = Positioning.MAX_DISTANCE + 1
	assert_true(_has_error(positioning.get_validation_errors(), "kite"))


func test_map_sizes_grow_with_the_tower_and_stop() -> void:
	var tower := _tower()
	for floor_number: int in [1, 7, 12, 33, 45, 99, 251]:  # Not boss floors (those get 2 more).
		var size := FloorGenerator.encounter(tower, floor_number).map.parse().grid.size
		var expected := Vector2i(9, 11) if floor_number < 10 else (Vector2i(12, 15) if floor_number < 40 else Vector2i(15, 18))
		expected.y = maxi(expected.y, tower.map_settings.ambush_size)  # An ambush map is at least that big.
		for side in [size.x, size.y]:
			assert_true(side >= expected.x and side <= expected.y, "floor %d: %s within %s" % [floor_number, size, expected])
	for floor_number: int in [500, 990]:  # Boss floors: 2 more, within the cap.
		var boss_size := FloorGenerator.encounter(tower, floor_number).map.parse().grid.size
		assert_true(maxi(boss_size.x, boss_size.y) <= FloorBand.MAX_MAP_SIZE, "floor %d: %s never past the cap" % [floor_number, boss_size])


func test_every_typology_makes_playable_maps_quickly() -> void:
	var settings := _tower().map_settings
	for file in ResourceLoader.list_directory("res://data/maps/typologies"):
		var typology := load("res://data/maps/typologies/" + file) as MapTypology
		var rng := RandomNumberGenerator.new()
		rng.seed = 11
		var playable := 0
		var tries := 40
		for i in tries:
			var layout := i % 3 as MapGenerator.Layout
			var map := MapGenerator._attempt(rng, settings, 2 + i % 4, layout, typology, Vector2i(12, 18))
			if map != null and MapGenerator.is_playable(map, 2 + i % 4, settings.min_enemy_distance):
				playable += 1
		assert_true(playable >= tries / 2, "%s: %d of %d attempts playable (20 attempts per map)" % [file, playable, tries])


func test_enemies_spawn_a_bounded_walk_away_on_any_board() -> void:
	var tower := _tower()
	var settings := tower.map_settings
	for floor_number in range(40, 70):
		var parsed := FloorGenerator.encounter(tower, floor_number).map.parse()
		var to_zone := Movement.distances_to(parsed.grid, parsed.player_spawns)
		var from_zone := Movement.distances_from(parsed.grid, parsed.player_spawns)
		for spawn in parsed.enemy_spawns:
			for distance: int in [to_zone.get(spawn, -1), from_zone.get(spawn, -1)]:  # Its walk, and the heroes'.
				assert_true(distance >= settings.min_enemy_distance and distance <= settings.max_enemy_distance,
						"floor %d: an enemy %d MP away on a %s board" % [floor_number, distance, parsed.grid.size])


func test_stages_have_their_own_shape() -> void:
	var tower := _tower()
	var expected := {"ruined_gate": "ruins", "sunken_crypt": "crater", "sky_bastion": "islands"}
	for stage in tower.stages:
		var name := stage.resource_path.get_file().get_basename()
		assert_eq(stage.map_typology.resource_path.get_file().get_basename(), expected[name], name)


## Fingerprints of a few floors (every typology, an ambush, elite and boss floors) and the
## stages: a change that alters the generated floors (noise settings, an extra random draw)
## fails here, so it is made on purpose. After such a change, update GOLDEN_FLOORS from the
## failure messages.
const GOLDEN_FLOORS := {
	"floor 1": "0564191eaa9ac41559df552e6b731bc7",
	"floor 5": "ba1b4378508047a4d9e44ea296a2a4f8",
	"floor 10": "6fb039c425bbca96868cc88e03959637",
	"floor 13": "c14e51ea6dc118ef507867423d734074",
	"floor 17": "7f57e50a306f52684b8446a6a6dd46c7",
	"floor 22": "43a6c223d07d9ba5e36b704358a1cedb",
	"floor 24": "59690552c054e7fe867c068695a4590d",
	"floor 26": "275ba1f749cbc9017c74fe940541ef51",
	"floor 31": "41b28ebfea9fdddb730721d5c60509ba",
	"floor 40": "56dd170fb1825f56285f655bd9510399",
	"floor 47": "75fb04c63ceff1e080d4fdb7760f9054",
	"floor 58": "5a191b263d22f12b07318ddb683c07ca",
	"floor 75": "ab7e0a3fa8168b45dee345a43558dedf",
	"ruined_gate": "07b06c341ac9538bec8008532507e0c5",
	"sunken_crypt": "894d51fbb552a490d7f8f96fa9451dfc",
	"sky_bastion": "6cb5cf97848dcbae48bc42f685147774",
}


func _fingerprint(encounter: Encounter) -> String:
	return (encounter.map.layout + "|" + ",".join(_labels(encounter))).md5_text()


func test_floors_keep_their_exact_maps() -> void:
	var tower := _tower()
	var encounters := {}
	for floor_number: int in [1, 5, 10, 13, 17, 22, 24, 26, 31, 40, 47, 58, 75]:
		encounters["floor %d" % floor_number] = FloorGenerator.encounter(tower, floor_number)
	for stage in tower.stages:
		encounters[stage.resource_path.get_file().get_basename()] = FloorGenerator.stage_encounter(tower, stage)
	for key: String in encounters:
		var encounter: Encounter = encounters[key]
		var typology := encounter.map_typology.resource_path.get_file().get_basename() if encounter.map_typology != null else "?"
		assert_eq(_fingerprint(encounter), GOLDEN_FLOORS.get(key, ""), "%s (%s, %s)" % [key, typology, encounter.layout_name])
