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
	hp.text = "%d / %d HP" % [info.hp, info.max_hp]
	rows.add_child(hp)
	chip.add_child(rows)
	return chip
