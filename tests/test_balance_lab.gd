extends TestCase
## The balance lab: AI-vs-AI battles on the rules layer, tallied. One cached run serves
## the tally tests, to keep the suite fast.

const ROSTER := "res://data/progression/roster.tres"
const SLICE := "res://data/encounters/slice.tres"

static var _cached: BalanceLab.Result


func _party(level: int) -> Array:
	var roster := load(ROSTER) as Roster
	return BalanceLab.party([roster.heroes[0], roster.heroes[1]] as Array[HeroData], [level, level] as Array[int])


## 4 battles of level-3 heroes against the slice (seeds 1-4).
func _run() -> BalanceLab.Result:
	if _cached == null:
		var input := _party(3)
		_cached = BalanceLab.run(input[0], input[1], load(SLICE) as Encounter, 4)
	return _cached


func test_runs_and_tallies_battles() -> void:
	var result := _run()
	assert_eq(result.battles, 4)
	assert_eq(result.player_wins + result.enemy_wins + result.draws + result.unfinished, 4)
	assert_true(result.total_rounds >= 4)
	assert_true(result.damage_dealt["Knight"] > 0, "the Knight fought")
	assert_true(result.damage_taken.has("Brute Lv 1"))
	assert_true(result.spell_uses.get("Slash", 0) > 0)
	assert_true(result.status_damage > 0, "Poison Arrow's poison ticks are tallied apart")
	var text := "\n".join(result.summary())
	assert_true(text.begins_with("4 battles: party wins"), text)


func test_same_seeds_same_results() -> void:
	var input := _party(3)
	var again := BalanceLab.run(input[0], input[1], load(SLICE) as Encounter, 4)
	assert_eq([again.player_wins, again.total_rounds, again.damage_dealt], [_run().player_wins, _run().total_rounds, _run().damage_dealt])


func test_levels_and_presets_move_the_win_rate() -> void:
	var encounter := load(SLICE) as Encounter
	var strong := _party(10)
	var high := BalanceLab.run(strong[0], strong[1], encounter, 3).win_rate()
	var weak := _party(1)
	var low := BalanceLab.run(weak[0], weak[1], encounter, 3).win_rate()
	assert_true(high > low, "level 10 heroes win more (%.2f vs %.2f)" % [high, low])
	var bosses := encounter.duplicate_deep(Resource.DEEP_DUPLICATE_INTERNAL) as Encounter
	for spawn in bosses.spawns:
		spawn.preset = load("res://data/presets/boss.tres")
	var against_bosses := BalanceLab.run(strong[0], strong[1], bosses, 2).win_rate()
	assert_true(against_bosses < high, "bosses are harder (%.2f vs %.2f)" % [against_bosses, high])


func test_a_run_can_be_cancelled_and_reports_progress() -> void:
	var input := _party(1)
	var control := BalanceLab.RunControl.new()
	control.cancel()
	var cancelled := BalanceLab.run(input[0], input[1], load(SLICE) as Encounter, 50, 1, control)
	assert_eq(cancelled.battles, 0, "stops before the next battle")
	assert_true(cancelled.cancelled)
	assert_true("\n".join(cancelled.summary()).contains("(cancelled)"))
	var counted := BalanceLab.RunControl.new()
	BalanceLab.run(input[0], input[1], load(SLICE) as Encounter, 1, 1, counted)
	assert_eq(counted.completed(), 1)


func test_snapshots_are_independent_of_the_originals() -> void:
	var input := _party(1)
	var encounter := load(SLICE) as Encounter
	var copy := BalanceLab.snapshot(input[0], input[1], encounter)
	assert_ne(copy[2], encounter)
	assert_ne((copy[2] as Encounter).spawns[0].enemy, encounter.spawns[0].enemy, "deep: enemies copied too")
	assert_ne((copy[0][0] as UnitData).spells[0], (input[0][0] as UnitData).spells[0], "spells copied")
	assert_eq((copy[2] as Encounter).spawns[0].enemy.unit.max_hp, encounter.spawns[0].enemy.unit.max_hp)


func test_units_with_the_same_label_are_counted_apart() -> void:
	var encounter := (load(SLICE) as Encounter).duplicate_deep(Resource.DEEP_DUPLICATE_INTERNAL) as Encounter
	encounter.spawns[1].enemy = encounter.spawns[0].enemy  # Two Brutes.
	var input := _party(1)
	var result := BalanceLab.run(input[0], input[1], encounter, 1)
	assert_true(result.damage_dealt.has("Brute Lv 1 #1") and result.damage_dealt.has("Brute Lv 1 #2"), str(result.damage_dealt.keys()))


func test_runs_on_a_worker_thread() -> void:
	var input := _party(1)
	var snapshot := BalanceLab.snapshot(input[0], input[1], load(SLICE) as Encounter)
	var holder := {"result": null}
	var task := WorkerThreadPool.add_task(func() -> void:
		holder.result = BalanceLab.run(snapshot[0], snapshot[1], snapshot[2], 1))
	while not WorkerThreadPool.is_task_completed(task):
		await (Engine.get_main_loop() as SceneTree).process_frame
	WorkerThreadPool.wait_for_task_completion(task)
	assert_eq((holder.result as BalanceLab.Result).battles, 1)


func test_lab_panel_script_loads() -> void:
	var script := load("res://addons/design_tools/lab_panel.gd") as GDScript
	assert_true(script != null and script.is_tool())
