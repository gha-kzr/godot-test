@tool
extends VBoxContainer
## The balance lab in the Design panel: pick an encounter, the party's heroes and levels
## and a battle count; the battles run on a worker thread and the results show here.

const PreviewPanel := preload("res://addons/design_tools/previews/preview_panel.gd")
const ROSTER := "res://data/progression/roster.tres"
const DEFAULT_ENCOUNTER := "res://data/encounters/slice.tres"

var _encounter_picker: EditorResourcePicker
var _hero_pickers: Array[OptionButton] = []
var _level_spins: Array[SpinBox] = []
var _battles: SpinBox
var _run: Button
var _cancel: Button
var _results: Label
var _control: BalanceLab.RunControl
var _count := 0
var _roster: Roster
var _task := -1
var _result: BalanceLab.Result
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
	for slot in 2:
		var picker := OptionButton.new()
		if _roster != null:
			for hero in _roster.heroes:
				picker.add_item(hero.display_name())
			picker.select(mini(slot, _roster.heroes.size() - 1))
		row.add_child(picker)
		_hero_pickers.append(picker)
		var level := SpinBox.new()
		level.min_value = 1
		level.max_value = _roster.config.level_cap if _roster != null and _roster.config != null else 10
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
	var party := BalanceLab.party(heroes, levels)
	# The worker gets its own copies: the Inspector may edit the originals meanwhile.
	var input := BalanceLab.snapshot(party[0], party[1], encounter)
	_count = int(_battles.value)
	_control = BalanceLab.RunControl.new()
	var control := _control
	_run.disabled = true
	_cancel.disabled = false
	_results.text = "Running %d battles… (don't edit scripts until it's done)" % _count
	# Rules only: no nodes are touched off the main thread.
	_task = WorkerThreadPool.add_task(func() -> void:
		var result := BalanceLab.run(input[0], input[1], input[2], _count, 1, control)
		_mutex.lock()
		_result = result
		_mutex.unlock())


func _process(_delta: float) -> void:
	if _task == -1:
		return
	if not WorkerThreadPool.is_task_completed(_task):
		_results.text = "Running… %d / %d battles (don't edit scripts until it's done)" % [_control.completed(), _count]
		return
	WorkerThreadPool.wait_for_task_completion(_task)
	_task = -1
	_mutex.lock()
	var result := _result
	_result = null
	_mutex.unlock()
	_run.disabled = false
	_cancel.disabled = true
	_control = null
	_results.text = "\n".join(result.summary()) if result != null else "The run failed (see Output)."


## Cancels a running lab first, so closing the panel waits for one battle at most.
func _exit_tree() -> void:
	if _task != -1:
		_control.cancel()
		WorkerThreadPool.wait_for_task_completion(_task)
		_task = -1


func _label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	return label
