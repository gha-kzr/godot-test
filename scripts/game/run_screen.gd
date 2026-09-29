class_name RunScreen
extends Control
## Between two floors of a run: what the last battle brought (XP, level-ups, runes), the
## party's HP, then the next step: Next floor; after a boss, a boon or a full heal, then
## Continue or Leave; at the end of the run, Back to the party. Reads the director's report;
## choices go up as signals and the Game root applies them.
## First version, to be revamped in milestone 5.

signal next_pressed
## `choice`: an index into the boss offer, or RunDirector.HEAL.
signal boss_choice_made(choice: int, keep_going: bool)
signal back_pressed

## The selected boss choice (an offer index or RunDirector.HEAL); NONE until one is picked.
const NONE := -2

var choice := NONE

@onready var _title: Label = %Title
@onready var _lines: Label = %Lines
@onready var _party: Label = %PartyHp
@onready var _choices: VBoxContainer = %Choices
@onready var _buttons: HBoxContainer = %Buttons


## `title`: e.g. "Floor 3 cleared". The next step comes from profile.run (null once the run ended).
func show_report(report: RunDirector.Report, profile: Profile, title: String) -> void:
	_title.text = title
	_lines.text = "\n".join(_report_lines(report, profile))
	_party.text = _party_hp(profile)
	_party.visible = profile.run != null
	choice = NONE
	_clear(_choices)
	_clear(_buttons)
	if report.run_over or profile.run == null:
		_buttons.add_child(_button("BackButton", "Back to the party", back_pressed.emit))
	elif profile.run.awaiting_choice():
		_show_boss_choice(profile.run.boss_offer)
	else:
		_buttons.add_child(_button("NextButton", "Floor %d" % profile.run.floor_number, next_pressed.emit))


func select_choice(value: int) -> void:
	choice = value
	for button: Button in _choices.get_children():
		button.button_pressed = button.get_meta("choice") == value
	for button: Button in _buttons.get_children():
		button.disabled = false


func _show_boss_choice(offer: Array[BoonData]) -> void:
	for index in offer.size():
		var boon := offer[index]
		_choices.add_child(_choice_button("Boon%d" % index, "%s — %s" % [boon.display_name, boon.describe()], index))
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
		lines.append("+%d XP for each hero." % report.rewards.xp)
		for level_up in report.level_ups:
			lines.append("%s reached level %d." % [profile.heroes[level_up.hero_index].hero.display_name(), level_up.to_level])
		if report.rewards.runes.is_empty():
			lines.append("No rune found.")
		else:
			lines.append("Found: %s." % ", ".join(report.rewards.runes.map(func(r: RuneData) -> String: return r.display_name)))
	lines.append_array(report.lines)
	return lines


func _party_hp(profile: Profile) -> String:
	if profile.run == null:
		return ""
	var parts: Array[String] = []
	var records := profile.party_records()
	for slot in records.size():
		var hero_max := RunDirector.max_hp(profile, slot)
		var hp: int = profile.run.hero_hp[slot] if slot < profile.run.hero_hp.size() else -1
		parts.append("%s %d / %d HP" % [records[slot].hero.display_name(), hero_max if hp < 0 else mini(hp, hero_max), hero_max])
	var boons := profile.run.boons.map(func(b: BoonData) -> String: return b.display_name)
	var text := "   ".join(parts)
	if not boons.is_empty():
		text += "\nBoons: " + ", ".join(boons)
	return text


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
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = Vector2(220, 44)
	button.pressed.connect(on_pressed)
	return button


## Removes children now and frees them at the end of the frame (a button may be rebuilt
## from inside its own pressed signal).
func _clear(parent: Node) -> void:
	for child in parent.get_children():
		parent.remove_child(child)
		child.queue_free()
