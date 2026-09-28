class_name Hud
extends CanvasLayer
## Battle HUD: turn order, active unit (with its statuses), spells, a panel for the unit
## under the mouse, end turn, view toggle, turn banner and result. The controller updates
## it with show_* calls (calls down) and listens to its signals (signals up); the HUD never
## reads or changes battle state itself.
##
## Buttons never take keyboard focus, so Space can't press a focused button; spells and
## End turn have keyboard shortcuts (1-9, the end_turn action) that respect disabled state.

signal spell_selected(index: int)
signal end_turn_pressed
signal view_toggle_pressed
signal restart_pressed

const BANNER_FADE := 0.2
const BANNER_HOLD := 0.9
const PLAYER_CHIP_COLOR := Color(0.16, 0.26, 0.42, 0.9)
const ENEMY_CHIP_COLOR := Color(0.42, 0.16, 0.16, 0.9)
const CURRENT_BORDER_COLOR := Color(1.0, 0.85, 0.3)
const SPELL_KEYS: Array[Key] = [KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6, KEY_7, KEY_8, KEY_9]
const BUFFED_COLOR := Color(0.5, 1.0, 0.5)
const DEBUFFED_COLOR := Color(1.0, 0.5, 0.45)


## A status as the HUD shows it.
class StatusInfo:
	var display_name := ""
	var short_label := ""
	var color := Color.WHITE
	var turns_left := 0
	var description := ""
	var is_positive := false


## What the HUD shows about a unit. Built by the controller from the battle state.
class UnitInfo:
	var display_name := ""
	var color := Color.WHITE
	var is_player := true
	var hp := 0
	var max_hp := 0
	var ap := 0
	var max_ap := 0
	var mp := 0
	var max_mp := 0
	## Maxima without modifiers, to show buffs and debuffs.
	var base_ap := 0
	var base_mp := 0
	var statuses: Array[StatusInfo] = []
	var spells: Array[SpellData] = []

	static func from_unit(unit: UnitState) -> UnitInfo:
		var info := UnitInfo.new()
		info.display_name = unit.data.display_name
		info.color = unit.data.color
		info.is_player = unit.team == UnitState.Team.PLAYER
		info.hp = unit.hp
		info.max_hp = unit.data.max_hp
		info.ap = unit.ap
		info.max_ap = unit.max_ap()
		info.base_ap = unit.data.ap
		info.mp = unit.mp
		info.max_mp = unit.max_mp()
		info.base_mp = unit.data.mp
		for status in unit.statuses:
			var status_info := StatusInfo.new()
			status_info.display_name = status.data.display_name
			status_info.short_label = status.data.short_label
			status_info.color = status.data.color
			status_info.turns_left = status.turns_left
			status_info.description = status.data.describe()
			status_info.is_positive = status.data.is_positive
			info.statuses.append(status_info)
		info.spells = unit.data.spells
		return info


var _spell_costs: Array[int] = []
var _selected_style := _make_selected_style()
var _ap := 0
var _controls_enabled := true
var _banner_tween: Tween

@onready var _round_label: Label = %RoundLabel
@onready var _turn_order: HBoxContainer = %TurnOrder
@onready var _unit_swatch: ColorRect = %UnitSwatch
@onready var _unit_name: Label = %UnitName
@onready var _hp_bar: ProgressBar = %HpBar
@onready var _hp_label: Label = %HpLabel
@onready var _ap_label: Label = %ApLabel
@onready var _mp_label: Label = %MpLabel
@onready var _spell_bar: HBoxContainer = %SpellBar
@onready var _end_turn_button: Button = %EndTurnButton
@onready var _view_button: Button = %ViewButton
@onready var _banner: Label = %Banner
@onready var _result_panel: Control = %ResultPanel
@onready var _result_label: Label = %ResultLabel
@onready var _restart_button: Button = %RestartButton
@onready var _seed_label: Label = %SeedLabel
@onready var _status_list: VBoxContainer = %StatusList
@onready var _inspect_panel: PanelContainer = %InspectPanel
@onready var _inspect_rows: VBoxContainer = %InspectRows


func _ready() -> void:
	_end_turn_button.pressed.connect(end_turn_pressed.emit)
	_view_button.pressed.connect(view_toggle_pressed.emit)
	_restart_button.pressed.connect(restart_pressed.emit)
	var end_turn_shortcut := Shortcut.new()
	var end_turn_event := InputEventAction.new()
	end_turn_event.action = &"end_turn"
	end_turn_shortcut.events = [end_turn_event]
	_end_turn_button.shortcut = end_turn_shortcut
	_banner.modulate.a = 0.0
	_result_panel.hide()
	_inspect_panel.hide()


## Units in the order they'll act, the current one first.
func show_turn_order(units: Array[UnitInfo], round_number: int) -> void:
	_round_label.text = "Round %d" % round_number
	_clear_children(_turn_order)
	for i in units.size():
		_turn_order.add_child(_turn_chip(units[i], i == 0))


## The active unit's panel.
func show_unit(info: UnitInfo) -> void:
	_unit_swatch.color = info.color
	_unit_name.text = info.display_name
	_hp_bar.max_value = info.max_hp
	_hp_bar.value = info.hp
	_hp_label.text = "%d / %d HP" % [info.hp, info.max_hp]
	_ap_label.text = "AP %d / %d" % [info.ap, info.max_ap]
	_mp_label.text = "MP %d / %d" % [info.mp, info.max_mp]
	_ap_label.modulate = _modifier_tint(info.max_ap, info.base_ap)
	_mp_label.modulate = _modifier_tint(info.max_mp, info.base_mp)
	_fill_status_list(_status_list, info.statuses)


## The panel for the unit under the mouse: HP, AP / MP, statuses and spells.
func show_inspected(info: UnitInfo) -> void:
	_clear_children(_inspect_rows)
	var title := HBoxContainer.new()
	var swatch := ColorRect.new()
	swatch.color = info.color
	swatch.custom_minimum_size = Vector2(16, 16)
	swatch.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	title.add_child(swatch)
	var name_label := Label.new()
	name_label.text = "%s (%s)" % [info.display_name, "ally" if info.is_player else "enemy"]
	name_label.add_theme_font_size_override("font_size", 18)
	title.add_child(name_label)
	_inspect_rows.add_child(title)
	var hp_bar := ProgressBar.new()
	hp_bar.show_percentage = false
	hp_bar.custom_minimum_size = Vector2(0, 12)
	hp_bar.max_value = info.max_hp
	hp_bar.value = info.hp
	hp_bar.add_theme_stylebox_override("fill", _hp_bar.get_theme_stylebox("fill"))
	_inspect_rows.add_child(hp_bar)
	_inspect_rows.add_child(_label("%d / %d HP" % [info.hp, info.max_hp]))
	var points := HBoxContainer.new()
	points.add_theme_constant_override("separation", 24)
	var ap := _label("AP %d / %d" % [info.ap, info.max_ap])
	ap.modulate = _modifier_tint(info.max_ap, info.base_ap)
	var mp := _label("MP %d / %d" % [info.mp, info.max_mp])
	mp.modulate = _modifier_tint(info.max_mp, info.base_mp)
	points.add_child(ap)
	points.add_child(mp)
	_inspect_rows.add_child(points)
	var statuses := VBoxContainer.new()
	statuses.name = "Statuses"
	_fill_status_list(statuses, info.statuses)
	_inspect_rows.add_child(statuses)
	var spells := VBoxContainer.new()
	spells.name = "Spells"
	for spell in info.spells:
		var row := _label("%s (%d AP)" % [spell.display_name, spell.ap_cost])
		row.tooltip_text = spell_description(spell)
		row.mouse_filter = Control.MOUSE_FILTER_PASS
		spells.add_child(row)
	_inspect_rows.add_child(spells)
	_inspect_panel.show()


func hide_inspected() -> void:
	_inspect_panel.hide()


## Whether a control belongs to the (visible) inspect panel.
func is_inspect_control(control: Control) -> bool:
	return _inspect_panel.visible and (control == _inspect_panel or _inspect_panel.is_ancestor_of(control))


## One button per spell; spells costing more than `ap` are disabled.
func show_spells(spells: Array[SpellData], ap: int) -> void:
	_clear_children(_spell_bar)
	_spell_costs.clear()
	_ap = ap
	for i in spells.size():
		var spell := spells[i]
		_spell_costs.append(spell.ap_cost)
		var button := Button.new()
		button.name = "Spell%d" % (i + 1)
		button.text = "%s\n%d AP" % [spell.display_name, spell.ap_cost]
		button.tooltip_text = spell_description(spell)
		button.toggle_mode = true
		button.focus_mode = Control.FOCUS_NONE
		button.custom_minimum_size = Vector2(110, 56)
		button.add_theme_stylebox_override("pressed", _selected_style)
		button.add_theme_stylebox_override("hover_pressed", _selected_style)
		if i < SPELL_KEYS.size():
			button.shortcut = _key_shortcut(SPELL_KEYS[i])
			button.text = "%d. %s" % [i + 1, button.text]
		button.pressed.connect(spell_selected.emit.bind(i))
		_spell_bar.add_child(button)
	_refresh_buttons()


## Shows which spell is being aimed (-1 for none). Doesn't emit spell_selected.
func set_selected_spell(index: int) -> void:
	for i in _spell_bar.get_child_count():
		(_spell_bar.get_child(i) as Button).set_pressed_no_signal(i == index)


## Spells and End turn only work on the player's turn, outside animations.
func set_player_controls_enabled(enabled: bool) -> void:
	_controls_enabled = enabled
	_refresh_buttons()


func set_overhead_view(enabled: bool) -> void:
	_view_button.text = "Side view (T)" if enabled else "Top view (T)"


## Fades a short message in and out. Await it to wait until it's gone.
func show_banner(text: String) -> void:
	_banner.text = text
	if _banner_tween != null:
		_banner_tween.kill()
	_banner_tween = create_tween()
	_banner_tween.tween_property(_banner, "modulate:a", 1.0, BANNER_FADE)
	_banner_tween.tween_interval(BANNER_HOLD)
	_banner_tween.tween_property(_banner, "modulate:a", 0.0, BANNER_FADE)
	await _banner_tween.finished


## `battle_seed` is shown so a battle can be replayed (BattleController.rng_seed).
func show_result(won: bool, battle_seed := 0) -> void:
	_result_label.text = "Victory!" if won else "Defeat"
	_seed_label.text = "Battle seed %d" % battle_seed
	set_player_controls_enabled(false)
	_result_panel.show()


func hide_result() -> void:
	_result_panel.hide()


## Tooltip text for a spell, e.g. "Range 2-6, line of sight. Circle area 1. 5-7 damage."
static func spell_description(spell: SpellData) -> String:
	var parts: Array[String] = []
	var range_text := "Range %s" % EffectData.amount_text(spell.min_range, spell.max_range)
	if spell.needs_line_of_sight:
		range_text += ", line of sight"
	if spell.height_extends_range:
		range_text += ", +range from high ground"
	parts.append(range_text)
	if spell.area != null and spell.area.kind != AreaShape.Kind.SINGLE:
		parts.append("%s area %d" % [AreaShape.Kind.keys()[spell.area.kind].capitalize(), spell.area.size])
	for effect in spell.effects:
		if effect != null:
			var text := effect.full_description()
			parts.append(text.left(1).to_upper() + text.substr(1))
	return ". ".join(parts) + "."


func _fill_status_list(list: VBoxContainer, statuses: Array[StatusInfo]) -> void:
	_clear_children(list)
	for status in statuses:
		var row := HBoxContainer.new()
		row.name = "Status"
		row.tooltip_text = status.description
		row.mouse_filter = Control.MOUSE_FILTER_PASS  # Tooltips need the mouse.
		var swatch := ColorRect.new()
		swatch.color = status.color
		swatch.custom_minimum_size = Vector2(12, 12)
		swatch.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		swatch.mouse_filter = Control.MOUSE_FILTER_PASS
		row.add_child(swatch)
		var turns := "1 turn" if status.turns_left == 1 else "%d turns" % status.turns_left
		var text := _label("%s, %s" % [status.display_name, turns])
		text.mouse_filter = Control.MOUSE_FILTER_PASS
		row.add_child(text)
		list.add_child(row)


static func _modifier_tint(value: int, base: int) -> Color:
	if value > base:
		return BUFFED_COLOR
	if value < base:
		return DEBUFFED_COLOR
	return Color.WHITE


static func _label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	return label


func _refresh_buttons() -> void:
	for i in _spell_bar.get_child_count():
		(_spell_bar.get_child(i) as Button).disabled = not _controls_enabled or _spell_costs[i] > _ap
	_end_turn_button.disabled = not _controls_enabled


func _turn_chip(info: UnitInfo, is_current: bool) -> PanelContainer:
	var chip := PanelContainer.new()
	chip.name = "Chip"
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = PLAYER_CHIP_COLOR if info.is_player else ENEMY_CHIP_COLOR
	style.set_corner_radius_all(4)
	style.set_content_margin_all(6)
	if is_current:
		style.border_color = CURRENT_BORDER_COLOR
		style.set_border_width_all(2)
	chip.add_theme_stylebox_override("panel", style)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var swatch := ColorRect.new()
	swatch.color = info.color
	swatch.custom_minimum_size = Vector2(14, 14)
	swatch.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	swatch.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var label := Label.new()
	label.text = "%s %d" % [info.display_name, info.hp]
	row.add_child(swatch)
	row.add_child(label)
	chip.add_child(row)
	return chip


static func _make_selected_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.25, 0.22, 0.12)
	style.border_color = CURRENT_BORDER_COLOR
	style.set_border_width_all(2)
	style.set_corner_radius_all(3)
	style.set_content_margin_all(6)
	return style


## Removes children right away but frees them at the end of the frame: a button may be
## rebuilt from inside its own `pressed` signal.
static func _clear_children(parent: Node) -> void:
	for child in parent.get_children():
		parent.remove_child(child)
		child.queue_free()


func _key_shortcut(key: Key) -> Shortcut:
	var event := InputEventKey.new()
	event.physical_keycode = key  # Same key on AZERTY and QWERTY.
	var shortcut := Shortcut.new()
	shortcut.events = [event]
	return shortcut
