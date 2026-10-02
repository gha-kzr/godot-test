class_name HeroPanel
extends VBoxContainer
## The selected hero: name and level, XP, stats, spells (click one for its description) and
## the six rune slots (click a filled one to unequip it). Reads the profile; the slot click
## is reported as a signal up.

signal unequip_requested(slot: int)

@onready var _title: Label = %HeroTitle
@onready var _hp_bar: ProgressBar = %HpBar
@onready var _hp_label: Label = %HpLabel
@onready var _xp_bar: ProgressBar = %XpBar
@onready var _xp_label: Label = %XpLabel
@onready var _stats: Label = %Stats
@onready var _spells: HBoxContainer = %Spells
@onready var _spell_info: Label = %SpellInfo
@onready var _next_reward: Label = %NextReward
@onready var _rune_slots: GridContainer = %RuneSlots


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
	HubStyle.clear_children(_spells)
	_spell_info.text = ""
	for spell in record.spells():
		var button := HubStyle.button(spell.display_name, "Spell_%s" % spell.display_name)
		button.icon = spell.display_icon()
		button.add_theme_constant_override("icon_max_width", 24)
		button.tooltip_text = Hud.spell_description(spell)
		# Hover only shows a tooltip; clicking (or Enter) shows the same text below.
		button.pressed.connect(func() -> void:
			_spell_info.text = tr("%s (%d AP): %s") % [tr(spell.display_name), spell.ap_cost, Hud.spell_description(spell)])
		_spells.add_child(button)


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
