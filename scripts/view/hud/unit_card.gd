class_name UnitCard
extends PanelContainer
## A unit's card: name and level, HP, AP / MP, power and resistances, statuses and (when
## `show_spells`) its spells. Used for the active unit and, pinnable, for the inspected one.
## Takes a UnitInfo; reports the ✕ and spell hovers as signals.

signal closed
signal spell_hovered(spell: SpellData)
signal spell_unhovered

const BUFFED_COLOR := Color(0.5, 1.0, 0.5)
const DEBUFFED_COLOR := Color(1.0, 0.5, 0.45)

## Lists the unit's spells (hover one for its details).
@export var show_spells := false

@onready var _swatch: ColorRect = %Swatch
@onready var _name_label: Label = %NameLabel
@onready var _close_button: Button = %CloseButton
@onready var _hp_bar: ProgressBar = %HpBar
@onready var _hp_label: Label = %HpLabel
@onready var _ap_label: Label = %ApLabel
@onready var _mp_label: Label = %MpLabel
@onready var _combat_stats: Label = %CombatStats
@onready var _status_list: VBoxContainer = %StatusList
@onready var _spell_list: VBoxContainer = %SpellList


func _ready() -> void:
	_close_button.pressed.connect(closed.emit)
	_spell_list.visible = show_spells


func show_unit(info: UnitInfo) -> void:
	_swatch.color = info.color
	_name_label.text = info.title_text()
	_hp_bar.max_value = info.max_hp
	_hp_bar.value = info.hp
	_hp_label.text = tr("%d / %d HP") % [info.hp, info.max_hp]
	_ap_label.text = tr("AP %d / %d") % [info.ap, info.max_ap]
	_mp_label.text = tr("MP %d / %d") % [info.mp, info.max_mp]
	_ap_label.modulate = _modifier_tint(info.max_ap, info.base_ap)
	_mp_label.modulate = _modifier_tint(info.max_mp, info.base_mp)
	_combat_stats.text = info.combat_stats_text()
	_set_tooltips()
	_fill_statuses(info.statuses)
	var listed: Array[SpellData] = []
	if show_spells:
		listed = info.spells
	_fill_spells(listed)


## Hovering the numbers explains the terms.
func _set_tooltips() -> void:
	for pair: Array in [[_hp_label, &"hp"], [_ap_label, &"ap"], [_mp_label, &"mp"]]:
		var label := pair[0] as Label
		label.tooltip_text = Glossary.tip(pair[1])
		label.mouse_filter = Control.MOUSE_FILTER_PASS
	_combat_stats.tooltip_text = Glossary.tips([&"initiative", &"damage_taken", &"power", &"resistance"] as Array[StringName])
	_combat_stats.mouse_filter = Control.MOUSE_FILTER_PASS


## Shows the ✕ that unpins the card.
func set_closable(closable: bool) -> void:
	_close_button.visible = closable


func is_closable() -> bool:
	return _close_button.visible


func _fill_statuses(statuses: Array[StatusInfo]) -> void:
	_clear_children(_status_list)
	for status in statuses:
		var row := HBoxContainer.new()
		row.name = "Status"
		row.tooltip_text = status.description
		row.mouse_filter = Control.MOUSE_FILTER_PASS  # Tooltips need the mouse.
		var icon := TextureRect.new()
		icon.texture = status.icon
		icon.modulate = status.color
		icon.custom_minimum_size = Vector2(18, 18)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		icon.mouse_filter = Control.MOUSE_FILTER_PASS
		row.add_child(icon)
		var text := Label.new()
		text.theme_type_variation = &"SmallLabel"
		text.text = tr("%s, %s") % [tr(status.display_name), status.turns_text()]
		text.mouse_filter = Control.MOUSE_FILTER_PASS
		row.add_child(text)
		_status_list.add_child(row)


func _fill_spells(spells: Array[SpellData]) -> void:
	_clear_children(_spell_list)
	for spell in spells:
		var row := HBoxContainer.new()
		row.name = "Spell"
		row.mouse_filter = Control.MOUSE_FILTER_STOP
		var icon := TextureRect.new()
		icon.texture = spell.display_icon()
		icon.custom_minimum_size = Vector2(20, 20)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_PASS
		row.add_child(icon)
		var label := Label.new()
		label.theme_type_variation = &"SmallLabel"
		label.text = tr("%s (%d AP)") % [tr(spell.display_name), spell.ap_cost]
		label.mouse_filter = Control.MOUSE_FILTER_PASS
		row.add_child(label)
		row.mouse_entered.connect(spell_hovered.emit.bind(spell))
		row.mouse_exited.connect(spell_unhovered.emit)
		_spell_list.add_child(row)


static func _modifier_tint(value: int, base: int) -> Color:
	if value > base:
		return BUFFED_COLOR
	if value < base:
		return DEBUFFED_COLOR
	return Color.WHITE


## Removes children right away but frees them at the end of the frame: a control may be
## rebuilt from inside its own signal.
static func _clear_children(parent: Node) -> void:
	for child in parent.get_children():
		parent.remove_child(child)
		child.queue_free()
