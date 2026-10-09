class_name NetTopBar
extends HBoxContainer
## The round buttons in the top right corner of the lobby and the fight: the settings and, in the fight, a menu (leaving it),
## in that order from left to right. The sound button (the Game root's) moves to their left while they are shown: sound,
## settings, menu. More options can join the row.

signal menu_requested
signal settings_requested

const MENU_ICON: Texture2D = preload("res://ui/icons/hamburger.svg")
const COG_ICON: Texture2D = preload("res://ui/icons/cog.svg")
## The margin on the right (Game.OVERLAY_MARGIN_X) and from the top (Game.OVERLAY_MARGIN_Y).
const RIGHT_GAP := 24.0
const TOP := 16.0
const BUTTON_WIDTH := 48.0
const GAP := 8.0

var _menu: Button


func _init() -> void:
	name = "NetTopBar"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_constant_override("separation", int(GAP))
	anchor_left = 1.0
	anchor_right = 1.0
	anchor_top = 0.0
	anchor_bottom = 0.0
	grow_horizontal = Control.GROW_DIRECTION_BEGIN
	offset_right = -RIGHT_GAP
	offset_left = -RIGHT_GAP
	offset_top = TOP
	offset_bottom = TOP + 44.0
	var cog := _icon_button("CogButton", COG_ICON, tr("Settings"))
	cog.pressed.connect(settings_requested.emit)
	_menu = _icon_button("HamburgerButton", MENU_ICON, tr("Menu"))
	_menu.pressed.connect(menu_requested.emit)


## The menu button is for the fight only.
func show_menu(shown: bool) -> void:
	_menu.visible = shown


## How much room the bar takes from the right edge (the margin excluded), with a gap before the first button: what the
## sound button must leave free. 0 while the bar is hidden.
func occupied_width() -> float:
	if not visible:
		return 0.0
	var count := 0
	for child in get_children():
		if child is Control and (child as Control).visible:
			count += 1
	return count * (BUTTON_WIDTH + GAP)


func _icon_button(button_name: String, icon: Texture2D, tooltip: String) -> Button:
	var button := Button.new()
	button.name = button_name
	button.icon = icon
	button.expand_icon = true
	button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.custom_minimum_size = Vector2(BUTTON_WIDTH, 44)
	button.focus_mode = Control.FOCUS_NONE
	button.tooltip_text = tooltip
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	add_child(button)
	return button
