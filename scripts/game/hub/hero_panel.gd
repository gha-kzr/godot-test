class_name HeroPanel
extends VBoxContainer
## The selected hero: name and level, XP, stats, the spell loadout and the six rune slots
## (click a filled one to unequip it). Loadout: the five slots, then the known spells that
## aren't in it; click a slot (its description shows), then another slot to swap them or an
## inactive spell to put it there. Reads the profile; changes are reported as signals up.

signal unequip_requested(slot: int)
## Put `spell` (a known one) in loadout slot `slot`.
signal spell_assign_requested(slot: int, spell: SpellData)

@onready var _title: Label = %HeroTitle
@onready var _hp_bar: ProgressBar = %HpBar
@onready var _hp_label: Label = %HpLabel
@onready var _xp_bar: ProgressBar = %XpBar
@onready var _xp_label: Label = %XpLabel
@onready var _stats: Label = %Stats
@onready var _spells: Container = %Spells
@onready var _inactive_title: Label = %InactiveTitle
@onready var _inactive_spells: Container = %InactiveSpells
@onready var _spell_info: Label = %SpellInfo
@onready var _next_reward: Label = %NextReward
@onready var _rune_slots: GridContainer = %RuneSlots

## The loadout slot picked first (-1: none), for the hero shown.
var _selected_slot := -1
var _shown_hero: HeroData


func show_hero(profile: Profile, hero_index: int) -> void:
	var record := profile.heroes[hero_index]
	var stats := _battle_view(record)
	_title.text = tr("%s — level %d") % [tr(record.hero.display_name()), record.level]
	var hp := RunDirector.hero_hp(profile, hero_index)
	_hp_bar.max_value = hp.y
	_hp_bar.value = hp.x
	_hp_label.text = tr("HP %d / %d") % [hp.x, hp.y]
	var progress := profile.xp_progress(hero_index)
	_xp_bar.max_value = progress.y
	_xp_bar.value = progress.x
	_xp_label.text = profile.xp_text(hero_index)
	var lines: Array[String] = [
		tr("HP %d   AP %d   MP %d   Initiative %d") % [stats.max_hp(), stats.max_ap(), stats.max_mp(), stats.initiative()],
		tr("Power %+d%%") % stats.power(),
	]
	var resistances: Array[String] = []
	for type in stats.resistance_types():
		var value := stats.resistance_percent(type)
		if value != 0:
			resistances.append("%s %+d%%" % [tr(type.display_name), value])
	if not resistances.is_empty():
		lines.append(tr("Resistance: %s") % ", ".join(resistances))
	_stats.text = "\n".join(lines)
	_stats.tooltip_text = Glossary.tips([&"hp", &"ap", &"mp", &"initiative", &"power", &"resistance"] as Array[StringName])
	_stats.mouse_filter = Control.MOUSE_FILTER_PASS
	_show_spells(record)
	var reward := record.hero.reward_for(record.level + 1)
	_next_reward.visible = reward != null and profile.roster.config.xp_for_next(record.level) >= 0
	_next_reward.text = tr("Next level: %s") % reward.describe() if _next_reward.visible else ""
	_show_rune_slots(record)


func _show_spells(record: HeroRecord) -> void:
	if record.hero != _shown_hero:
		_selected_slot = -1
		_shown_hero = record.hero
	HubStyle.clear_children(_spells)
	HubStyle.clear_children(_inactive_spells)
	_spell_info.text = ""
	var active := record.spells()
	if _selected_slot >= active.size():
		_selected_slot = -1
	for slot in HeroRecord.LOADOUT_SLOTS:
		var spell: SpellData = active[slot] if slot < active.size() else null
		var button := HubStyle.button("%d. %s" % [slot + 1, tr("(empty)") if spell == null else tr(spell.display_name)], "Slot_Spell%d" % (slot + 1))
		if spell == null:
			button.disabled = true  # Filled by learning a spell; spells are never removed.
		else:
			_style_spell_button(button, spell)
			button.toggle_mode = true
			button.set_pressed_no_signal(slot == _selected_slot)
			button.pressed.connect(_on_slot_pressed.bind(slot, spell))
		_spells.add_child(button)
	var inactive := record.inactive_spells()
	_inactive_title.visible = not inactive.is_empty()
	for spell in inactive:
		var button := HubStyle.button(tr(spell.display_name), "Spell_%s" % spell.display_name)
		_style_spell_button(button, spell)
		button.pressed.connect(_on_inactive_pressed.bind(spell))
		_inactive_spells.add_child(button)
	if _selected_slot != -1:
		_show_spell_info(active[_selected_slot], tr("Click a spell below to put it in this slot, or another slot to swap them."))


func _style_spell_button(button: Button, spell: SpellData) -> void:
	button.icon = spell.display_icon()
	button.add_theme_constant_override("icon_max_width", 24)
	button.tooltip_text = Hud.spell_description(spell)


## A first click picks the slot (and shows its spell); a click on another slot swaps them;
## the same slot again lets go.
func _on_slot_pressed(slot: int, spell: SpellData) -> void:
	if _selected_slot == -1:
		_selected_slot = slot
		_select_slot_buttons()
		_show_spell_info(spell, tr("Click a spell below to put it in this slot, or another slot to swap them."))
	elif _selected_slot == slot:
		_selected_slot = -1
		_select_slot_buttons()
		_show_spell_info(spell)
	else:
		var target := _selected_slot
		_selected_slot = -1
		spell_assign_requested.emit(target, spell)


## With a slot picked, an inactive spell goes there; else its description shows.
func _on_inactive_pressed(spell: SpellData) -> void:
	if _selected_slot == -1:
		_show_spell_info(spell, tr("Pick a slot first, then this spell to put it there."))
		return
	var target := _selected_slot
	_selected_slot = -1
	spell_assign_requested.emit(target, spell)


func _select_slot_buttons() -> void:
	for slot in _spells.get_child_count():
		var button := _spells.get_child(slot) as Button
		if button.toggle_mode:
			button.set_pressed_no_signal(slot == _selected_slot)


func _show_spell_info(spell: SpellData, hint := "") -> void:
	var text := tr("%s (%d AP): %s") % [tr(spell.display_name), spell.ap_cost, Hud.spell_description(spell)]
	_spell_info.text = text if hint.is_empty() else "%s\n%s" % [text, hint]


func _show_rune_slots(record: HeroRecord) -> void:
	HubStyle.clear_children(_rune_slots)
	for slot in HeroRecord.RUNE_SLOTS:
		var rune := record.runes[slot]
		var button := HubStyle.button("(empty)" if rune == null else rune.display_name, "Slot%d" % slot)
		button.custom_minimum_size = Vector2(170, 44)
		if rune == null:
			button.disabled = true
		else:
			HubStyle.tint(button, rune.color())
			button.tooltip_text = tr("%s %s: %s. Click to unequip.") % [tr(rune.rarity_name()), tr(rune.display_name), rune.describe()]
			button.pressed.connect(unequip_requested.emit.bind(slot))
		_rune_slots.add_child(button)


## The hero as it would enter a battle, to read its stats with the battle rules' own
## accessors (the same numbers the fight will use).
static func _battle_view(record: HeroRecord) -> UnitState:
	var unit := UnitState.new(0, record.battle_unit_data(), UnitState.Team.PLAYER, Vector2i.ZERO)
	unit.permanent_modifiers = record.modifiers()
	return unit
