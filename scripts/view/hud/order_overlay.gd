class_name OrderOverlay
extends Control
## The full turn order over the board: every unit, both teams, with level, HP and statuses.
## Opened by Tab or the timeline's button; closed by Tab, Esc (the controller asks) or a
## click outside the panel.

signal opened
signal closed
## A row was clicked: the overlay closes and the camera should go to this unit.
signal unit_pressed(unit_id: int)

var _units: Array[UnitInfo] = []

@onready var _rows: VBoxContainer = %Rows
@onready var _dim: ColorRect = %Dim
@onready var _hint: Label = %Hint


func _ready() -> void:
	_hint.text = tr("%s or Esc to close") % SettingsApplier.key_text(&"show_order")
	hide()
	_dim.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed \
				and event.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]:
			close())


## Rebuilds the rows: `units` in acting order, the acting unit first.
func show_order(units: Array[UnitInfo]) -> void:
	_units = units
	if visible:  # Hidden: rebuilt when it opens.
		_rebuild()


func _rebuild() -> void:
	var units := _units
	for child in _rows.get_children():
		_rows.remove_child(child)
		child.queue_free()
	for i in units.size():
		_rows.add_child(_make_row(units[i], i == 0))


func is_open() -> bool:
	return visible


func open() -> void:
	_rebuild()
	show()
	opened.emit()


func close() -> void:
	if visible:
		hide()
		closed.emit()


func toggle() -> void:
	if visible:
		close()
	else:
		open()


func _make_row(info: UnitInfo, is_current: bool) -> PanelContainer:
	var row := PanelContainer.new()
	row.name = "Row"
	row.theme_type_variation = &"ChipActive" if is_current else &"Chip"
	row.self_modulate = TurnTimeline.PLAYER_TINT if info.is_player else TurnTimeline.ENEMY_TINT
	row.mouse_filter = Control.MOUSE_FILTER_STOP
	row.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	row.tooltip_text = "Click to look at this unit"
	var unit_id := info.unit_id
	row.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			close()
			unit_pressed.emit(unit_id))
	var line := HBoxContainer.new()
	line.name = "Line"
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE  # The row takes the click; a child doesn't eat it.
	line.add_theme_constant_override("separation", 12)
	var name_label := Label.new()
	name_label.name = "NameLabel"
	name_label.text = info.title_text()
	name_label.custom_minimum_size = Vector2(200, 0)
	line.add_child(name_label)
	var hp_box := VBoxContainer.new()
	hp_box.name = "HpBox"
	hp_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hp_box.custom_minimum_size = Vector2(120, 0)
	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, 10)
	bar.max_value = info.max_hp
	bar.value = info.hp
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hp_box.add_child(bar)
	var hp_label := Label.new()
	hp_label.name = "HpLabel"
	hp_label.theme_type_variation = &"SmallLabel"
	hp_label.text = tr("%d / %d HP") % [info.hp, info.max_hp]
	hp_box.add_child(hp_label)
	line.add_child(hp_box)
	var statuses := HBoxContainer.new()
	statuses.name = "Statuses"
	statuses.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for status in info.statuses:
		var icon := TextureRect.new()
		icon.texture = status.icon
		icon.modulate = status.color
		icon.tooltip_text = tr("%s, %s") % [tr(status.display_name), status.turns_text()]
		icon.mouse_filter = Control.MOUSE_FILTER_PASS  # Keeps its tooltip, and the click goes on to the row.
		icon.custom_minimum_size = Vector2(22, 22)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		statuses.add_child(icon)
		var turns := Label.new()
		turns.theme_type_variation = &"SmallLabel"
		turns.text = str(status.turns_left)
		statuses.add_child(turns)
	line.add_child(statuses)
	row.add_child(line)
	return row
