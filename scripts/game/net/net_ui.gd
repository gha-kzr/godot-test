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


## A selectable card for a hero: its name, what it does, its stats and its five spells, a mark when it is the chosen
## one, and an (i) button that opens everything about the hero. Pressing the card calls `on_pick(hero_index)`.
static func hero_card(hero_index: int, selected: bool, on_pick: Callable) -> Button:
	var info := PvpHeroes.summary(hero_index)
	var button := Button.new()
	button.name = "Hero%d" % hero_index
	button.toggle_mode = true
	button.button_pressed = selected
	button.custom_minimum_size = Vector2(200, 150)
	button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	button.focus_mode = Control.FOCUS_ALL
	button.tooltip_text = info["description"]
	button.pressed.connect(on_pick.bind(hero_index))
	_style_choice(button, Color(1.0, 0.85, 0.4))
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
	role.clip_text = true
	role.custom_minimum_size = Vector2(150, 0)
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
	var chosen := Label.new()
	chosen.name = "Chosen"
	chosen.theme_type_variation = &"SmallLabel"
	chosen.text = TranslationServer.translate("Chosen")
	chosen.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
	chosen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chosen.visible = selected
	box.add_child(chosen)
	button.toggled.connect(func(on: bool) -> void: chosen.visible = on)
	var more := Button.new()
	more.name = "Info%d" % hero_index
	more.text = "i"
	more.tooltip_text = TranslationServer.translate("Stats and spells in detail")
	more.focus_mode = Control.FOCUS_NONE
	more.custom_minimum_size = Vector2(28, 28)
	more.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	more.offset_left = -34
	more.offset_right = -6
	more.offset_top = 6
	more.offset_bottom = 34
	more.pressed.connect(func() -> void: show_hero_info(button, hero_index))
	button.add_child(more)
	return button


## A toggle button that is clearly on or off: a plain panel with a thin border, and a thick bright one with a tinted
## fill when it is pressed (the theme's own pressed look is too close to the normal one to read at a glance).
static func _style_choice(button: Button, tint: Color) -> void:
	var states := {
		"normal": [Color(0.15, 0.16, 0.2), Color(0.32, 0.34, 0.4), 1],
		"hover": [Color(0.2, 0.22, 0.28), Color(0.55, 0.58, 0.66), 2],
		"pressed": [Color(0.15, 0.16, 0.2).lerp(tint, 0.3), tint, 3],
		"hover_pressed": [Color(0.15, 0.16, 0.2).lerp(tint, 0.38), tint, 3],
		"disabled": [Color(0.12, 0.13, 0.15), Color(0.25, 0.26, 0.3), 1],
	}
	for state: String in states:
		var style := StyleBoxFlat.new()
		style.bg_color = states[state][0]
		style.border_color = states[state][1]
		style.set_border_width_all(states[state][2])
		style.set_corner_radius_all(6)
		style.set_content_margin_all(6)
		button.add_theme_stylebox_override(state, style)
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())


## A team button in the team's colour: it fills with it when it is the player's team.
static func side_button(button: Button, side: int) -> void:
	var tint: Color = SIDE_COLORS[side]
	_style_choice(button, tint)
	button.add_theme_color_override("font_color", tint)
	button.add_theme_color_override("font_hover_color", tint.lightened(0.2))
	button.add_theme_color_override("font_pressed_color", Color.WHITE)
	button.add_theme_color_override("font_hover_pressed_color", Color.WHITE)


## The (i) popup: the hero's stats, then each spell with what it does. Closes with its button, Esc or a click outside.
static func show_hero_info(from: Control, hero_index: int) -> void:
	var host := from
	while host.get_parent() is Control:
		host = host.get_parent() as Control
	var info := PvpHeroes.details(hero_index)
	var overlay := Control.new()
	overlay.name = "HeroInfo"
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
			overlay.queue_free()
		elif event is InputEventMouseButton and event.pressed:
			overlay.queue_free())
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(dim)
	var center := CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)
	var box := card(center, info["name"], Color(1.0, 0.85, 0.4))
	box.get_parent().custom_minimum_size = Vector2(minf(560.0, maxf(280.0, host.size.x - 40.0)), 0)
	box.get_parent().mouse_filter = Control.MOUSE_FILTER_STOP
	note(box, info["role"])
	note(box, info["description"])
	note(box, TranslationServer.translate("HP %d · AP %d · MP %d") % [info["hp"], info["ap"], info["mp"]])
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(0, minf(340.0, maxf(100.0, host.size.y - 330.0)))
	box.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 10)
	scroll.add_child(list)
	for spell: Dictionary in info["spells"]:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		list.add_child(row)
		var icon := TextureRect.new()
		icon.texture = spell["icon"]
		icon.custom_minimum_size = Vector2(40, 40)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		row.add_child(icon)
		var text := VBoxContainer.new()
		text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(text)
		var name_label := Label.new()
		name_label.theme_type_variation = &"PromptLabel"
		name_label.text = TranslationServer.translate("%s  (%d AP)") % [spell["name"], spell["ap"]]
		text.add_child(name_label)
		note(text, "\n".join(spell["lines"]))
	var close := HubStyle.button("Close", "CloseInfo")
	close.pressed.connect(overlay.queue_free)
	box.add_child(close)
	host.add_child(overlay)
	overlay.focus_mode = Control.FOCUS_ALL
	overlay.grab_focus()


## The names a player gets when they have not chosen one (the front page has no name field: it is set in the lobby).
const NAMES: Array[String] = [
	"Aldric", "Brynn", "Cedric", "Dara", "Elowen", "Fenwick", "Garrick", "Hilda", "Ivo", "Jasper",
	"Kestrel", "Lyra", "Mordin", "Nyx", "Orla", "Perrin",
]


static func random_name() -> String:
	return NAMES[randi() % NAMES.size()]


## The name this player last used, or a new random one (kept, so the same browser keeps the same name until they change it).
static func saved_name() -> String:
	var file := ConfigFile.new()
	if file.load(player_file) == OK:
		var kept := str(file.get_value("player", "name", "")).strip_edges()
		if not kept.is_empty():
			return kept
	var made := random_name()
	save_name(made)
	return made


static func save_name(player_name: String) -> void:
	var file := ConfigFile.new()
	file.load(player_file)
	file.set_value("player", "name", player_name)
	file.save(player_file)


static func side_name(side: int) -> String:
	return TranslationServer.translate("Blue team") if side == 0 else TranslationServer.translate("Red team")


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
