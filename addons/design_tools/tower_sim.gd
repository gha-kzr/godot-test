@tool
class_name TowerSim
extends RefCounted
## Plays whole tower runs AI vs AI through RunDirector (HP carry-over, boons, sudden death,
## rewards), to tune the floor bands: where runs end and which floors kill. Found runes
## are equipped automatically; the first boon is always picked. Rules only (no nodes), so
## it runs on a worker thread like the balance lab; give it copies (see snapshot()).

## A battle stops after this many actions (a stuck AI), counted as a loss.
const MAX_ACTIONS := 3000


class Result:
	var start_floor := 1
	var runs := 0
	var cleared := 0  ## Runs that cleared the tower's cap.
	var depths: Array[int] = []  ## The last floor each run cleared.
	var plays: Dictionary[int, int] = {}
	var losses: Dictionary[int, int] = {}
	var cancelled := false

	func summary() -> PackedStringArray:
		var lines := PackedStringArray()
		var total := 0
		for depth in depths:
			total += depth
		lines.append("%d runs from floor %d%s: cleared the cap %d times; depth %.1f on average (%d to %d)" % [
				runs, start_floor, " (cancelled)" if cancelled else "", cleared, float(total) / maxi(1, depths.size()),
				depths.min() if not depths.is_empty() else 0, depths.max() if not depths.is_empty() else 0])
		var floors := plays.keys()
		floors.sort()
		for floor_number: int in floors:
			var lost := losses.get(floor_number, 0)
			lines.append("  floor %3d: played %3d, lost %3d (%d%%)" % [floor_number, plays[floor_number], lost,
					roundi(100.0 * lost / plays[floor_number])])
		return lines


## `runs` runs from `start_floor` with heroes at `level`. `keep_progress`: one profile
## across the runs (levels, runes: a player's sessions); otherwise each run starts fresh.
static func run(roster: Roster, config: TowerConfig, start_floor: int, level: int, runs: int, keep_progress := true,
		first_seed := 1, control: BalanceLab.RunControl = null) -> Result:
	var result := Result.new()
	result.start_floor = start_floor
	var profile: Profile
	var seed := first_seed
	for i in runs:
		if control != null and control.is_cancelled():
			result.cancelled = true
			break
		if profile == null or not keep_progress:
			profile = _profile(roster, config, start_floor, level)
		var error := RunDirector.start_tower(profile, config, start_floor)
		if not error.is_empty():
			push_error("TowerSim: " + error)
			return result
		var depth := start_floor - 1
		var plays: Dictionary[int, int] = {}
		var lost := 0
		while profile.run != null:
			var floor_number := profile.run.floor_number
			var state := _play(profile, config, seed, control)
			if state == null:  # Cancelled mid-battle: the unfinished run isn't counted.
				result.cancelled = true
				return result
			plays[floor_number] = plays.get(floor_number, 0) + 1
			var report := RunDirector.apply_result(profile, config, state)
			seed += 1
			_equip_all(profile)
			if not report.won:
				lost = floor_number
				break
			depth = floor_number
			if report.success:
				result.cleared += 1
			elif profile.run.awaiting_choice():
				RunDirector.apply_boss_choice(profile, 0 if not profile.run.boss_offer.is_empty() else RunDirector.HEAL, true)
		result.runs += 1
		for floor_number in plays:
			result.plays[floor_number] = result.plays.get(floor_number, 0) + plays[floor_number]
		if lost > 0:
			result.losses[lost] = result.losses.get(lost, 0) + 1
		result.depths.append(depth)
		if control != null:
			control._count_battle()
	return result


## Independent copies of the inputs for a worker thread: [roster, config].
static func snapshot(roster: Roster, config: TowerConfig) -> Array:
	return [roster.duplicate_deep(Resource.DEEP_DUPLICATE_ALL), config.duplicate_deep(Resource.DEEP_DUPLICATE_ALL)]


## A profile at `level` whose cleared stages let a run start at `start_floor`.
static func _profile(roster: Roster, config: TowerConfig, start_floor: int, level: int) -> Profile:
	var profile := Profile.create(roster)
	var capped := clampi(level, 1, roster.config.xp_thresholds.size())
	for record in profile.heroes:
		record.level = capped
		record.xp = roster.config.xp_thresholds[capped - 1]
	for stage in config.stages:
		if stage.unlocks_start_floor <= start_floor:
			profile.cleared_stages.append(stage)
	return profile


## Null when `control` cancels during the battle.
static func _play(profile: Profile, config: TowerConfig, seed: int, control: BalanceLab.RunControl) -> BattleState:
	var setup := RunDirector.battle_setup(profile, config)
	var builds := setup.encounter.builds()
	var enemies: Array[UnitData] = []
	for build in builds:
		enemies.append(build.unit)
	var state := BattleState.create(setup.encounter.map.parse(), setup.units, enemies, seed, setup.modifiers, builds,
			setup.hero_hp)
	var battle := Battle.new(state)
	battle.sudden_death_round = setup.sudden_death_round
	battle.sudden_death_percent = setup.sudden_death_percent
	battle.start()
	var actions := 0
	while not state.is_over() and actions < MAX_ACTIONS:
		if control != null and actions % 50 == 0 and control.is_cancelled():
			return null
		var actor := state.turn_order.current_unit_id()
		var unit := state.units[actor]
		var ai := unit.ai_profile if unit.ai_profile != null else config.ai_profile
		if not battle.perform(EnemyAI.choose_next(state, actor, ai)).ok():
			battle.perform(BattleActions.EndTurn.new(actor))
		actions += 1
	if not state.is_over():
		for hero in state.units:
			if hero.team == UnitState.Team.PLAYER:
				hero.hp = 0  # A stuck battle counts as a loss.
	return state


## Equips stash runes on the party, round-robin, while slots are free (the stash keeps
## what doesn't fit or isn't allowed).
static func _equip_all(profile: Profile) -> void:
	var index := profile.stash.size() - 1
	while index >= 0:
		for hero in profile.party:
			if profile.heroes[hero].runes.has(null) and profile.equip(hero, index).is_empty():
				break
		index -= 1
