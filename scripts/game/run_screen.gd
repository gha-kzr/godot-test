class_name RunScreen
extends Screen
## Between two floors of a run: what the last battle brought (XP, level-ups, runes), the
## party's HP, then the next step: Next floor; after a boss, a boon or a full heal, then
## Continue or Leave; at the end of the run, Back to the party. Reads the director's report;
## choices go up as signals and the Game root applies them.
## Shows the tower's floor strip and the party's HP between floors; a level-up lists the
## spells it unlocks. No Esc: leaving is an explicit button.

signal next_pressed
## The player wants the hub (to change runes) between two floors.
signal party_pressed
## The tip card was dismissed.
signal hint_dismissed
## `choice`: an index into the boss offer, or RunDirector.HEAL.
signal boss_choice_made(choice: int, keep_going: bool)

## The selected boss choice (an offer index or RunDirector.HEAL); NONE until one is picked.
const NONE := -2

var choice := NONE

@onready var _title: Label = %Title
@onready var _lines: Label = %Lines
@onready var _strip: FloorStrip = %FloorStrip
@onready var _party_row: PartyHpRow = %PartyHpRow
@onready var _boons: Label = %Boons
@onready var _choices: VBoxContainer = %Choices
@onready var _buttons: HBoxContainer = %Buttons
@onready var _hint_card: HintCard = %HintCard


## Shows a dismissable tip card.
func show_hint(text: String) -> void:
	_hint_card.show_hint(text)


## `title`: e.g. "Floor 3 cleared". The next step comes from profile.run (null once the run ended).
func show_report(report: RunDirector.Report, profile: Profile, title: String) -> void:
	_title.text = title
	_lines.text = "\n".join(_report_lines(report, profile))
	var run := profile.run
	_strip.visible = run != null and run.mode == RunState.Mode.TOWER
	if _strip.visible:
		_strip.show_floors(run.floor_number)
	_party_row.visible = run != null
	_party_row.show_party(_party_infos(profile, report))
	_boons.visible = run != null and not run.boons.is_empty()
	_boons.text = tr("Boons: %s") % ", ".join(run.boons.map(func(b: BoonData) -> String: return tr(b.display_name))) if _boons.visible else ""
	choice = NONE
	_clear(_choices)
	_clear(_buttons)
	if report.run_over or profile.run == null:
		_buttons.add_child(_button("BackButton", "Back to the party", back_pressed.emit))
	elif profile.run.awaiting_choice():
		_show_boss_choice(profile.run.boss_offer)
		_buttons.add_child(_button("PartyButton", "Party", party_pressed.emit))
	else:
		_buttons.add_child(_button("NextButton", tr("Floor %d") % profile.run.floor_number, next_pressed.emit))
		_buttons.add_child(_button("PartyButton", "Party", party_pressed.emit))


func _ready() -> void:
	back_enabled = false  # Leaving the run is an explicit button.
	_hint_card.dismissed.connect(hint_dismissed.emit)


func select_choice(value: int) -> void:
	choice = value
	for button: Button in _choices.get_children():
		button.button_pressed = button.get_meta("choice") == value
	for button: Button in _buttons.get_children():
		button.disabled = false


func _show_boss_choice(offer: Array[BoonData]) -> void:
	for index in offer.size():
		var boon := offer[index]
		_choices.add_child(_choice_button("Boon%d" % index, "%s — %s" % [tr(boon.display_name), boon.describe()], index))
	_choices.add_child(_choice_button("Heal", "Full heal — every hero back to full HP", RunDirector.HEAL))
	var go_on := _button("ContinueButton", "Continue the climb", func() -> void: boss_choice_made.emit(choice, true))
	var leave := _button("LeaveButton", "Leave the tower", func() -> void: boss_choice_made.emit(choice, false))
	go_on.disabled = true
	leave.disabled = true
	_buttons.add_child(go_on)
	_buttons.add_child(leave)


func _report_lines(report: RunDirector.Report, profile: Profile) -> Array[String]:
	var lines: Array[String] = []
	if report.rewards != null:
		lines.append(tr("+%d XP for each hero.") % report.rewards.xp)
		for level_up in report.level_ups:
			var hero := profile.heroes[level_up.hero_index].hero
			var learned: Array[String] = []
			for level in range(level_up.from_level + 1, level_up.to_level + 1):
				var reward := hero.reward_for(level)
				if reward != null:
					for spell in reward.spells:
						learned.append(tr(spell.display_name))
			if learned.is_empty():
				lines.append(tr("%s reached level %d.") % [tr(hero.display_name()), level_up.to_level])
			else:
				lines.append(tr("%s reached level %d and learned %s.") % [tr(hero.display_name()), level_up.to_level, ", ".join(learned)])
		if report.rewards.runes.is_empty():
			lines.append(tr("No rune found."))
		else:
			lines.append(tr("Found: %s.") % ", ".join(report.rewards.runes.map(func(r: RuneData) -> String: return tr(r.display_name))))
	lines.append_array(report.lines)
	return lines


## One UnitInfo per hero of the run's party, for the HP chips.
func _party_infos(profile: Profile, report: RunDirector.Report) -> Array[UnitInfo]:
	var infos: Array[UnitInfo] = []
	if profile.run == null:
		return infos
	var records := profile.party_records()
	for slot in records.size():
		var info := UnitInfo.new()
		info.display_name = records[slot].hero.display_name()
		info.level = records[slot].level
		_fill_xp(info, profile, profile.party[slot], report)
		info.max_hp = RunDirector.max_hp(profile, slot)
		var hp: int = profile.run.hero_hp[slot] if slot < profile.run.hero_hp.size() else -1
		info.hp = info.max_hp if hp < 0 else mini(hp, info.max_hp)
		infos.append(info)
	return infos


## The bar and text for what this fight gave: the XP from before in gold, the gain in a lighter
## gold after it; a level-up shows a full bar and says so.
func _fill_xp(info: UnitInfo, profile: Profile, hero_index: int, report: RunDirector.Report) -> void:
	var progress := profile.xp_progress(hero_index)
	info.xp_max = progress.y
	info.xp_value = progress.x
	var gained := report.rewards.xp if report.rewards != null else 0
	var leveled := report.level_ups.any(func(up: Profile.LevelUp) -> bool: return up.hero_index == hero_index)
	if leveled:
		info.xp_value = progress.y  # Full: the level is reached (the remainder belongs to the next one).
		info.xp_text = tr("Level up! (+%d XP)") % gained
		return
	var capped := profile.roster.config.xp_for_next(profile.heroes[hero_index].level) < 0
	info.xp_gain = 0 if capped else mini(gained, progress.x)  # At the cap the bar is simply full.
	info.xp_text = profile.xp_text(hero_index) + (" (+%d)" % gained if gained > 0 else "")


func _choice_button(node_name: String, text: String, value: int) -> Button:
	var button := _button(node_name, text, select_choice.bind(value))
	button.toggle_mode = true
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.set_meta("choice", value)
	return button


func _button(node_name: String, text: String, on_pressed: Callable) -> Button:
	var button := Button.new()
	button.name = node_name
	button.text = text
	button.custom_minimum_size = Vector2(220, 44)
	button.pressed.connect(on_pressed)
	return button


## Removes children now and frees them at the end of the frame (a button may be rebuilt
## from inside its own pressed signal).
func _clear(parent: Node) -> void:
	for child in parent.get_children():
		parent.remove_child(child)
		child.queue_free()
