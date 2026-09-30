class_name PartyScreen
extends Control
## The hub between runs: the party, each hero's level, XP, stats, spells and 6 rune slots,
## the shared rune stash, what the last run brought, and where to fight next (the tower
## from an unlocked starting floor, a stage, or the saved run). Reads the profile to
## display it; choices go up as signals and the Game root applies them (then calls
## show_profile). First version, to be revamped in milestone 5.

signal tower_pressed(start_floor: int)
signal stage_pressed(stage_index: int)
signal continue_pressed
signal abandon_pressed
signal equip_requested(hero_index: int, stash_index: int)
signal unequip_requested(hero_index: int, slot: int)

const LOCKED_TEXT := "%s (locked)"

## The hero whose details are shown (a roster index).
var selected_hero := 0
var _profile: Profile
var _tower: TowerConfig

@onready var _summary: Label = %Summary
@onready var _hub: VBoxContainer = %Hub
@onready var _hero_list: VBoxContainer = %HeroList
@onready var _details: VBoxContainer = %Details
@onready var _rune_slots: GridContainer = %RuneSlots
@onready var _stash: VBoxContainer = %Stash


## `summary`: what the last run brought ("" for none); `message`: e.g. an equip error;
## `tower`: the tower and stages to offer (none: no hub).
func show_profile(profile: Profile, summary := "", message := "", tower: TowerConfig = null) -> void:
	_profile = profile
	if tower != null:
		_tower = tower
	if not profile.is_unlocked(selected_hero):
		selected_hero = profile.party[0] if not profile.party.is_empty() else 0
	_summary.text = "\n".join([summary, message].filter(func(t: String) -> bool: return not t.is_empty()))
	_summary.visible = not _summary.text.is_empty()
	_show_heroes()
	_show_details()
	_show_stash()
	_show_hub()


func select_hero(hero_index: int) -> void:
	selected_hero = hero_index
	_show_heroes()
	_show_details()


func _show_heroes() -> void:
	_clear(_hero_list)
	for index in _profile.heroes.size():
		var record := _profile.heroes[index]
		var button := _button("")
		button.name = "Hero%d" % index
		if _profile.is_unlocked(index):
			var in_party := " ★" if index in _profile.party else ""
			button.text = "%s  Lv %d%s" % [record.hero.display_name(), record.level, in_party]
			button.toggle_mode = true
			button.button_pressed = index == selected_hero
			button.pressed.connect(select_hero.bind(index))
		else:
			button.text = LOCKED_TEXT % record.hero.display_name()
			button.disabled = true
		_hero_list.add_child(button)


func _show_details() -> void:
	_clear(_details)
	var record := _profile.heroes[selected_hero]
	var stats := _battle_view(record)
	_details.add_child(_label("%s — level %d" % [record.hero.display_name(), record.level], 22))
	var next := _profile.roster.config.xp_for_next(record.level)
	var xp_bar := ProgressBar.new()
	xp_bar.name = "XpBar"
	xp_bar.show_percentage = false
	xp_bar.custom_minimum_size = Vector2(0, 10)
	var from := _profile.roster.config.xp_thresholds[record.level - 1]
	xp_bar.max_value = maxi(1, next - from) if next >= 0 else 1
	xp_bar.value = record.xp - from if next >= 0 else 1
	_details.add_child(xp_bar)
	var xp_text := "XP %d / %d" % [record.xp, next] if next >= 0 else "XP %d (max level)" % record.xp
	var xp_label := _label(xp_text)
	xp_label.name = "XpLabel"
	_details.add_child(xp_label)
	var stat_lines: Array[String] = [
		"HP %d   AP %d   MP %d   Initiative %d" % [stats.max_hp(), stats.max_ap(), stats.max_mp(), stats.initiative()],
		"Power %+d%%" % stats.power(),
	]
	var resistances: Array[String] = []
	for type in stats.resistance_types():
		var value := stats.resistance_percent(type)
		if value != 0:
			resistances.append("%s %+d%%" % [type.display_name, value])
	if not resistances.is_empty():
		stat_lines.append("Resistance: " + ", ".join(resistances))
	var stats_label := _label("\n".join(stat_lines))
	stats_label.name = "Stats"
	_details.add_child(stats_label)
	var spell_names: Array[String] = []
	for spell in record.spells():
		spell_names.append(spell.display_name)
	_details.add_child(_label("Spells: " + ", ".join(spell_names)))
	var next_reward := record.hero.reward_for(record.level + 1)
	if next_reward != null and next >= 0:
		_details.add_child(_label("Next level: " + next_reward.describe()))
	_show_rune_slots(record)


func _show_rune_slots(record: HeroRecord) -> void:
	_clear(_rune_slots)
	for slot in HeroRecord.RUNE_SLOTS:
		var rune := record.runes[slot]
		var button := _button("(empty)" if rune == null else rune.display_name)
		button.name = "Slot%d" % slot
		button.custom_minimum_size = Vector2(170, 40)
		if rune == null:
			button.disabled = true
		else:
			_tint(button, rune.color())
			button.tooltip_text = "%s %s: %s. Click to unequip." % [rune.rarity_name(), rune.display_name, rune.describe()]
			button.pressed.connect(func() -> void: unequip_requested.emit(selected_hero, slot))
		_rune_slots.add_child(button)


func _show_stash() -> void:
	_clear(_stash)
	if _profile.stash.is_empty():
		_stash.add_child(_label("No runes yet: win battles to find some."))
	for index in _profile.stash.size():
		var rune := _profile.stash[index]
		var button := _button("%s — %s" % [rune.display_name, rune.describe()])
		button.name = "Stash%d" % index
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.clip_text = true  # The tooltip has the full text.
		button.custom_minimum_size.x = 1
		_tint(button, rune.color())
		button.tooltip_text = "%s: %s.\n%s rune%s. Click to equip on the selected hero." % [
				rune.display_name, rune.describe(), rune.rarity_name(), " (one per hero)" if rune.is_unique() else ""]
		button.pressed.connect(func() -> void: equip_requested.emit(selected_hero, index))
		_stash.add_child(button)


func _show_hub() -> void:
	_clear(_hub)
	if _tower == null:
		return
	var run := _profile.run
	if run != null:
		var where := run.stage.display_name if run.mode == RunState.Mode.STAGE else "Tower, floor %d" % run.floor_number
		if run.awaiting_choice():
			where += " (boss reward to pick)"
		_hub.add_child(_label("Run in progress: " + where, 18))
		_hub.add_child(_row([_hub_button("ContinueButton", "Continue run", continue_pressed.emit),
				_hub_button("AbandonButton", "Abandon run", abandon_pressed.emit)]))
		return
	var cap := _profile.tower_cap(_tower)
	var best := "best floor %d" % _profile.best_depth if _profile.best_depth > 0 else "not climbed yet"
	_hub.add_child(_label("Tower — up to floor %d, %s" % [cap, best], 18))
	var floors := OptionButton.new()
	floors.name = "StartFloor"
	floors.focus_mode = Control.FOCUS_NONE
	floors.custom_minimum_size = Vector2(180, 44)
	for start in _profile.start_floors(_tower):
		floors.add_item("From floor %d" % start, start)
	floors.select(floors.item_count - 1)
	var climb := _hub_button("TowerButton", "Climb the tower",
			func() -> void: tower_pressed.emit(floors.get_selected_id()))
	_hub.add_child(_row([floors, climb]))
	_hub.add_child(_label("Stages", 18))
	var stages: Array[Control] = []
	for index in _tower.stages.size():
		var stage := _tower.stages[index]
		var cleared := stage in _profile.cleared_stages
		var button := _hub_button("Stage%d" % index, stage.display_name + (" ✓" if cleared else ""),
				stage_pressed.emit.bind(index))
		if not _profile.is_stage_available(_tower, stage):
			button.text = LOCKED_TEXT % stage.display_name
			button.disabled = true
			button.tooltip_text = "Clear the previous stage first."
		else:
			button.tooltip_text = "One battle. Clearing it lets the tower go up to floor %d and start at floor %d." % [
					stage.unlocks_cap, stage.unlocks_start_floor]
		stages.append(button)
	_hub.add_child(_row(stages))


func _hub_button(node_name: String, text: String, on_pressed: Callable) -> Button:
	var button := _button(text)
	button.name = node_name
	button.custom_minimum_size = Vector2(200, 44)
	button.pressed.connect(on_pressed)
	return button


func _row(controls: Array) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	for control: Control in controls:
		row.add_child(control)
	return row


## The hero as it would enter a battle, to read its stats with the battle rules' own
## accessors (the same numbers the fight will use).
func _battle_view(record: HeroRecord) -> UnitState:
	var unit := UnitState.new(0, record.battle_unit_data(), UnitState.Team.PLAYER, Vector2i.ZERO)
	unit.permanent_modifiers = record.modifiers()
	return unit


## Colors a button's background (a rune's rarity), keeping the theme's shape.
static func _tint(button: Button, color: Color) -> void:
	for state in ["normal", "hover", "pressed", "hover_pressed"]:
		var box := button.get_theme_stylebox(state).duplicate() as StyleBox
		if box is StyleBoxFlat:
			(box as StyleBoxFlat).bg_color = color.lightened(0.15) if state == "hover" else color
		button.add_theme_stylebox_override(state, box)


func _button(text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	return button


func _label(text: String, font_size := 0) -> Label:
	var label := Label.new()
	label.text = text
	if font_size > 0:
		label.add_theme_font_size_override("font_size", font_size)
	return label


## Removes children now and frees them at the end of the frame (a button may be rebuilt
## from inside its own pressed signal).
func _clear(parent: Node) -> void:
	for child in parent.get_children():
		parent.remove_child(child)
		child.queue_free()
