class_name HeroTabs
extends VBoxContainer
## One toggle button per hero of the roster (name, level, ★ when in the party); locked
## heroes are disabled. Selecting one is reported as a signal up.

signal hero_selected(hero_index: int)

const LOCKED_TEXT := "%s (locked)"


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
		tab.custom_minimum_size = Vector2(0, 48)
		if profile.is_unlocked(index):
			var in_party := " ★" if index in profile.party else ""
			tab.text = "%s  Lv %d%s" % [record.hero.display_name(), record.level, in_party]
			tab.toggle_mode = true
			tab.button_pressed = index == selected
			tab.pressed.connect(hero_selected.emit.bind(index))
		else:
			tab.text = LOCKED_TEXT % record.hero.display_name()
			tab.disabled = true
		add_child(tab)
