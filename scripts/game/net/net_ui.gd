class_name NetUi
extends RefCounted
## The look of the multiplayer screens: cards (a panel with a title) and hero cards.

const SIDE_COLORS: Array[Color] = [Color(0.45, 0.65, 1.0), Color(1.0, 0.5, 0.45)]
## Where the hero (and, from the front page, the name) is remembered (tests use another file).
static var player_file := "user://net_player.cfg"


## A card: a panel in the theme's chip look, with an optional title and a coloured border. Returns the box to fill.
static func card(parent: Control, title := "", tint := Color(0, 0, 0, 0), min_width := 0.0) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.theme_type_variation = &"Chip"
	panel.custom_minimum_size = Vector2(min_width, 0)
	var theme := ThemeDB.get_project_theme()
	if theme != null and theme.has_stylebox("panel", "Chip"):
		var style := theme.get_stylebox("panel", "Chip").duplicate() as StyleBoxFlat
		if style != null:
			style.content_margin_left = 14
			style.content_margin_right = 14
			style.content_margin_top = 10
			style.content_margin_bottom = 12
			if tint.a > 0.0:
				style.border_color = tint
				style.set_border_width_all(2)
				style.bg_color = style.bg_color.lerp(tint, 0.1)
			panel.add_theme_stylebox_override("panel", style)
	parent.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	panel.add_child(box)
	if not title.is_empty():
		var label := Label.new()
		label.theme_type_variation = &"PromptLabel"
		label.text = title
		if tint.a > 0.0:
			label.add_theme_color_override("font_color", tint)
		box.add_child(label)
	return box


static func note(parent: Control, text: String) -> Label:
	var label := Label.new()
	label.theme_type_variation = &"SmallLabel"
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.text = text
	parent.add_child(label)
	return label


## A selectable card for a hero: its name, what it does, its stats and its five spells.
## Pressing it calls `on_pick(hero_index)`.
static func hero_card(hero_index: int, selected: bool, on_pick: Callable) -> Button:
	var info := PvpHeroes.summary(hero_index)
	var button := Button.new()
	button.name = "Hero%d" % hero_index
	button.toggle_mode = true
	button.button_pressed = selected
	button.custom_minimum_size = Vector2(176, 150)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.focus_mode = Control.FOCUS_ALL
	button.tooltip_text = ", ".join(info["spell_names"])
	button.pressed.connect(on_pick.bind(hero_index))
	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.offset_left = 10
	box.offset_right = -10
	box.offset_top = 8
	box.offset_bottom = -8
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(box)
	var title := Label.new()
	title.theme_type_variation = &"PromptLabel"
	title.text = info["name"]
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(title)
	var role := Label.new()
	role.theme_type_variation = &"SmallLabel"
	role.text = info["role"]
	role.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(role)
	var stats := Label.new()
	stats.theme_type_variation = &"SmallLabel"
	stats.text = TranslationServer.translate("HP %d · AP %d · MP %d") % [info["hp"], info["ap"], info["mp"]]
	stats.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(stats)
	var spells := HBoxContainer.new()
	spells.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for icon: Texture2D in info["spell_icons"]:
		var rect := TextureRect.new()
		rect.texture = icon
		rect.custom_minimum_size = Vector2(26, 26)
		rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		spells.add_child(rect)
	box.add_child(spells)
	return button


## The hero this player last chose (0 the first time): the lobby starts with it.
static func saved_hero() -> int:
	var file := ConfigFile.new()
	if file.load(player_file) == OK:
		var kept: Variant = file.get_value("player", "hero", 0)
		if kept is int and kept >= 0 and kept < PvpHeroes.hero_count():
			return kept
	return 0


static func save_hero(hero_index: int) -> void:
	var file := ConfigFile.new()
	file.load(player_file)
	file.set_value("player", "hero", hero_index)
	file.save(player_file)
