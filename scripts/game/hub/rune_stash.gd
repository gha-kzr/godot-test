class_name RuneStash
extends VBoxContainer
## The shared rune stash and the essence counter. A row per rune, on two lines: a rarity-tinted
## button (click to equip it on the selected hero), then its actions: Fuse (for a rune that has
## levels; it says what is missing: copies or essence) and Salvage. Salvage turns that row into
## "Salvage <rune> for N essence?" with Yes / No, on the same two lines so nothing below moves; Yes
## breaks the rune for good. Choices go up as signals.

signal equip_requested(stash_index: int)
signal salvage_requested(stash_index: int)
signal fuse_requested(stash_index: int)

const ROW_HEIGHT := 44.0
const ACTION_HEIGHT := 36.0

## The rune being asked about ("Salvage it?") and its row. The row is an index because several
## copies of a rune are the same resource: only the clicked one asks. When the list changes
## under the question (an equip elsewhere) it follows the nearest row holding that rune.
var _confirming: RuneData
var _confirming_index := -1
var _profile: Profile

@onready var _list: VBoxContainer = %StashList
@onready var _scroll: ScrollContainer = %StashScroll
@onready var _essence_label: Label = %EssenceLabel


func show_stash(profile: Profile) -> void:
	_profile = profile
	_essence_label.text = tr("Essence: %d") % profile.essence
	_follow_question()
	_rebuild()


## Index of the row being asked about, -1 for none.
func asking_index() -> int:
	return _confirming_index


## Focuses the row nearest `stash_index` (after a rune left the list); false when it is empty.
func focus_row(stash_index: int) -> bool:
	if _profile == null or _profile.stash.is_empty():
		return false
	var row := clampi(stash_index, 0, _profile.stash.size() - 1)
	(_list.find_child("Stash%d" % row, true, false) as Control).grab_focus()
	return true


## Keeps the question with its rune when the stash changed, or drops it when the rune is gone.
func _follow_question() -> void:
	if _confirming == null:
		return
	var stash := _profile.stash
	if _confirming_index >= 0 and _confirming_index < stash.size() and stash[_confirming_index] == _confirming:
		return
	var nearest := -1
	for index in stash.size():
		if stash[index] == _confirming and (nearest == -1 or absi(index - _confirming_index) < absi(nearest - _confirming_index)):
			nearest = index
	_confirming_index = nearest
	if nearest == -1:
		_confirming = null


func _rebuild() -> void:
	var kept_scroll := _scroll.scroll_vertical
	HubStyle.clear_children(_list)
	if _profile.stash.is_empty():
		var empty := Label.new()
		empty.theme_type_variation = &"SmallLabel"
		empty.text = "No runes yet: win battles to find some."
		_list.add_child(empty)
	for index in _profile.stash.size():
		_list.add_child(_confirm_row(index) if index == _confirming_index else _rune_row(index))
	_wire_focus()
	# The list was emptied and refilled: the scroll would fall back to the top.
	_scroll.set_deferred("scroll_vertical", kept_scroll)


## Up and down walk from rune to rune (not through each row's buttons); right reaches the row's
## buttons, left comes back.
func _wire_focus() -> void:
	var runes: Array[Button] = []
	for index in _profile.stash.size():
		var rune_button := _list.find_child("Stash%d" % index, true, false) as Button
		if rune_button != null:
			runes.append(rune_button)
	for position in runes.size():
		var rune_button := runes[position]
		var index := int(String(rune_button.name).trim_prefix("Stash"))
		var below := runes[position + 1] if position + 1 < runes.size() else null
		var above := runes[position - 1] if position > 0 else null
		if below != null:
			rune_button.focus_neighbor_bottom = rune_button.get_path_to(below)
		if above != null:
			rune_button.focus_neighbor_top = rune_button.get_path_to(above)
		var actions := _list.find_child("Actions%d" % index, true, false)
		if actions == null or actions.get_child_count() == 0:
			continue
		var first := actions.get_child(0) as Control
		rune_button.focus_neighbor_right = rune_button.get_path_to(first)
		first.focus_neighbor_left = first.get_path_to(rune_button)
		for action: Control in actions.get_children():
			action.focus_neighbor_top = action.get_path_to(rune_button)
			if below != null:
				action.focus_neighbor_bottom = action.get_path_to(below)


## The rune's button on top (its name, level and stats whole), its actions underneath.
func _rune_row(index: int) -> VBoxContainer:
	var rune := _profile.stash[index]
	var row := VBoxContainer.new()
	row.name = "Row%d" % index
	row.add_theme_constant_override("separation", 2)
	var button := HubStyle.button("%s — %s" % [rune.title(), rune.describe()], "Stash%d" % index)
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.clip_text = true  # The tooltip has the full text.
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.custom_minimum_size = Vector2(1, ROW_HEIGHT)
	HubStyle.tint(button, rune.color())
	var tooltip := tr("%s: %s.\n%s rune (one per hero). Click to equip on the selected hero.") if rune.is_unique() \
			else tr("%s: %s.\n%s rune. Click to equip on the selected hero.")
	button.tooltip_text = tooltip % [rune.title(), rune.describe(), tr(rune.rarity_name())]
	button.pressed.connect(equip_requested.emit.bind(index))
	row.add_child(button)
	var actions := HBoxContainer.new()
	actions.name = "Actions%d" % index
	actions.alignment = BoxContainer.ALIGNMENT_END
	row.add_child(actions)
	if rune.can_level() and rune.level < RuneData.MAX_LEVEL:
		actions.add_child(_fuse_button(index, rune))
	var salvage := HubStyle.button("Salvage", "Salvage%d" % index)
	salvage.custom_minimum_size = Vector2(100, ACTION_HEIGHT)
	salvage.tooltip_text = tr("Break this rune for %d essence") % rune.salvage_value()
	salvage.pressed.connect(_ask.bind(index))
	actions.add_child(salvage)
	return row


## The Fuse button says what is missing: copies, then essence; enabled when it can be done.
func _fuse_button(index: int, rune: RuneData) -> Button:
	var copies := _profile.copies_of(index)
	var error := _profile.fuse_error(index)
	var text: String
	if copies < RuneData.FUSE_COPIES:
		text = tr("Need %d (have %d)") % [RuneData.FUSE_COPIES, copies]
	elif _profile.essence < rune.fuse_cost():
		text = tr("Need %d essence") % rune.fuse_cost()
	else:
		text = tr("Fuse to level %d") % (rune.level + 1)
	var fuse := HubStyle.button(text, "Fuse%d" % index)
	fuse.custom_minimum_size = Vector2(150, ACTION_HEIGHT)
	fuse.disabled = not error.is_empty()
	fuse.tooltip_text = error if not error.is_empty() \
			else tr("Fuse %d of these into one of level %d, for %d essence.") % [RuneData.FUSE_COPIES, rune.level + 1, rune.fuse_cost()]
	fuse.pressed.connect(fuse_requested.emit.bind(index))
	return fuse


## The question, on two lines like the rune row it replaces.
func _confirm_row(index: int) -> VBoxContainer:
	var rune := _profile.stash[index]
	var row := VBoxContainer.new()
	row.name = "Row%d" % index
	row.add_theme_constant_override("separation", 2)
	var question := Label.new()
	question.name = "SalvageQuestion%d" % index
	question.text = tr("Salvage %s for %d essence?") % [rune.title(), rune.salvage_value()]
	question.theme_type_variation = &"SmallLabel"  # Two lines fit the row's height.
	question.custom_minimum_size = Vector2(1, ROW_HEIGHT)
	question.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	question.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	row.add_child(question)
	var actions := HBoxContainer.new()
	actions.name = "Actions%d" % index
	actions.alignment = BoxContainer.ALIGNMENT_END
	row.add_child(actions)
	var no := HubStyle.button("No", "SalvageNo%d" % index)
	no.custom_minimum_size = Vector2(100, ACTION_HEIGHT)
	no.pressed.connect(_cancel.bind(index))
	actions.add_child(no)
	var yes := HubStyle.button("Yes", "SalvageYes%d" % index)
	yes.custom_minimum_size = Vector2(100, ACTION_HEIGHT)
	yes.pressed.connect(_confirm.bind(index))
	actions.add_child(yes)
	return row


func _ask(index: int) -> void:
	_confirming = _profile.stash[index]
	_confirming_index = index
	_rebuild()
	(_list.find_child("SalvageNo%d" % index, true, false) as Control).grab_focus()  # The safe answer first.


func _cancel(index: int) -> void:
	_confirming = null
	_confirming_index = -1
	_rebuild()
	(_list.find_child("Salvage%d" % index, true, false) as Control).grab_focus()


func _confirm(index: int) -> void:
	_confirming = null
	_confirming_index = -1
	salvage_requested.emit(index)
