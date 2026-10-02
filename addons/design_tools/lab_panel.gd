@tool
extends VBoxContainer
## The balance lab in the Design panel: pick an encounter, the party's heroes and levels
## and a battle count; or play whole tower runs (TowerSim) from a floor with heroes at a
## level. Either runs on a worker thread and the results show here.

const PreviewPanel := preload("res://addons/design_tools/previews/preview_panel.gd")
const ROSTER := "res://data/progression/roster.tres"
const DEFAULT_ENCOUNTER := "res://data/encounters/slice.tres"
const TOWER := "res://data/tower/tower.tres"

var _encounter_picker: EditorResourcePicker
var _hero_pickers: Array[OptionButton] = []
var _level_spins: Array[SpinBox] = []
var _battles: SpinBox
var _run: Button
var _run_tower: Button
var _tower_start: SpinBox
var _tower_level: SpinBox
var _tower_runs: SpinBox
var _keep_progress: CheckBox
var _unit := "battles"
var _cancel: Button
var _results: Label
var _control: BalanceLab.RunControl
var _count := 0
var _roster: Roster
var _task := -1
## A BalanceLab.Result or a TowerSim.Result (both have summary()).
var _result: RefCounted
var _mutex := Mutex.new()


func _init() -> void:
	name = "BalanceLab"
	var title := Label.new()
	title.text = "Balance lab"
	add_child(title)
	var row := HBoxContainer.new()
	add_child(row)
	row.add_child(_label("Encounter"))
	_encounter_picker = EditorResourcePicker.new()
	_encounter_picker.base_type = "Encounter"
	_encounter_picker.custom_minimum_size = Vector2(200, 0)
	row.add_child(_encounter_picker)
	_roster = load(ROSTER) as Roster if ResourceLoader.exists(ROSTER) else null
	for slot in 3:
		var picker := OptionButton.new()
		if _roster != null:
			for hero in _roster.heroes:
				picker.add_item(hero.display_name())
			picker.select(mini(slot, _roster.heroes.size() - 1))
		row.add_child(picker)
		_hero_pickers.append(picker)
		var level := SpinBox.new()
		level.min_value = 1
		level.max_value = _roster.config.level_cap if _roster != null and _roster.config != null else 100
		level.value = 1
		level.prefix = "Lv"
		row.add_child(level)
		_level_spins.append(level)
	_battles = SpinBox.new()
	_battles.min_value = 1
	_battles.max_value = 1000
	_battles.value = 50
	_battles.suffix = "battles"
	row.add_child(_battles)
	_run = Button.new()
	_run.text = "Run"
	_run.pressed.connect(_on_run)
	row.add_child(_run)
	_cancel = Button.new()
	_cancel.text = "Cancel"
	_cancel.disabled = true
	_cancel.pressed.connect(func() -> void:
		if _control != null:
			_control.cancel())
	row.add_child(_cancel)
	var tower_row := HBoxContainer.new()
	add_child(tower_row)
	tower_row.add_child(_label("Tower runs from"))
	_tower_start = _spin(1, 999, 1, "Floor")
	tower_row.add_child(_tower_start)
	_tower_level = _spin(1, _roster.config.level_cap if _roster != null and _roster.config != null else 100, 1, "Heroes Lv")
	tower_row.add_child(_tower_level)
	_tower_runs = _spin(1, 200, 10, "")
	_tower_runs.suffix = "runs"
	tower_row.add_child(_tower_runs)
	_keep_progress = CheckBox.new()
	_keep_progress.text = "Keep progress between runs"
	_keep_progress.button_pressed = true
	_keep_progress.tooltip_text = "On: one profile gains levels and runes across the runs, like a player. Off: every run starts from the chosen level with no runes."
	tower_row.add_child(_keep_progress)
	_run_tower = Button.new()
	_run_tower.text = "Run tower"
	_run_tower.tooltip_text = "Plays whole runs AI vs AI with %s: HP carry-over, boons, rewards; found runes are equipped automatically." % TOWER
	_run_tower.pressed.connect(_on_run_tower)
	tower_row.add_child(_run_tower)
	_results = Label.new()
	PreviewPanel.use_editor_code_font(_results)
	add_child(_results)
	if ResourceLoader.exists(DEFAULT_ENCOUNTER):
		_encounter_picker.edited_resource = load(DEFAULT_ENCOUNTER)


func _on_run() -> void:
	var encounter := _encounter_picker.edited_resource as Encounter
	if encounter == null or _roster == null:
		_results.text = "Pick an encounter (and keep %s)." % ROSTER
		return
	var errors := encounter.get_validation_errors()
	if not errors.is_empty():
		_results.text = "The encounter has errors:\n" + "\n".join(errors)
		return
	var heroes: Array[HeroData] = []
	var levels: Array[int] = []
	for slot in _hero_pickers.size():
		heroes.append(_roster.heroes[_hero_pickers[slot].selected])
		levels.append(int(_level_spins[slot].value))
	var spawns := encounter.map.parse().player_spawns.size()
	if heroes.size() > spawns:
		_results.text = "The encounter's map has %d player spawns for %d heroes." % [spawns, heroes.size()]
		return
	var party := BalanceLab.party(heroes, levels)
	# The worker gets its own copies: the Inspector may edit the originals meanwhile.
	var input := BalanceLab.snapshot(party[0], party[1], encounter)
	var count := int(_battles.value)
	_start(count, "battles", func(control: BalanceLab.RunControl) -> RefCounted:
		return BalanceLab.run(input[0], input[1], input[2], count, 1, control))


func _on_run_tower() -> void:
	var tower := load(TOWER) as TowerConfig if ResourceLoader.exists(TOWER) else null
	if tower == null or _roster == null:
		_results.text = "Needs %s and %s." % [TOWER, ROSTER]
		return
	var errors := tower.get_validation_errors()
	if not errors.is_empty():
		_results.text = "The tower has errors:\n" + "\n".join(errors)
		return
	var input := TowerSim.snapshot(_roster, tower)
	var start := int(_tower_start.value)
	if start not in _starts(input[1]):
		_results.text = "Runs start at floor 1 or a stage's unlocked floor: %s." % ", ".join(_starts(input[1]).map(str))
		return
	var level := int(_tower_level.value)
	var runs := int(_tower_runs.value)
	var keep := _keep_progress.button_pressed
	_start(runs, "runs", func(control: BalanceLab.RunControl) -> RefCounted:
		return TowerSim.run(input[0], input[1], start, level, runs, keep, 1, control))


## Runs `work` (rules only: no nodes are touched off the main thread) on a worker task.
func _start(count: int, unit: String, work: Callable) -> void:
	_count = count
	_unit = unit
	_control = BalanceLab.RunControl.new()
	var control := _control
	_run.disabled = true
	_run_tower.disabled = true
	_cancel.disabled = false
	_results.text = "Running %d %s… (don't edit scripts until it's done)" % [_count, _unit]
	_task = WorkerThreadPool.add_task(func() -> void:
		var result: RefCounted = work.call(control)
		_mutex.lock()
		_result = result
		_mutex.unlock())


func _starts(tower: TowerConfig) -> Array[int]:
	var starts: Array[int] = [1]
	for stage in tower.stages:
		starts.append(stage.unlocks_start_floor)
	return starts


func _process(_delta: float) -> void:
	if _task == -1:
		return
	if not WorkerThreadPool.is_task_completed(_task):
		_results.text = "Running… %d / %d %s (don't edit scripts until it's done)" % [_control.completed(), _count, _unit]
		return
	WorkerThreadPool.wait_for_task_completion(_task)
	_task = -1
	_mutex.lock()
	var result: RefCounted = _result
	_result = null
	_mutex.unlock()
	_run.disabled = false
	_run_tower.disabled = false
	_cancel.disabled = true
	_control = null
	_results.text = "\n".join(result.call("summary")) if result != null else "The run failed (see Output)."


## Cancels a running lab first, so closing the panel waits for one battle at most.
func _exit_tree() -> void:
	if _task != -1:
		_control.cancel()
		WorkerThreadPool.wait_for_task_completion(_task)
		_task = -1


func _spin(from: int, to: int, value: int, prefix: String) -> SpinBox:
	var spin := SpinBox.new()
	spin.min_value = from
	spin.max_value = to
	spin.value = value
	spin.prefix = prefix
	return spin


func _label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	return label
