class_name TurnTimeline
extends HBoxContainer
## The next turns as chips (name and HP bar), the acting unit first, plus the button that
## opens the full order. Hovering a chip and clicking it are reported as signals up.

signal chip_hovered(unit_id: int)
signal chip_unhovered
signal chip_pressed(unit_id: int)
signal order_button_pressed

const MAX_CHIPS := 5
const PLAYER_TINT := Color(0.7, 0.85, 1.0)
const ENEMY_TINT := Color(1.0, 0.72, 0.7)
const CHIP_WIDTH := 104

## Whether the mouse is over a chip (a rebuilt chip never reports mouse_exited).
var _chip_hovered := false

@onready var _chips: HBoxContainer = %Chips
@onready var _order_button: Button = %OrderButton


func _ready() -> void:
	_order_button.pressed.connect(order_button_pressed.emit)
	_order_button.text = tr("All (%s)") % SettingsApplier.key_text(&"show_order")


## The first MAX_CHIPS units of `units` (in acting order).
func show_order(units: Array[UnitInfo]) -> void:
	if _chip_hovered:
		_chip_hovered = false
		chip_unhovered.emit()
	for child in _chips.get_children():
		_chips.remove_child(child)
		child.queue_free()
	for i in mini(units.size(), MAX_CHIPS):
		_chips.add_child(_make_chip(units[i], i == 0))


func _make_chip(info: UnitInfo, is_current: bool) -> PanelContainer:
	var chip := PanelContainer.new()
	chip.name = "Chip"
	chip.theme_type_variation = &"ChipActive" if is_current else &"Chip"
	chip.self_modulate = PLAYER_TINT if info.is_player else ENEMY_TINT
	chip.custom_minimum_size = Vector2(CHIP_WIDTH, 0)
	chip.mouse_filter = Control.MOUSE_FILTER_STOP
	var rows := VBoxContainer.new()
	rows.name = "Rows"
	rows.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rows.add_theme_constant_override("separation", 2)
	var name_label := Label.new()
	name_label.name = "NameLabel"
	name_label.theme_type_variation = &"SmallLabel"
	name_label.text = info.display_name
	name_label.clip_text = true
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bar := ProgressBar.new()
	bar.name = "HpBar"
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, 8)
	bar.max_value = info.max_hp
	bar.value = info.hp
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rows.add_child(name_label)
	rows.add_child(bar)
	chip.add_child(rows)
	var unit_id := info.unit_id
	chip.mouse_entered.connect(func() -> void:
		_chip_hovered = true
		chip_hovered.emit(unit_id))
	chip.mouse_exited.connect(func() -> void:
		_chip_hovered = false
		chip_unhovered.emit())
	chip.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			chip_pressed.emit(unit_id))
	return chip
