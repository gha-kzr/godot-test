class_name SpellBar
extends VBoxContainer
## The active unit's spells as square icon slots (AP cost, key number), and a details panel
## at a fixed place above them that shows the spell under the mouse (name, AP, range, area,
## effects). Slots are toggle buttons; selecting is reported as a signal up.
##
## Buttons never take keyboard focus, so Space can't press a focused button; the spell
## actions (keys 1-9 by default) are shortcuts that respect the disabled state.

signal spell_pressed(index: int)

## Spell slot i is pressed by the InputMap action "spell_<i+1>" (rebindable in the settings).
const MAX_KEYED_SLOTS := 9
const SLOT_SIZE := Vector2(64, 64)
const HEAL_TINT := Color(0.55, 1.0, 0.6)

var _spell_costs: Array[int] = []
var _cooldowns: Array[int] = []
var _ap := 0
var _locked := false

@onready var _slots: HBoxContainer = %Slots
@onready var _details: PanelContainer = %Details
@onready var _details_name: Label = %DetailsName
@onready var _details_cost: Label = %DetailsCost
@onready var _details_body: Label = %DetailsBody


func _ready() -> void:
	_details.hide()


## One slot per spell; spells costing more than `ap`, or with turns of cooldown left
## (`cooldowns`, per slot; empty: none), are disabled.
func show_spells(spells: Array[SpellData], ap: int, cooldowns: Array[int] = []) -> void:
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
	set_cooldowns(cooldowns)


## Shows which spell is being aimed (-1 for none). Doesn't emit spell_pressed.
func set_selected(index: int) -> void:
	for i in _slots.get_child_count():
		var slot := _slots.get_child(i) as Button
		slot.set_pressed_no_signal(i == index)
		slot.theme_type_variation = &"SelectedSlotButton" if i == index else &"SlotButton"


func set_ap(ap: int) -> void:
	_ap = ap
	_refresh()


## Turns of cooldown left per slot (missing slots: ready); shown on the slot.
func set_cooldowns(cooldowns: Array[int]) -> void:
	_cooldowns.assign(cooldowns)
	_cooldowns.resize(_spell_costs.size())  # New entries are 0.
	_refresh()


## The number shown on a slot waiting for its cooldown ("" when ready).
func cooldown_text(index: int) -> String:
	return (slot(index).get_node("Cooldown") as Label).text


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
	_details_cost.text = tr("%d AP") % spell.ap_cost
	_details_body.text = "\n".join(detail_lines(spell))
	_details.show()


func hide_details() -> void:
	_details.hide()


func is_details_visible() -> bool:
	return _details.visible


## One line each for range, area and every effect, e.g. "Range 2-6, line of sight". Static, so
## it translates through the TranslationServer (tr() is an instance method).
static func detail_lines(spell: SpellData) -> Array[String]:
	var lines: Array[String] = []
	var range_amount := EffectData.amount_text(spell.min_range, spell.max_range)
	var range_text: String
	if spell.needs_line_of_sight and spell.height_extends_range:
		range_text = TranslationServer.translate("Range %s, line of sight, +range from high ground")
	elif spell.needs_line_of_sight:
		range_text = TranslationServer.translate("Range %s, line of sight")
	elif spell.height_extends_range:
		range_text = TranslationServer.translate("Range %s, +range from high ground")
	else:
		range_text = TranslationServer.translate("Range %s")
	range_text = range_text % range_amount
	lines.append(range_text)
	if spell.target_unit == SpellData.TargetUnit.ENEMY:
		lines.append(TranslationServer.translate("Targets an enemy"))
	elif spell.target_unit == SpellData.TargetUnit.ALLY:
		lines.append(TranslationServer.translate("Targets an ally"))
	if spell.cooldown == 1:
		lines.append(TranslationServer.translate("Once per turn"))
	elif spell.cooldown > 1:
		lines.append(TranslationServer.translate("Every %d turns") % spell.cooldown)
	if spell.area != null and spell.area.kind != AreaShape.Kind.SINGLE:
		lines.append(TranslationServer.translate("%s area %d") % [TranslationServer.translate(AreaShape.Kind.keys()[spell.area.kind].capitalize()), spell.area.size])
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
	cost.text = tr("%d AP") % spell.ap_cost
	cost.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT, Control.PRESET_MODE_MINSIZE, 6)
	cost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(cost)
	var cooldown := Label.new()
	cooldown.name = "Cooldown"
	cooldown.theme_type_variation = &"HeaderLabel"
	cooldown.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cooldown.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	cooldown.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cooldown.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(cooldown)
	if index < MAX_KEYED_SLOTS:
		var action := StringName("spell_%d" % (index + 1))
		var key := Label.new()
		key.name = "Key"
		key.theme_type_variation = &"SmallLabel"
		key.text = SettingsApplier.key_text(action)
		key.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT, Control.PRESET_MODE_MINSIZE, 6)
		key.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(key)
		button.shortcut = _action_shortcut(action)
	button.pressed.connect(spell_pressed.emit.bind(index))
	button.mouse_entered.connect(show_details.bind(spell))
	button.mouse_exited.connect(hide_details)
	return button


func _refresh() -> void:
	for i in _slots.get_child_count():
		var slot_button := _slots.get_child(i) as Button
		var waiting := _cooldowns[i] if i < _cooldowns.size() else 0
		slot_button.disabled = _locked or _spell_costs[i] > _ap or waiting > 0
		(slot_button.get_node("Icon") as TextureRect).self_modulate.a = 0.4 if slot_button.disabled else 1.0
		(slot_button.get_node("Cooldown") as Label).text = str(waiting) if waiting > 0 else ""


static func _action_shortcut(action: StringName) -> Shortcut:
	var event := InputEventAction.new()
	event.action = action
	var shortcut := Shortcut.new()
	shortcut.events = [event]
	return shortcut
