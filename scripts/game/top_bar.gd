class_name TopBar
extends HBoxContainer
## The round buttons in the top right corner, over every screen (the Game root owns the bar): sound, settings and, in
## a fight (solo or multiplayer), a menu (leaving it), in that order from left to right. The Game root decides which
## are shown. More options can join the row.

signal menu_requested
signal settings_requested

const MENU_ICON: Texture2D = preload("res://ui/icons/hamburger.svg")
const COG_ICON: Texture2D = preload("res://ui/icons/cog.svg")
## The screens' own margins (24 at the sides, 16 at the top): the buttons line up with their top bars.
const RIGHT_GAP := 24.0
const TOP := 16.0
const BUTTON_WIDTH := 48.0
const GAP := 8.0

## The speaker: always shown. It only shows and reports the state (`toggled`); the Game root owns the setting.
var mute_button: MuteButton
var _cog: Button
var _menu: Button


func _init() -> void:
	name = "TopBar"
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
	mute_button = MuteButton.new()
	add_child(mute_button)
	_cog = _icon_button("CogButton", COG_ICON, tr("Settings"))
	_cog.pressed.connect(settings_requested.emit)
	_menu = _icon_button("HamburgerButton", MENU_ICON, tr("Menu"))
	_menu.pressed.connect(menu_requested.emit)


## The settings button: on the screens that are not the settings themselves (or the title, which has its own).
func show_settings(shown: bool) -> void:
	_cog.visible = shown


## The menu button is for the fight only.
func show_menu(shown: bool) -> void:
	_menu.visible = shown


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
