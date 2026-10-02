class_name PartyHpRow
extends HBoxContainer
## One chip per hero: name and level, an HP bar and "hp / max".


## `heroes`: a UnitInfo per hero (display_name, level, hp, max_hp).
func show_party(heroes: Array[UnitInfo]) -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	for info in heroes:
		add_child(_chip(info))


func _chip(info: UnitInfo) -> PanelContainer:
	var chip := PanelContainer.new()
	chip.name = "Hero"
	chip.theme_type_variation = &"Chip"
	chip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var rows := VBoxContainer.new()
	var name_label := Label.new()
	name_label.name = "NameLabel"
	name_label.text = info.title_text()
	rows.add_child(name_label)
	var bar := ProgressBar.new()
	bar.name = "HpBar"
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, 12)
	bar.max_value = info.max_hp
	bar.value = info.hp
	rows.add_child(bar)
	var hp := Label.new()
	hp.name = "HpLabel"
	hp.theme_type_variation = &"SmallLabel"
	hp.text = tr("%d / %d HP") % [info.hp, info.max_hp]
	rows.add_child(hp)
	if info.xp_max > 0:
		rows.add_child(_xp_bars(info))
		if not info.xp_text.is_empty():
			var xp_label := Label.new()
			xp_label.name = "XpLabel"
			xp_label.theme_type_variation = &"SmallLabel"
			xp_label.text = info.xp_text
			rows.add_child(xp_label)
	chip.add_child(rows)
	return chip


## Two stacked bars in one slot: the lighter one runs to the XP now, the gold one on top
## stops where the hero was before the fight.
func _xp_bars(info: UnitInfo) -> Control:
	var slot := Control.new()
	slot.name = "XpBars"
	slot.custom_minimum_size = Vector2(0, 10)
	slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var gain := _xp_bar("XpGainBar", "GainBar", info.xp_max, info.xp_value)
	var before := _xp_bar("XpBarOverlay", "XpBar", info.xp_max, info.xp_value - info.xp_gain)
	slot.add_child(gain)
	slot.add_child(before)
	return slot


func _xp_bar(variation: StringName, node_name: String, maximum: int, value: int) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.name = node_name
	bar.theme_type_variation = variation
	bar.show_percentage = false
	bar.max_value = maximum
	bar.value = value
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return bar
