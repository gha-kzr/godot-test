class_name HeroPanel
extends VBoxContainer
## The selected hero: name and level, XP, stats, spells (click one for its description) and
## the six rune slots (click a filled one to unequip it). Reads the profile; the slot click
## is reported as a signal up.

signal unequip_requested(slot: int)

@onready var _title: Label = %HeroTitle
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
	_title.text = "%s — level %d" % [record.hero.display_name(), record.level]
	var next := profile.roster.config.xp_for_next(record.level)
	var from := profile.roster.config.xp_thresholds[record.level - 1]
	_xp_bar.max_value = maxi(1, next - from) if next >= 0 else 1
	_xp_bar.value = record.xp - from if next >= 0 else 1
	_xp_label.text = "XP %d / %d" % [record.xp, next] if next >= 0 else "XP %d (max level)" % record.xp
	var lines: Array[String] = [
		"HP %d   AP %d   MP %d   Initiative %d" % [stats.max_hp(), stats.max_ap(), stats.max_mp(), stats.initiative()],
		"Power %+d%%" % stats.power(),
	]
	var resistances: Array[String] = []
	for type in stats.resistance_types():
		var value := stats.resistance_percent(type)
		if value != 0:
			resistances.append("%s %+d%%" % [type.display_name, value])
	if not resistances.is_empty():
		lines.append("Resistance: " + ", ".join(resistances))
	_stats.text = "\n".join(lines)
	_show_spells(record)
	var reward := record.hero.reward_for(record.level + 1)
	_next_reward.visible = reward != null and next >= 0
	_next_reward.text = "Next level: " + reward.describe() if _next_reward.visible else ""
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
			_spell_info.text = "%s (%d AP): %s" % [spell.display_name, spell.ap_cost, Hud.spell_description(spell)])
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
			button.tooltip_text = "%s %s: %s. Click to unequip." % [rune.rarity_name(), rune.display_name, rune.describe()]
			button.pressed.connect(unequip_requested.emit.bind(slot))
		_rune_slots.add_child(button)


## The hero as it would enter a battle, to read its stats with the battle rules' own
## accessors (the same numbers the fight will use).
static func _battle_view(record: HeroRecord) -> UnitState:
	var unit := UnitState.new(0, record.battle_unit_data(), UnitState.Team.PLAYER, Vector2i.ZERO)
	unit.permanent_modifiers = record.modifiers()
	return unit
