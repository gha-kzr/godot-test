class_name RuneStash
extends VBoxContainer
## The shared rune stash: a row per rune with a rarity-tinted button (click to equip it on the
## selected hero) and a Drop button. Drop turns that row into "Drop <rune>?" with Yes / No,
## inline; Yes asks to throw the rune away for good. Choices go up as signals.

signal equip_requested(stash_index: int)
signal drop_requested(stash_index: int)

## The rune being asked about ("Drop it?"), or null. A reference, not a row: the list can change
## under it (an equip elsewhere) and the question must stay with its rune.
var _confirming: RuneData
var _profile: Profile

@onready var _list: VBoxContainer = %StashList


func show_stash(profile: Profile) -> void:
	_profile = profile
	if _confirming != null and _confirming not in profile.stash:
		_confirming = null
	_rebuild()


## Focuses the row nearest `stash_index` (after a rune left the list); false when it is empty.
func focus_row(stash_index: int) -> bool:
	if _profile == null or _profile.stash.is_empty():
		return false
	var row := clampi(stash_index, 0, _profile.stash.size() - 1)
	(_list.find_child("Stash%d" % row, true, false) as Control).grab_focus()
	return true


func _rebuild() -> void:
	HubStyle.clear_children(_list)
	if _profile.stash.is_empty():
		var empty := Label.new()
		empty.theme_type_variation = &"SmallLabel"
		empty.text = "No runes yet: win battles to find some."
		_list.add_child(empty)
	for index in _profile.stash.size():
		var asking := _profile.stash[index] == _confirming and _profile.stash.find(_confirming) == index
		_list.add_child(_confirm_row(index) if asking else _rune_row(index))


func _rune_row(index: int) -> HBoxContainer:
	var rune := _profile.stash[index]
	var row := HBoxContainer.new()
	row.name = "Row%d" % index
	var button := HubStyle.button("%s — %s" % [tr(rune.display_name), rune.describe()], "Stash%d" % index)
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.clip_text = true  # The tooltip has the full text.
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.custom_minimum_size = Vector2(1, 44)
	HubStyle.tint(button, rune.color())
	var tooltip := tr("%s: %s.\n%s rune (one per hero). Click to equip on the selected hero.") if rune.is_unique() \
			else tr("%s: %s.\n%s rune. Click to equip on the selected hero.")
	button.tooltip_text = tooltip % [tr(rune.display_name), rune.describe(), tr(rune.rarity_name())]
	button.pressed.connect(equip_requested.emit.bind(index))
	row.add_child(button)
	var drop := HubStyle.button("Drop", "Drop%d" % index)
	drop.custom_minimum_size = Vector2(64, 44)
	drop.tooltip_text = "Throw this rune away for good"
	drop.pressed.connect(_ask.bind(index))
	row.add_child(drop)
	return row


func _confirm_row(index: int) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.name = "Row%d" % index
	var question := Label.new()
	question.name = "DropQuestion%d" % index
	question.text = tr("Drop %s?") % tr(_profile.stash[index].display_name)
	question.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	question.clip_text = true
	row.add_child(question)
	var no := HubStyle.button("No", "DropNo%d" % index)
	no.custom_minimum_size = Vector2(56, 44)
	no.pressed.connect(_cancel.bind(index))
	row.add_child(no)
	var yes := HubStyle.button("Yes", "DropYes%d" % index)
	yes.custom_minimum_size = Vector2(56, 44)
	yes.pressed.connect(_confirm.bind(index))
	row.add_child(yes)
	return row


func _ask(index: int) -> void:
	_confirming = _profile.stash[index]
	_rebuild()
	(_list.find_child("DropNo%d" % index, true, false) as Control).grab_focus()  # The safe answer first.


func _cancel(index: int) -> void:
	_confirming = null
	_rebuild()
	(_list.find_child("Drop%d" % index, true, false) as Control).grab_focus()


func _confirm(index: int) -> void:
	_confirming = null
	drop_requested.emit(index)
