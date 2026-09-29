@tool
class_name RunDirector
extends RefCounted
## The run loop's rules, on the profile and its current run: starting a tower or stage
## run, setting up the next battle, applying a battle's result (rewards, HP carry-over,
## best depth, boss offers, success or defeat) and applying a boss choice. Pure logic; the
## screens show the Report each step returns.

## Heroes below this share of their max HP after a won battle are raised to it (fallen
## ones are revived).
const MIN_HP_SHARE := 0.25
## A boss choice: an index into the offer, or HEAL for a full heal instead of a boon.
const HEAL := -1


## Everything a battle needs for the current floor.
class Setup:
	var title := ""
	var encounter: Encounter
	var units: Array[UnitData] = []
	var modifiers: Array = []
	var hero_hp: Array = []
	var sudden_death_round := 0
	var sudden_death_percent := 10


## What a step did, for the screens.
class Report:
	var won := false
	var rewards: BattleRewards
	var level_ups: Array[Profile.LevelUp] = []
	var floor_cleared := 0
	var stage_cleared: StageData
	var boss_offer: Array[BoonData] = []
	var run_over := false
	var success := false
	var lines: Array[String] = []


## Returns an error message, or "" once the run has started.
static func start_tower(profile: Profile, config: TowerConfig, start_floor := 1) -> String:
	if start_floor not in profile.start_floors(config):
		return "Floor %d isn't unlocked as a starting floor." % start_floor
	var run := RunState.new()
	run.start_floor = start_floor
	run.floor_number = start_floor
	_fill_hp(run, profile)
	profile.run = run
	return ""


static func start_stage(profile: Profile, config: TowerConfig, stage: StageData) -> String:
	if stage not in config.stages:
		return "Unknown stage."
	if not profile.is_stage_available(config, stage):
		return "Clear the previous stage first."
	var run := RunState.new()
	run.mode = RunState.Mode.STAGE
	run.stage = stage
	run.floor_number = stage.difficulty_floor
	_fill_hp(run, profile)
	profile.run = run
	return ""


static func battle_setup(profile: Profile, config: TowerConfig) -> Setup:
	var run := profile.run
	var setup := Setup.new()
	if run.mode == RunState.Mode.STAGE:
		setup.encounter = FloorGenerator.stage_encounter(config, run.stage)
		setup.title = run.stage.display_name
	else:
		setup.encounter = FloorGenerator.encounter(config, run.floor_number)
		setup.title = "Floor %d" % run.floor_number
	setup.units = profile.battle_units()
	setup.modifiers = _party_modifiers(profile)
	setup.hero_hp.assign(run.hero_hp)
	setup.sudden_death_round = config.sudden_death_round
	setup.sudden_death_percent = config.sudden_death_percent
	return setup


## A finished battle's consequences on the profile and the run.
static func apply_result(profile: Profile, config: TowerConfig, state: BattleState) -> Report:
	var run := profile.run
	var report := Report.new()
	report.won = state.outcome() == BattleState.Outcome.PLAYER_WON
	if not report.won:
		report.run_over = true
		report.lines.append("Defeat. The run ends; heroes keep their levels and runes.")
		profile.run = null
		return report
	report.rewards = BattleRewards.compute(state)
	report.level_ups = profile.apply_rewards(report.rewards)
	# HP carries over; after the rewards (levels may raise max HP), nobody stays below 25 %.
	for slot in profile.party.size():
		var hp := state.units[slot].hp if slot < state.units.size() else 0
		var hero_max := max_hp(profile, slot)
		run.hero_hp[slot] = maxi(hp, ceili(hero_max * MIN_HP_SHARE))
	report.floor_cleared = run.floor_number
	if run.mode == RunState.Mode.STAGE:
		if run.stage not in profile.cleared_stages:
			profile.cleared_stages.append(run.stage)
		report.stage_cleared = run.stage
		report.run_over = true
		report.success = true
		report.lines.append("%s cleared! The tower now goes up to floor %d, and you can start at floor %d." % [
				run.stage.display_name, profile.tower_cap(config), run.stage.unlocks_start_floor])
		profile.run = null
		return report
	profile.best_depth = maxi(profile.best_depth, run.floor_number)
	if run.floor_number >= profile.tower_cap(config):
		report.run_over = true
		report.success = true
		report.lines.append("Floor %d cleared: the top of the tower for now. Clear the next stage to go higher." % run.floor_number)
		profile.run = null
	elif TowerConfig.is_boss_floor(run.floor_number):
		run.boss_offer = offer(config, run.floor_number)
		run.choice_pending = true
		report.boss_offer = run.boss_offer
		report.lines.append("Boss defeated! Pick a boon, or heal the party instead.")
	else:
		run.floor_number += 1
		report.lines.append("Floor %d cleared." % report.floor_cleared)
	return report


## `choice`: an index into the boss offer, or HEAL. Continue to the next floor, or leave
## (the run ends as a success).
static func apply_boss_choice(profile: Profile, choice: int, keep_going: bool) -> Report:
	var run := profile.run
	var report := Report.new()
	report.won = true
	if choice == HEAL:
		for slot in run.hero_hp.size():
			run.hero_hp[slot] = -1
		report.lines.append("The party is fully healed.")
	elif choice >= 0 and choice < run.boss_offer.size():
		var boon := run.boss_offer[choice]
		run.boons.append(boon)
		report.lines.append("%s: %s for the rest of the run." % [boon.display_name, boon.describe()])
	run.boss_offer.clear()
	run.choice_pending = false
	if keep_going:
		run.floor_number += 1
	else:
		report.run_over = true
		report.success = true
		report.lines.append("You leave the tower after floor %d." % run.floor_number)
		profile.run = null
	return report


## The boons a boss floor offers: drawn from its tier, seeded by the floor (the same offer
## for everyone).
static func offer(config: TowerConfig, boss_floor: int) -> Array[BoonData]:
	var tier := config.boon_tier(boss_floor)
	var pool: Array[BoonData] = []
	for boon in config.boons:
		if boon != null and boon.tier == tier and boon not in pool:
			pool.append(boon)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([config.seed_salt, "boons", boss_floor])
	var picked: Array[BoonData] = []
	var size := mini(config.boon_offer_size, pool.size())
	while picked.size() < size:
		picked.append(pool.pop_at(rng.randi_range(0, pool.size() - 1)))
	return picked


## Each party hero's permanent modifiers (levels, runes) plus the run's boons.
static func _party_modifiers(profile: Profile) -> Array:
	var modifiers := profile.battle_modifiers()
	if profile.run != null:
		for list: Array in modifiers:
			for boon in profile.run.boons:
				list.append_array(boon.modifiers)
	return modifiers


## A party hero's max HP with its levels, runes and the run's boons.
static func max_hp(profile: Profile, slot: int) -> int:
	var record := profile.party_records()[slot]
	var unit := UnitState.new(0, record.battle_unit_data(), UnitState.Team.PLAYER, Vector2i.ZERO)
	unit.permanent_modifiers.assign(_party_modifiers(profile)[slot])
	return unit.max_hp()


static func _fill_hp(run: RunState, profile: Profile) -> void:
	run.hero_hp.clear()
	for slot in profile.party.size():
		run.hero_hp.append(-1)
