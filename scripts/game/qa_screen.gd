class_name QaScreen
extends Screen
## Developer tools (with the QA tools setting): the floor browser (any floor's map and team,
## and Fight it), the playground (any board and units) and the profile tools. Fights go up as
## fight_requested (the Game root plays them without touching the save); profile tools go up as
## profile_action, each after a second press to confirm.

signal fight_requested(encounter: Encounter, team: QaTools.Team, title: String)
signal profile_action(action: StringName, value: int)

const MAX_FLOOR := 999
const ENEMY_ROWS := 6
## A profile tool's button asks to be pressed again within this many seconds.
const CONFIRM_TIME := 3.0
## The playground's smallest board side (0 means the floor's size).
const MIN_BOARD_SIZE := 9


## What the screen shows, kept by the Game root between visits.
class State:
	var floor_number := 1
	var hero_levels: Array[int] = [5, 5, 5]
	var rune_rarity := QaTools.NO_RUNES
	var board_source := 0  ## 0: the floor's own shape; then the typologies, in file order.
	var board_seed := 1
	var board_size := 0  ## 0: the floor band's size.
	var enemies: Array = []  ## [enemy path, level, preset index] per row; "" for none.
	var profile_value := 10
	var tab := 0


var state := State.new()
var _profile: Profile
var _tower: TowerConfig
var _typologies: Array[MapTypology] = []
var _enemies: Array[EnemyData] = []
var _floor_encounter: Encounter
var _floor_spin: SpinBox
var _floor_preview: MapPreview
var _floor_info: Label
var _board_preview: MapPreview
var _board_info: Label

@onready var _back: Button = %BackButton
@onready var _message: Label = %Message
@onready var _tabs: TabContainer = %Tabs


func _ready() -> void:
	_back.pressed.connect(back_pressed.emit)


func show_qa(qa_state: State, profile: Profile, tower: TowerConfig, message := "") -> void:
	state = qa_state
	_profile = profile
	_tower = tower
	_message.text = message
	_load_catalogs()
	for child in _tabs.get_children():
		_tabs.remove_child(child)
		child.queue_free()
	# One quick team for both fights, above the tabs.
	var team := _team_rows()
	team.name = "QuickTeam"
	_tabs.add_sibling(team)
	_tabs.get_parent().move_child(team, _tabs.get_index())
	_tabs.add_child(_floors_tab())
	_tabs.add_child(_playground_tab())
	_tabs.add_child(_profile_tab())
	_tabs.set_tab_title(0, tr("Floors"))
	_tabs.set_tab_title(1, tr("Playground"))
	_tabs.set_tab_title(2, tr("Profile"))
	_tabs.current_tab = clampi(state.tab, 0, _tabs.get_tab_count() - 1)
	_tabs.tab_changed.connect(func(index: int) -> void: state.tab = index)
	_show_floor()
	_show_board()


func _load_catalogs() -> void:
	_typologies.clear()
	for file in _sorted_files("res://data/maps/typologies"):
		_typologies.append(load("res://data/maps/typologies/" + file) as MapTypology)
	_enemies.clear()
	for file in _sorted_files("res://data/enemies"):
		_enemies.append(load("res://data/enemies/" + file) as EnemyData)
	if state.enemies.is_empty():
		state.enemies = [["res://data/enemies/brute.tres", 3, 0], ["res://data/enemies/skeleton_archer.tres", 3, 0]]


static func _sorted_files(directory: String) -> Array:
	var files := Array(ResourceLoader.list_directory(directory)).filter(func(f: String) -> bool: return f.ends_with(".tres"))
	files.sort()
	return files


# --- Floors ---

func _floors_tab() -> Control:
	var tab := HBoxContainer.new()
	tab.name = "Floors"
	tab.add_theme_constant_override("separation", 24)
	_floor_preview = MapPreview.new()
	_floor_preview.custom_minimum_size = Vector2(380, 380)
	tab.add_child(_floor_preview)
	var side := VBoxContainer.new()
	side.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tab.add_child(side)
	var row := HBoxContainer.new()
	row.add_child(_label(tr("Floor")))
	_floor_spin = _spin(1, MAX_FLOOR, state.floor_number, "FloorNumber")
	_floor_spin.value_changed.connect(func(value: float) -> void:
		state.floor_number = int(value)
		_show_floor())
	row.add_child(_floor_spin)
	row.add_child(_named(_button(tr("Previous"), func() -> void: _floor_spin.value -= 1), "PreviousFloor"))
	row.add_child(_named(_button(tr("Next"), func() -> void: _floor_spin.value += 1), "NextFloor"))
	side.add_child(row)
	_floor_info = _label("")
	_floor_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	side.add_child(_floor_info)
	side.add_child(_named(_button(tr("Fight it"), func() -> void:
		fight_requested.emit(_floor_encounter, _team(), tr("QA: floor %d") % state.floor_number)), "FightFloor"))
	return tab


func _show_floor() -> void:
	_floor_encounter = FloorGenerator.encounter(_tower, state.floor_number)
	_floor_preview.show_map(_floor_encounter.map)
	var title := tr("Floor %d") % state.floor_number
	if TowerConfig.is_boss_floor(state.floor_number):
		title = tr("Floor %d: a boss") % state.floor_number
	elif TowerConfig.is_elite_floor(state.floor_number):
		title = tr("Floor %d: an elite") % state.floor_number
	_floor_info.text = "%s\n%s" % [title, QaTools.describe(_floor_encounter)]


## The quick team: a level per hero (0: not in the team) and the runes' rarity, on one line.
func _team_rows() -> Control:
	var rows := HBoxContainer.new()
	rows.add_theme_constant_override("separation", 16)
	rows.add_child(_label(tr("Quick team (level 0: left out)")))
	var roster := _profile.roster
	for index in roster.heroes.size():
		var row := HBoxContainer.new()
		row.add_child(_label(tr(roster.heroes[index].display_name())))
		var level := _spin(0, roster.config.level_cap, state.hero_levels[index] if index < state.hero_levels.size() else 0, "HeroLevel%d" % index)
		level.value_changed.connect(func(value: float) -> void:
			while state.hero_levels.size() <= index:
				state.hero_levels.append(0)
			state.hero_levels[index] = int(value))
		row.add_child(level)
		rows.add_child(row)
	var runes := HBoxContainer.new()
	runes.add_child(_label(tr("Runes")))
	var rarity := OptionButton.new()
	rarity.name = "RuneRarity"
	# Item ids are the rarity + 1 (an id of -1 would mean "the index" to an OptionButton).
	rarity.add_item(tr("None"), QaTools.NO_RUNES + 1)
	for value in RuneData.Rarity.values():
		rarity.add_item(tr(RuneData.Rarity.keys()[value].capitalize()), value + 1)
	rarity.select(rarity.get_item_index(state.rune_rarity + 1))
	rarity.item_selected.connect(func(index: int) -> void: state.rune_rarity = rarity.get_item_id(index) - 1)
	runes.add_child(rarity)
	rows.add_child(runes)
	return rows


func _team() -> QaTools.Team:
	return QaTools.quick_team(_profile.roster, state.hero_levels, state.rune_rarity)


# --- Playground ---

func _playground_tab() -> Control:
	var tab := HBoxContainer.new()
	tab.name = "Playground"
	tab.add_theme_constant_override("separation", 24)
	var left := VBoxContainer.new()
	_board_preview = MapPreview.new()
	_board_preview.custom_minimum_size = Vector2(320, 320)
	left.add_child(_board_preview)
	_board_info = _label("")
	_board_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_board_info.custom_minimum_size = Vector2(320, 0)
	left.add_child(_board_info)
	tab.add_child(left)
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var side := VBoxContainer.new()
	side.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(side)
	tab.add_child(scroll)
	var board := HBoxContainer.new()
	board.add_child(_label(tr("Board")))
	var source := OptionButton.new()
	source.name = "BoardSource"
	source.add_item(tr("The floor's own"), 0)
	for index in _typologies.size():
		source.add_item(QaTools.kind_text(_typologies[index].kind), index + 1)
	source.select(clampi(state.board_source, 0, _typologies.size()))
	source.item_selected.connect(func(index: int) -> void:
		state.board_source = index
		_show_board())
	board.add_child(source)
	side.add_child(board)
	var numbers := HBoxContainer.new()
	numbers.add_child(_label(tr("Floor or seed")))
	var seed := _spin(1, MAX_FLOOR, state.board_seed, "BoardSeed")
	seed.value_changed.connect(func(value: float) -> void:
		state.board_seed = int(value)
		_show_board())
	numbers.add_child(seed)
	numbers.add_child(_label(tr("Size (0: the floor's)")))
	var board_size := _spin(0, FloorBand.MAX_MAP_SIZE, state.board_size, "BoardSize")
	board_size.value_changed.connect(func(value: float) -> void:
		if value > 0 and value < MIN_BOARD_SIZE:
			board_size.set_value_no_signal(MIN_BOARD_SIZE)  # Too small for a start zone and a walk.
		state.board_size = int(board_size.value)
		_show_board())
	numbers.add_child(board_size)
	side.add_child(numbers)
	side.add_child(_label(tr("Enemies (they take the board's spawns)")))
	for row_index in ENEMY_ROWS:
		side.add_child(_enemy_row(row_index))
	side.add_child(_named(_button(tr("Fight"), func() -> void:
		var encounter := _board()
		if encounter.spawns.is_empty():
			_message.text = tr("Pick at least one enemy.")
			return
		fight_requested.emit(encounter, _team(), tr("QA: playground"))), "FightPlayground"))
	return tab


func _enemy_row(row_index: int) -> Control:
	var entry: Array = state.enemies[row_index] if row_index < state.enemies.size() else ["", 1, 0]
	var row := HBoxContainer.new()
	var enemy := OptionButton.new()
	enemy.name = "Enemy%d" % row_index
	enemy.add_item(tr("(none)"), 0)
	for index in _enemies.size():
		enemy.add_item(tr(_enemies[index].display_name()), index + 1)
		if _enemies[index].resource_path == entry[0]:
			enemy.select(index + 1)
	row.add_child(enemy)
	var level := _spin(1, 99, entry[1], "EnemyLevel%d" % row_index)
	row.add_child(level)
	var preset := OptionButton.new()
	preset.name = "EnemyPreset%d" % row_index
	for label in ["Normal", "Elite", "Boss"]:
		preset.add_item(tr(label))
	preset.select(clampi(entry[2], 0, 2))
	row.add_child(preset)
	var store := func(_value: Variant = null) -> void:
		while state.enemies.size() <= row_index:
			state.enemies.append(["", 1, 0])
		var picked := enemy.get_selected_id()
		state.enemies[row_index] = [_enemies[picked - 1].resource_path if picked > 0 else "", int(level.value), preset.selected]
		_show_board()
	enemy.item_selected.connect(store)
	level.value_changed.connect(store)
	preset.item_selected.connect(store)
	return row


## The playground's encounter from the current choices.
func _board() -> Encounter:
	var picked: Array = []
	for entry: Array in state.enemies:
		if not String(entry[0]).is_empty():
			picked.append([load(entry[0]) as EnemyData, int(entry[1]), int(entry[2])])
	var typology := _typologies[state.board_source - 1] if state.board_source > 0 else null
	return QaTools.playground(_tower, state.board_seed, typology, state.board_size, picked)


func _show_board() -> void:
	if _board_preview == null:
		return
	var encounter := _board()
	_board_preview.show_map(encounter.map)
	_board_info.text = QaTools.describe(encounter)


# --- Profile ---

func _profile_tab() -> Control:
	var tab := VBoxContainer.new()
	tab.name = "Profile"
	tab.add_child(_label(tr("These change your save (press twice to confirm).")))
	var value_row := HBoxContainer.new()
	value_row.add_child(_label(tr("Value (a level or a floor)")))
	var value := _spin(1, MAX_FLOOR, state.profile_value, "ProfileValue")
	value.value_changed.connect(func(v: float) -> void: state.profile_value = int(v))
	value_row.add_child(value)
	tab.add_child(value_row)
	for entry: Array in [[&"set_levels", tr("Set every hero to this level")], [&"give_runes", tr("Give one of every rune")],
			[&"best_floor", tr("Set the best floor to this value")], [&"clear_stages", tr("Clear every stage")],
			[&"start_run", tr("Start a tower run at this floor")]]:
		tab.add_child(_confirm_button(entry[1], entry[0]))
	return tab


## A button that acts on a second press within CONFIRM_TIME.
func _confirm_button(text: String, action: StringName) -> Button:
	var button := _named(_button(text, Callable()), "Profile_" + action) as Button
	button.custom_minimum_size = Vector2(380, 40)
	button.pressed.connect(func() -> void:
		if button.has_meta("armed"):
			button.remove_meta("armed")
			button.text = text
			profile_action.emit(action, state.profile_value)
			return
		button.set_meta("armed", true)
		button.text = tr("Sure? Press again")
		get_tree().create_timer(CONFIRM_TIME).timeout.connect(func() -> void:
			if is_instance_valid(button) and button.has_meta("armed"):
				button.remove_meta("armed")
				button.text = text))
	return button


# --- Helpers ---

func _label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	return label


func _spin(low: int, high: int, value: int, node_name: String) -> SpinBox:
	var spin := SpinBox.new()
	spin.name = node_name
	spin.min_value = low
	spin.max_value = high
	spin.value = value
	return spin


func _button(text: String, on_pressed: Callable) -> Button:
	var button := Button.new()
	button.text = text
	if on_pressed.is_valid():
		button.pressed.connect(on_pressed)
	return button


## Names a node (for tests and focus), apart from its text so the extraction tool skips it.
static func _named(node: Node, node_name: String) -> Node:
	node.name = node_name
	return node
