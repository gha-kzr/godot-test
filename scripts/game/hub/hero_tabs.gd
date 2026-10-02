class_name HeroTabs
extends VBoxContainer
## One toggle button per hero of the roster (name, level); locked
## heroes are disabled. Selecting one is reported as a signal up.

signal hero_selected(hero_index: int)


## A thin green HP bar above the XP bar (full outside a run, the saved HP in one).
func _hp_bar(profile: Profile, hero_index: int) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.name = "HpBar"
	bar.show_percentage = false
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var hp := RunDirector.hero_hp(profile, hero_index)
	bar.tooltip_text = tr("HP %d / %d") % [hp.x, hp.y]
	bar.max_value = hp.y
	bar.value = hp.x
	bar.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bar.offset_left = 12.0
	bar.offset_right = -12.0
	bar.offset_top = -23.0
	bar.offset_bottom = -16.0
	return bar


## A thin XP bar along the bottom of the tab.
func _xp_bar(profile: Profile, hero_index: int) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.name = "XpBar"
	bar.theme_type_variation = &"XpBar"
	bar.show_percentage = false
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.tooltip_text = profile.xp_text(hero_index)
	var progress := profile.xp_progress(hero_index)
	bar.max_value = progress.y
	bar.value = progress.x
	bar.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bar.offset_left = 12.0
	bar.offset_right = -12.0
	bar.offset_top = -13.0
	bar.offset_bottom = -6.0
	return bar


## Marks the selected tab without rebuilding (keeps keyboard focus on it).
func set_selected(selected: int) -> void:
	for child in get_children():
		var tab := child as Button
		tab.set_pressed_no_signal(tab.toggle_mode and tab.name == "Hero%d" % selected)


func show_heroes(profile: Profile, selected: int) -> void:
	HubStyle.clear_children(self)
	for index in profile.heroes.size():
		var record := profile.heroes[index]
		var tab := HubStyle.button("", "Hero%d" % index)
		tab.custom_minimum_size = Vector2(0, 66)
		if profile.is_unlocked(index):
			tab.text = tr("%s  Lv %d") % [tr(record.hero.display_name()), record.level]
			tab.toggle_mode = true
			tab.button_pressed = index == selected
			tab.pressed.connect(hero_selected.emit.bind(index))
			tab.add_child(_hp_bar(profile, index))
			tab.add_child(_xp_bar(profile, index))
		else:
			tab.text = tr("%s (locked)") % tr(record.hero.display_name())
			tab.disabled = true
		add_child(tab)
