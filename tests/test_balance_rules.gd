extends TestCase
## The balance rules of milestone 6c, as invariants on the shipped data (not exact numbers): enemy
## levels mean the same as hero levels, the tower paces levelling, area spells pay off from two
## targets, and stages sit between the floors around them.

const TURN_AP := 6


func _roster() -> Roster:
	return load("res://data/progression/roster.tres") as Roster


func _tower() -> TowerConfig:
	return load("res://data/tower/tower.tres") as TowerConfig


func _hero_stats(hero: HeroData, level: int) -> Vector2i:
	var record := HeroRecord.new(hero)
	record.level = level
	var unit := UnitState.new(0, record.battle_unit_data(), UnitState.Team.PLAYER, Vector2i.ZERO)
	unit.permanent_modifiers.assign(record.modifiers())
	return Vector2i(unit.max_hp(), unit.power())


func _enemy_stats(enemy: EnemyData, level: int) -> Vector2i:
	var build := enemy.build(level)
	var unit := UnitState.new(0, build.unit, UnitState.Team.ENEMY, Vector2i.ZERO)
	unit.permanent_modifiers.assign(build.modifiers)
	return Vector2i(unit.max_hp(), unit.power())


func test_a_level_n_enemy_is_slightly_weaker_than_the_level_n_hero_it_resembles() -> void:
	var roster := _roster()
	var pairs := [["res://data/enemies/brute.tres", 0], ["res://data/enemies/archer.tres", 2]]  # Knight, Ranger.
	for pair in pairs:
		var enemy := load(pair[0]) as EnemyData
		var hero := roster.heroes[pair[1]]
		for level in [3, 10, 30, 60, 100]:
			var foe := _enemy_stats(enemy, level)
			var mine := _hero_stats(hero, level)
			var name := "%s L%d vs %s" % [enemy.display_name(), level, hero.display_name()]
			assert_true(foe.x <= mine.x * 1.02 and foe.x >= mine.x * 0.75, "%s: HP %d vs %d" % [name, foe.x, mine.x])
			assert_true(foe.y <= mine.y and foe.y >= mine.y * 0.7, "%s: Power %d vs %d" % [name, foe.y, mine.y])


func test_elites_are_stronger_than_a_normal_enemy_of_their_level_and_bosses_than_elites() -> void:
	var tower := _tower()
	var brute := load("res://data/enemies/brute.tres") as EnemyData
	var normal := brute.build(10, tower.normal_preset)
	var elite := brute.build(10, tower.elite_preset)
	var boss := brute.build(10, tower.boss_preset)
	var hp := func(build: EnemyData.Build) -> int:
		return build.modifiers.filter(func(m: StatModifier) -> bool: return m.stat == StatModifier.Stat.MAX_HP).reduce(func(sum: int, m: StatModifier) -> int: return sum + m.amount, 0)
	assert_true(hp.call(elite) > hp.call(normal) and hp.call(boss) > hp.call(elite))


## The hero level reached at the start of floor `floor_number` of a first climb that clears
## every floor.
func _hero_level_at(floor_number: int) -> int:
	var tower := _tower()
	var config := _roster().config
	var xp := 0
	for floor_index in range(1, floor_number):
		for spawn in FloorGenerator.encounter(tower, floor_index).spawns:
			xp += spawn.enemy.build(spawn.level, spawn.preset).reward.xp
	return config.level_for_xp(xp)


func test_levelling_follows_the_pace_targets() -> void:
	# Targets: level 10 around floor 25, 20 around floor 60, 30 around floor 100.
	var at_25 := _hero_level_at(25)
	var at_60 := _hero_level_at(60)
	var at_100 := _hero_level_at(100)
	assert_true(at_25 >= 9 and at_25 <= 11, "floor 25: level %d" % at_25)
	assert_true(at_60 >= 18 and at_60 <= 21, "floor 60: level %d" % at_60)
	assert_true(at_100 >= 28 and at_100 <= 31, "floor 100: level %d" % at_100)


func test_tower_enemy_levels_never_outrun_the_party_and_stay_close_behind() -> void:
	var tower := _tower()
	for floor_number in [10, 25, 40, 60, 80, 100, 120]:
		var enemy_level := FloorGenerator.encounter(tower, floor_number).spawns[-1].level
		var hero_level := _hero_level_at(floor_number)
		assert_true(enemy_level <= hero_level, "floor %d: enemy L%d vs hero L%d" % [floor_number, enemy_level, hero_level])
		assert_true(enemy_level >= hero_level - 3, "floor %d: not far behind: enemy L%d vs hero L%d" % [floor_number, enemy_level, hero_level])


func test_floors_from_ten_have_three_enemies_and_more_deeper() -> void:
	var tower := _tower()
	assert_true(FloorGenerator.encounter(tower, 12).spawns.size() >= 3)
	assert_true(FloorGenerator.encounter(tower, 45).spawns.size() >= 4)
	assert_true(FloorGenerator.encounter(tower, 90).spawns.size() >= 5)


func _best_loop_damage(spells: Array[SpellData], targets: int, want_area: bool) -> float:
	var best := 0.0
	for spell in spells:
		if (spell.area.kind != AreaShape.Kind.SINGLE) != want_area or spell.ap_cost == 0:
			continue
		var damage := 0.0
		for effect in spell.effects:
			if effect is DamageEffect:
				damage += (effect as DamageEffect).average_roll() * (effect as DamageEffect).power_scaling / 100.0
		var hit := 1 if not want_area else targets
		best = maxf(best, floorf(float(TURN_AP) / spell.ap_cost) * damage * hit)
	return best


func test_area_spells_beat_single_target_spells_from_two_targets_not_on_one() -> void:
	for hero in _roster().heroes:
		var spells: Array[SpellData] = hero.unit.spells.duplicate()
		for reward in hero.level_rewards:
			spells.append_array(reward.spells)
		var single := _best_loop_damage(spells, 1, false)
		var on_two := _best_loop_damage(spells, 2, true)
		var on_one := _best_loop_damage(spells, 1, true)
		assert_true(on_two >= single * 1.25, "%s: two targets %.1f vs single %.1f per turn" % [hero.display_name(), on_two, single])
		assert_true(on_one < single, "%s: one target %.1f stays below single %.1f" % [hero.display_name(), on_one, single])


func test_stages_sit_halfway_through_the_block_they_unlock() -> void:
	var tower := _tower()
	var previous_cap := tower.initial_cap
	for stage in tower.stages:
		assert_eq(stage.difficulty_floor, stage.unlocks_cap - 5, "%s plays as a boss at floor %d" % [stage.display_name, stage.unlocks_cap - 5])
		assert_eq(stage.unlocks_start_floor, previous_cap + 1, "%s unlocks the floor after the previous cap" % stage.display_name)
		assert_true(stage.difficulty_floor > previous_cap, "%s is harder than the floors below it" % stage.display_name)
		assert_true(stage.difficulty_floor < stage.unlocks_cap, "%s is easier than the top of its block" % stage.display_name)
		previous_cap = stage.unlocks_cap
	assert_eq(tower.stages[-1].unlocks_cap, 40, "the last stage unlocks the cap of 40")
	assert_eq(tower.stages[-1].difficulty_floor, 35)


func test_the_knight_is_the_sturdiest_hero_and_resists_physical_damage() -> void:
	var roster := _roster()
	var knight := roster.heroes[0]
	for index in [1, 2]:
		var other := _hero_stats(roster.heroes[index], 10)
		assert_true(_hero_stats(knight, 10).x > other.x * 1.3, "more HP than %s" % roster.heroes[index].display_name())
	var physical := load("res://data/damage_types/physical.tres") as DamageType
	var unit := UnitState.new(0, knight.unit, UnitState.Team.PLAYER, Vector2i.ZERO)
	assert_eq(unit.resistance_percent(physical), 10, "10 % physical resistance, innate")
