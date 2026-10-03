extends TestCase
## The shipped slice content: every resource loads and validates, the map is playable,
## and AI-vs-AI battles on it finish.

const CONTENT_DIRS := ["res://data/spells", "res://data/units", "res://data/maps", "res://data/ai", "res://data/statuses", "res://data/damage_types", "res://data/runes", "res://data/heroes", "res://data/progression", "res://data/enemies", "res://data/loot", "res://data/presets", "res://data/encounters", "res://data/boons", "res://data/stages", "res://data/tower"]
const MAP := "res://data/maps/slice.tres"
const PLAYERS := ["res://data/units/knight.tres", "res://data/units/mage.tres"]
const ENEMIES := ["res://data/units/brute.tres", "res://data/units/skeleton_archer.tres"]
## AI-vs-AI battles for the balance checks (deterministic seeds; ~5 s).
const BALANCE_SEEDS := 20


func _content_paths() -> Array[String]:
	var paths: Array[String] = []
	for dir in CONTENT_DIRS:
		for file in ResourceLoader.list_directory(dir):
			if file.ends_with(".tres"):
				paths.append(dir.path_join(file))
	return paths


func _team(paths: Array) -> Array[UnitData]:
	var team: Array[UnitData] = []
	for path: String in paths:
		team.append(load(path) as UnitData)
	return team


func _slice_state(rng_seed: int) -> BattleState:
	var map := load(MAP) as MapData
	return BattleState.create(map.parse(), _team(PLAYERS), _team(ENEMIES), rng_seed)


## Cells reachable on foot from `start` over any number of turns (units ignored).
func _walkable_from(grid: Grid, start: Vector2i) -> Dictionary[Vector2i, bool]:
	var seen: Dictionary[Vector2i, bool] = {start: true}
	var queue: Array[Vector2i] = [start]
	while not queue.is_empty():
		var cell: Vector2i = queue.pop_front()
		for next in grid.neighbors(cell):
			if not seen.has(next) and Movement.step_cost(grid, cell, next) >= 0:
				seen[next] = true
				queue.append(next)
	return seen


func test_every_content_file_loads_and_validates() -> void:
	var paths := _content_paths()
	assert_true(paths.size() >= 60, "found %d content files" % paths.size())
	for path in paths:
		var resource := load(path)
		assert_true(resource != null and resource.has_method("get_validation_errors"), "%s loads as content" % path)
		if resource != null and resource.has_method("get_validation_errors"):
			assert_eq(resource.get_validation_errors(), PackedStringArray(), path)


func test_slice_teams_and_spell_kinds() -> void:
	var units := _team(PLAYERS + ENEMIES)
	var kinds := {}
	for unit in units:
		assert_true(unit.spells.size() >= 2 and unit.spells.size() <= 4, "%s has 2-4 spells" % unit.display_name)
		for spell in unit.spells:
			if spell.area.kind != AreaShape.Kind.SINGLE:
				kinds["area"] = true
			elif spell.needs_line_of_sight:
				kinds["ranged"] = true
			elif spell.max_range == 1:
				kinds["melee"] = true
	assert_eq(kinds.keys().size(), 3, "melee, ranged with LoS and area spells, got %s" % [kinds.keys()])


func test_slice_map_is_playable() -> void:
	var parsed := (load(MAP) as MapData).parse()
	assert_eq(parsed.errors, PackedStringArray())
	assert_eq(parsed.grid.size, Vector2i(10, 10))
	assert_eq(parsed.player_spawns.size(), 3, "room for the party of three")
	assert_eq(parsed.enemy_spawns.size(), ENEMIES.size())
	# Climbing and dropping limits make walking one-way, so check both directions:
	# every floor cell can walk to a spawn, and a spawn can walk to every floor cell.
	var to_spawn := Movement.distances_to(parsed.grid, parsed.player_spawns)
	var from_spawn := _walkable_from(parsed.grid, parsed.player_spawns[0])
	for y in parsed.grid.size.y:
		for x in parsed.grid.size.x:
			var cell := Vector2i(x, y)
			if parsed.grid.is_walkable(cell):
				assert_true(to_spawn.has(cell), "%s can walk to the spawns" % cell)
				assert_true(from_spawn.has(cell), "%s can be reached from the spawns" % cell)
	var heights := {}
	for y in parsed.grid.size.y:
		for x in parsed.grid.size.x:
			heights[parsed.grid.height_at(Vector2i(x, y))] = true
	assert_true(heights.size() >= 3, "a few height levels")


func test_ai_vs_ai_battles_on_the_slice_finish() -> void:
	var outcomes := {}
	var casts := {}
	for rng_seed in range(1, BALANCE_SEEDS + 1):
		var battle := Battle.new(_slice_state(rng_seed))
		battle.start()
		var actions := 0
		while not battle.state.is_over() and actions < 1000:
			var actor := battle.state.turn_order.current_unit_id()
			var result := battle.perform(EnemyAI.choose_next(battle.state, actor))
			if not result.ok():
				assert_true(false, "seed %d: invalid action: %s" % [rng_seed, result.error])
				break
			for event in result.events:
				if event is BattleEvents.SpellCast:
					var spell_name := (event as BattleEvents.SpellCast).spell.display_name
					casts[spell_name] = casts.get(spell_name, 0) + 1
			actions += 1
		assert_true(battle.state.is_over(), "seed %d: battle ends within 1000 actions" % rng_seed)
		var outcome: String = BattleState.Outcome.keys()[battle.state.outcome()]
		outcomes[outcome] = outcomes.get(outcome, 0) + 1
	print("  slice AI-vs-AI outcomes over %d seeds: %s" % [BALANCE_SEEDS, outcomes])
	print("  spells cast: %s" % casts)
	for spell_name in ["Crippling Blow", "Guard", "Slash", "Smash", "Firebolt"]:
		assert_true(casts.get(spell_name, 0) > 0, "%s gets cast by the AI" % spell_name)
	# Which Skeleton Archer attack wins depends on where the heroes stand (Bone Rain when they're close).
	assert_true(["Bone Arrow", "Pinning Shot", "Bone Rain"].any(func(s: String) -> bool: return casts.get(s, 0) > 0), "the Skeleton Archer shoots")
	# A loose balance guard (AI plays both sides): neither team should always win.
	assert_true(outcomes.get("PLAYER_WON", 0) >= BALANCE_SEEDS / 10, "players win sometimes: %s" % outcomes)
	assert_true(outcomes.get("ENEMY_WON", 0) >= BALANCE_SEEDS / 10, "enemies win sometimes: %s" % outcomes)


func test_heroes_grow_with_levels() -> void:
	var roster := load("res://data/progression/roster.tres") as Roster
	assert_eq(roster.heroes.size(), 3)
	var profile := Profile.create(roster)
	assert_eq(profile.party, [0, 1, 2] as Array[int], "all three heroes play from the start")
	var knight := profile.heroes[0]
	assert_eq(knight.spells().size(), 3, "level 1: base kit")
	knight.level = 3
	assert_eq(knight.spells().size(), 4, "level 3: Whirlwind")
	assert_eq(knight.spells().back().display_name, "Whirlwind")
	knight.level = 6
	var mp := knight.modifiers().filter(func(m: StatModifier) -> bool: return m.stat == StatModifier.Stat.MP)
	assert_eq(mp.size(), 1, "level 6: +1 MP")
	assert_eq(profile.heroes[1].spells().size() + 1, 4, "the Mage learns Regeneration at 3")
	profile.heroes[1].level = 3
	assert_eq(profile.heroes[1].spells().back().display_name, "Regeneration")
	for record in profile.heroes:
		record.level = 100
		assert_true(record.spells().size() <= HeroRecord.LOADOUT_SLOTS, "%s within the loadout" % record.hero.display_name())


func test_enemies_give_xp_and_loot() -> void:
	for path in ["res://data/enemies/brute.tres", "res://data/enemies/skeleton_archer.tres", "res://data/enemies/ghoul.tres", "res://data/enemies/ghost.tres"]:
		var enemy := load(path) as EnemyData
		assert_true(enemy.xp_base > 0, "%s gives XP" % enemy.display_name())
		assert_true(enemy.loot_table != null and not enemy.loot_table.runes.is_empty(), "%s drops runes" % enemy.display_name())


func test_heroes_grow_differently() -> void:
	var roster := load("res://data/progression/roster.tres") as Roster
	var growth := func(hero: HeroData, stat: StatModifier.Stat) -> int:
		return hero.reward_for(2).modifiers.filter(func(m: StatModifier) -> bool: return m.stat == stat)[0].amount
	var knight := roster.heroes[0]
	var mage := roster.heroes[1]
	assert_true(growth.call(knight, StatModifier.Stat.MAX_HP) > growth.call(mage, StatModifier.Stat.MAX_HP), "the Knight gains more HP")
	assert_true(growth.call(mage, StatModifier.Stat.POWER) > growth.call(knight, StatModifier.Stat.POWER), "the Mage gains more Power")


func test_each_enemy_resists_a_hero_damage_type() -> void:
	var brute := load("res://data/units/brute.tres") as UnitData
	var skeleton := load("res://data/units/skeleton_archer.tres") as UnitData
	var ghost := load("res://data/units/ghost.tres") as UnitData
	var state := BattleFixtures.state_with("0p 0e 0e 0e", [BattleFixtures.unit("P0", 200)] as Array[UnitData], [brute, skeleton, ghost] as Array[UnitData])
	var holy := load("res://data/damage_types/holy.tres") as DamageType
	assert_eq(state.units[1].resistance_percent(load("res://data/damage_types/physical.tres")), 20, "the Brute resists the Knight")
	assert_eq(state.units[2].resistance_percent(load("res://data/damage_types/poison.tres")), 50, "the Skeleton Archer shrugs off the Ranger's poison")
	assert_eq(state.units[3].resistance_percent(load("res://data/damage_types/physical.tres")), 100, "the Ghost is immune to physical damage")
	for unit in [state.units[2], state.units[3]]:
		assert_true(unit.resistance_percent(holy) < 0, "%s: Holy hurts the undead more" % unit.label)


func test_the_ghoul_and_the_ghost_use_their_kits() -> void:
	var casts := {}
	for rng_seed in range(1, 6):
		var map := load(MAP) as MapData
		var battle := Battle.new(BattleState.create(map.parse(), _team(["res://data/units/knight.tres", "res://data/units/ranger.tres"]),
				_team(["res://data/units/ghoul.tres", "res://data/units/ghost.tres"]), rng_seed))
		battle.start()
		var actions := 0
		while not battle.state.is_over() and actions < 1000:
			var result := battle.perform(EnemyAI.choose_next(battle.state, battle.state.turn_order.current_unit_id()))
			assert_true(result.ok(), result.error)
			for event in result.events:
				if event is BattleEvents.SpellCast:
					var spell_name := (event as BattleEvents.SpellCast).spell.display_name
					casts[spell_name] = casts.get(spell_name, 0) + 1
			actions += 1
		assert_true(battle.state.is_over(), "seed %d ends" % rng_seed)
	print("  ghoul and ghost casts: %s" % casts)
	for spell_name in ["Rend", "Devour", "Chill Touch", "Wail"]:
		assert_true(casts.get(spell_name, 0) > 0, "%s gets cast by the AI" % spell_name)
