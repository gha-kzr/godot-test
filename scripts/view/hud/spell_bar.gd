class_name SpellBar
extends VBoxContainer
## The active unit's spells as square icon slots (AP cost, key number), and a details panel
## at a fixed place above them that shows the spell under the mouse (name, AP, range, area,
## effects). Slots are toggle buttons; selecting is reported as a signal up.
##
## Buttons never take keyboard focus, so Space can't press a focused button; the number
## keys 1-9 are shortcuts that respect the disabled state.

signal spell_pressed(index: int)

const SPELL_KEYS: Array[Key] = [KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6, KEY_7, KEY_8, KEY_9]
const SLOT_SIZE := Vector2(64, 64)
const HEAL_TINT := Color(0.55, 1.0, 0.6)

var _spell_costs: Array[int] = []
var _ap := 0
var _locked := false

@onready var _slots: HBoxContainer = %Slots
@onready var _details: PanelContainer = %Details
@onready var _details_name: Label = %DetailsName
@onready var _details_cost: Label = %DetailsCost
@onready var _details_body: Label = %DetailsBody


func _ready() -> void:
	_details.hide()


## One slot per spell; spells costing more than `ap` are disabled.
func show_spells(spells: Array[SpellData], ap: int) -> void:
	hide_details()
	# Removed at once, freed at the end of the frame: a slot may be rebuilt from inside its own `pressed`.
	for child in _slots.get_children():
		_slots.remove_child(child)
		child.queue_free()
	_spell_costs.clear()
	_ap = ap
	for i in spells.size():
		_spell_costs.append(spells[i].ap_cost)
		_slots.add_child(_make_slot(spells[i], i))
	_refresh()


## Shows which spell is being aimed (-1 for none). Doesn't emit spell_pressed.
func set_selected(index: int) -> void:
	for i in _slots.get_child_count():
		var slot := _slots.get_child(i) as Button
		slot.set_pressed_no_signal(i == index)
		slot.theme_type_variation = &"SelectedSlotButton" if i == index else &"SlotButton"


func set_ap(ap: int) -> void:
	_ap = ap
	_refresh()


## Locked: no spell can be picked (not the player's turn, placement, animations).
func set_locked(locked: bool) -> void:
	_locked = locked
	_refresh()


func slot_count() -> int:
	return _slots.get_child_count()


func slot(index: int) -> Button:
	return _slots.get_child(index) as Button


func show_details(spell: SpellData) -> void:
	_details_name.text = spell.display_name
	_details_cost.text = "%d AP" % spell.ap_cost
	_details_body.text = "\n".join(detail_lines(spell))
	_details.show()


func hide_details() -> void:
	_details.hide()


func is_details_visible() -> bool:
	return _details.visible


## One line each for range, area and every effect, e.g. "Range 2-6, line of sight".
static func detail_lines(spell: SpellData) -> Array[String]:
	var lines: Array[String] = []
	var range_text := "Range %s" % EffectData.amount_text(spell.min_range, spell.max_range)
	if spell.needs_line_of_sight:
		range_text += ", line of sight"
	if spell.height_extends_range:
		range_text += ", +range from high ground"
	lines.append(range_text)
	if spell.area != null and spell.area.kind != AreaShape.Kind.SINGLE:
		lines.append("%s area %d" % [AreaShape.Kind.keys()[spell.area.kind].capitalize(), spell.area.size])
	for effect in spell.effects:
		if effect != null:
			var text := effect.full_description()
			lines.append(text.left(1).to_upper() + text.substr(1))
	return lines


## The icon's tint: its damage type's color, green for a heal, else white.
static func spell_tint(spell: SpellData) -> Color:
	for effect in spell.effects:
		if effect is DamageEffect and (effect as DamageEffect).damage_type != null:
			return (effect as DamageEffect).damage_type.color
		if effect is HealEffect:
			return HEAL_TINT
	return Color.WHITE


func _make_slot(spell: SpellData, index: int) -> Button:
	var button := Button.new()
	button.name = "Spell%d" % (index + 1)
	button.theme_type_variation = &"SlotButton"
	button.toggle_mode = true
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = SLOT_SIZE
	var icon := TextureRect.new()
	icon.name = "Icon"
	icon.texture = spell.display_icon()
	icon.modulate = spell_tint(spell)
	icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 10)
	icon.offset_bottom = -18.0  # Room for the AP cost under the icon.
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(icon)
	var cost := Label.new()
	cost.name = "Cost"
	cost.theme_type_variation = &"SmallLabel"
	cost.text = "%d AP" % spell.ap_cost
	cost.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT, Control.PRESET_MODE_MINSIZE, 6)
	cost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(cost)
	if index < SPELL_KEYS.size():
		var key := Label.new()
		key.name = "Key"
		key.theme_type_variation = &"SmallLabel"
		key.text = str(index + 1)
		key.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT, Control.PRESET_MODE_MINSIZE, 6)
		key.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(key)
		button.shortcut = _key_shortcut(SPELL_KEYS[index])
	button.pressed.connect(spell_pressed.emit.bind(index))
	button.mouse_entered.connect(show_details.bind(spell))
	button.mouse_exited.connect(hide_details)
	return button


func _refresh() -> void:
	for i in _slots.get_child_count():
		var slot_button := _slots.get_child(i) as Button
		slot_button.disabled = _locked or _spell_costs[i] > _ap
		(slot_button.get_node("Icon") as TextureRect).self_modulate.a = 0.4 if slot_button.disabled else 1.0


static func _key_shortcut(key: Key) -> Shortcut:
	var event := InputEventKey.new()
	event.physical_keycode = key  # Same key on AZERTY and QWERTY.
	var shortcut := Shortcut.new()
	shortcut.events = [event]
	return shortcut
