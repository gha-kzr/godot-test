class_name RuneStash
extends VBoxContainer
## The shared rune stash: one rarity-tinted button per rune; clicking one asks to equip it
## on the selected hero (a signal up).

signal equip_requested(stash_index: int)

@onready var _list: VBoxContainer = %StashList


func show_stash(profile: Profile) -> void:
	HubStyle.clear_children(_list)
	if profile.stash.is_empty():
		var empty := Label.new()
		empty.theme_type_variation = &"SmallLabel"
		empty.text = "No runes yet: win battles to find some."
		_list.add_child(empty)
	for index in profile.stash.size():
		var rune := profile.stash[index]
		var button := HubStyle.button("%s — %s" % [rune.display_name, rune.describe()], "Stash%d" % index)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.clip_text = true  # The tooltip has the full text.
		button.custom_minimum_size = Vector2(1, 44)
		HubStyle.tint(button, rune.color())
		button.tooltip_text = "%s: %s.\n%s rune%s. Click to equip on the selected hero." % [
				rune.display_name, rune.describe(), rune.rarity_name(), " (one per hero)" if rune.is_unique() else ""]
		button.pressed.connect(equip_requested.emit.bind(index))
		_list.add_child(button)
