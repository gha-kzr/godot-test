extends TestCase
## The run loop's rules: starting runs, battles from the director, results, boss choices,
## caps and stages, saving and resuming.

const TOWER := "res://data/tower/tower.tres"
const ROSTER := "res://data/progression/roster.tres"


func _config() -> TowerConfig:
	return load(TOWER) as TowerConfig


func _profile() -> Profile:
	return Profile.create(load(ROSTER) as Roster)


## The battle the director sets up, ended as a win (all enemies dead) or a loss.
func _finish(profile: Profile, config: TowerConfig, win: bool, party_hp: Array = []) -> BattleState:
	var setup := RunDirector.battle_setup(profile, config)
	var enemies: Array[UnitData] = []
	var builds := setup.encounter.builds()
	for build in builds:
		enemies.append(build.unit)
	var state := BattleState.create(setup.encounter.map.parse(), setup.units, enemies, 1, setup.modifiers, builds, setup.hero_hp)
	for unit in state.units:
		if (unit.team == UnitState.Team.ENEMY) == win:
			unit.hp = 0
	for i in party_hp.size():
		state.units[i].hp = party_hp[i]
	return state


func test_a_tower_run_starts_at_an_unlocked_floor() -> void:
	var profile := _profile()
	assert_eq(RunDirector.start_tower(profile, _config(), 11), "Floor 11 isn't unlocked as a starting floor.")
	assert_eq(profile.run, null)
	assert_eq(RunDirector.start_tower(profile, _config(), 1), "")
	assert_eq([profile.run.floor_number, profile.run.hero_hp], [1, [-1, -1, -1]])


func test_battle_setup_uses_the_floor_and_the_party() -> void:
	var profile := _profile()
	RunDirector.start_tower(profile, _config())
	var setup := RunDirector.battle_setup(profile, _config())
	assert_eq(setup.title, "Floor 1")
	assert_eq(setup.encounter.map.layout, FloorGenerator.encounter(_config(), 1).map.layout)
	assert_eq(setup.units.size(), profile.party.size())
	assert_eq(setup.sudden_death_round, 40)


func test_a_won_floor_moves_on_and_carries_hp_with_a_25_percent_floor() -> void:
	var profile := _profile()
	var config := _config()
	RunDirector.start_tower(profile, config)
	var state := _finish(profile, config, true, [0, 20])  # The Knight fell, the Mage is at 20.
	var report := RunDirector.apply_result(profile, config, state)
	assert_true(report.won and not report.run_over)
	assert_eq(profile.run.floor_number, 2)
	assert_eq(profile.best_depth, 1)
	var knight_max := RunDirector.max_hp(profile, 0)
	assert_eq(profile.run.hero_hp[0], ceili(knight_max * 0.25), "revived at 25%")
	assert_eq(profile.run.hero_hp[1], 20, "kept above 25%")
	assert_true(profile.heroes[0].xp > 0, "rewards applied")


func test_a_loss_ends_the_run_and_gives_nothing() -> void:
	var profile := _profile()
	RunDirector.start_tower(profile, _config())
	var report := RunDirector.apply_result(profile, _config(), _finish(profile, _config(), false))
	assert_true(report.run_over and not report.success)
	assert_eq(profile.run, null)
	assert_eq(profile.heroes[0].xp, 0)
	assert_eq(profile.best_depth, 0)


func test_a_boss_offers_boons_or_a_heal() -> void:
	var profile := _profile()
	var config := _config()
	profile.cleared_stages.append(config.stages[0])  # Cap 20, so floor 10 isn't the top.
	RunDirector.start_tower(profile, config)
	profile.run.floor_number = 10
	var report := RunDirector.apply_result(profile, config, _finish(profile, config, true))
	assert_eq(report.boss_offer.size(), 3)
	assert_true(profile.run.awaiting_choice())
	assert_true(report.boss_offer.all(func(b: BoonData) -> bool: return b.tier == 1), "tier 1 at floor 10")
	assert_eq(RunDirector.offer(config, 10), report.boss_offer, "the same offer for everyone")
	var boon := report.boss_offer[1]
	RunDirector.apply_boss_choice(profile, 1, true)
	assert_eq(profile.run.boons, [boon] as Array[BoonData])
	assert_eq(profile.run.floor_number, 11)
	assert_false(profile.run.awaiting_choice())
	var setup := RunDirector.battle_setup(profile, config)
	assert_true(boon.modifiers.all(func(m: StatModifier) -> bool: return m in setup.modifiers[0] and m in setup.modifiers[1]), "worn by the whole team")


func test_the_heal_instead_of_a_boon_and_leaving() -> void:
	var profile := _profile()
	var config := _config()
	profile.cleared_stages.append(config.stages[0])
	RunDirector.start_tower(profile, config)
	profile.run.floor_number = 10
	RunDirector.apply_result(profile, config, _finish(profile, config, true, [5, 5]))
	var report := RunDirector.apply_boss_choice(profile, RunDirector.HEAL, false)
	assert_true(report.run_over and report.success, "leaving ends the run as a success")
	assert_eq(profile.run, null)
	assert_eq(profile.best_depth, 10)


func test_clearing_the_cap_ends_the_run_as_a_success() -> void:
	var profile := _profile()
	var config := _config()
	RunDirector.start_tower(profile, config)
	profile.run.floor_number = 10  # The initial cap.
	var report := RunDirector.apply_result(profile, config, _finish(profile, config, true))
	assert_true(report.run_over and report.success)
	assert_eq(report.boss_offer.size(), 0, "no offer at the cap")
	assert_eq(profile.best_depth, 10)


func test_a_cleared_stage_raises_the_cap_and_adds_a_starting_floor() -> void:
	var profile := _profile()
	var config := _config()
	assert_false(profile.is_stage_available(config, config.stages[1]), "stages in order")
	assert_eq(RunDirector.start_stage(profile, config, config.stages[1]), "Clear the previous stage first.")
	assert_eq(RunDirector.start_stage(profile, config, config.stages[0]), "")
	assert_eq(RunDirector.battle_setup(profile, config).title, "Ruined Gate")
	var report := RunDirector.apply_result(profile, config, _finish(profile, config, true))
	assert_true(report.run_over and report.success)
	assert_eq(report.stage_cleared, config.stages[0])
	assert_eq(profile.tower_cap(config), 20)
	assert_eq(profile.start_floors(config), [1, 11] as Array[int])
	assert_true(profile.is_stage_available(config, config.stages[1]))


func test_a_run_survives_a_save_and_reload() -> void:
	var profile := _profile()
	var config := _config()
	profile.cleared_stages.append(config.stages[0])
	RunDirector.start_tower(profile, config)
	profile.run.floor_number = 10
	RunDirector.apply_result(profile, config, _finish(profile, config, true, [7, 30]))
	RunDirector.apply_boss_choice(profile, 0, true)
	var loaded := Profile.from_dict(profile.to_dict(), profile.roster)
	assert_eq(loaded.run.floor_number, 11)
	assert_eq(loaded.run.hero_hp, profile.run.hero_hp)
	assert_eq(loaded.run.boons, profile.run.boons)
	assert_eq(loaded.best_depth, 10)
	assert_eq(loaded.cleared_stages, profile.cleared_stages)
	var pending := _profile()
	pending.cleared_stages.append(config.stages[0])
	RunDirector.start_tower(pending, config)
	pending.run.floor_number = 10
	RunDirector.apply_result(pending, config, _finish(pending, config, true))
	assert_eq(Profile.from_dict(pending.to_dict(), pending.roster).run.boss_offer, pending.run.boss_offer, "a pending offer resumes too")


func test_a_boss_choice_with_no_boons_left_still_offers_the_heal() -> void:
	var profile := _profile()
	var config := _config()
	profile.cleared_stages.append(config.stages[0])
	RunDirector.start_tower(profile, config)
	profile.run.floor_number = 10
	RunDirector.apply_result(profile, config, _finish(profile, config, true))
	var data := profile.run.to_dict()
	data["boss_offer"] = [{"uid": "", "path": "res://data/boons/deleted_since.tres"}]
	var loaded := RunState.from_dict(data)
	assert_true(loaded.awaiting_choice(), "the boss floor isn't replayed")
	assert_eq(loaded.boss_offer.size(), 0)
	profile.run = loaded
	RunDirector.apply_boss_choice(profile, RunDirector.HEAL, true)
	assert_false(profile.run.awaiting_choice())
	assert_eq(profile.run.floor_number, 11)


func test_duplicate_boons_count_once() -> void:
	var config := _config().duplicate() as TowerConfig
	var boon := config.boons.filter(func(b: BoonData) -> bool: return b.tier == 1)[0] as BoonData
	config.boons = [boon, boon, boon] as Array[BoonData]
	assert_eq(RunDirector.offer(config, 10), [boon] as Array[BoonData], "no endless search for a second one")
	assert_true(" ".join(config.get_validation_errors()).contains("fewer than 3 boons in tier 1"))


func test_a_malformed_run_save_loads_with_defaults() -> void:
	var run := RunState.from_dict({"mode": "x", "floor": [1], "start_floor": {}, "hero_hp": [3, "a", null]})
	assert_eq([run.mode, run.floor_number, run.start_floor], [RunState.Mode.TOWER, 1, 1])
	assert_eq(run.hero_hp, [3, -1, -1] as Array[int])


func test_a_saved_run_is_dropped_when_its_party_cant_be_restored() -> void:
	var roster := load(ROSTER) as Roster
	var profile := Profile.create(roster)
	RunDirector.start_tower(profile, _config())
	profile.run.hero_hp.assign([12, 30, 25])
	var data := profile.to_dict()
	assert_true(Profile.from_dict(data, roster).run != null, "resumes as saved")
	var knight: Variant = data["party"][0]
	data["party"] = [{"uid": "", "path": "res://data/heroes/gone.tres"}, data["party"][1], data["party"][2]]
	assert_eq(Profile.from_dict(data, roster).run, null, "the HP would land on the wrong heroes")
	data["party"] = [data["party"][1], knight]  # An older 2-hero party: the Ranger joins.
	assert_eq(Profile.from_dict(data, roster).run, null)
