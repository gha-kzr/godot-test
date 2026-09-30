extends SceneTree
## Builds res://ui/theme.tres, the game's cartoon UI theme (drawn rounded boxes, outlined
## labels), set project-wide in project.godot (gui/theme/custom).
## Rerun after changing the palette: godot --headless --script res://tools/build_theme.gd

const BASE_PATH := "res://ui/theme.tres"
const INK := Color(0.1, 0.09, 0.13)  ## Outlines.
const PANEL := Color(0.15, 0.15, 0.2, 0.94)
const PANEL_LIGHT := Color(0.22, 0.23, 0.3, 0.96)
const ACCENT := Color(1.0, 0.78, 0.25)  ## Gold: selection, focus, the active unit.
const BUTTON := Color(0.28, 0.44, 0.98)
const BUTTON_HOVER := Color(0.3, 0.72, 0.98)
const BUTTON_PRESSED := Color(0.2, 0.32, 0.75)
const BUTTON_DISABLED := Color(0.25, 0.25, 0.3)
const TEXT := Color(1.0, 0.98, 0.94)


func _init() -> void:
	_save(_base_theme(), BASE_PATH)
	quit()


func _base_theme() -> Theme:
	var theme := Theme.new()
	var font := FontVariation.new()  # Fredoka is a variable font: semi-bold reads best.
	font.base_font = load("res://ui/fonts/Fredoka.ttf") as Font
	font.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): 600}
	theme.default_font = font
	theme.default_font_size = 18
	for type in ["Label", "Button", "CheckBox", "OptionButton", "LineEdit", "TooltipLabel"]:
		theme.set_color("font_color", type, TEXT)
		theme.set_color("font_outline_color", type, INK)
		theme.set_constant("outline_size", type, 5 if type == "Label" else 4)
	for state in ["font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		theme.set_color(state, "Button", TEXT)
	theme.set_color("font_disabled_color", "Button", Color(0.7, 0.7, 0.75))
	theme.set_stylebox("normal", "Button", _box(BUTTON))
	theme.set_stylebox("hover", "Button", _box(BUTTON_HOVER))
	theme.set_stylebox("pressed", "Button", _box(BUTTON_PRESSED))
	theme.set_stylebox("hover_pressed", "Button", _box(BUTTON_PRESSED))
	theme.set_stylebox("disabled", "Button", _box(BUTTON_DISABLED))
	var focus := _box(Color.TRANSPARENT, 12, 3, ACCENT)
	focus.draw_center = false
	focus.shadow_size = 0
	theme.set_stylebox("focus", "Button", focus)
	theme.set_stylebox("panel", "PanelContainer", _box(PANEL, 16))
	theme.set_stylebox("panel", "Panel", _box(PANEL, 16))
	theme.set_stylebox("panel", "TooltipPanel", _box(PANEL_LIGHT, 10, 2))
	var bar_bg := _box(Color(0.05, 0.05, 0.08, 0.95), 7, 2)
	bar_bg.set_content_margin_all(0)
	bar_bg.shadow_size = 0
	var bar_fill := _box(Color(0.55, 0.85, 0.25), 7, 0)
	bar_fill.set_content_margin_all(0)
	bar_fill.shadow_size = 0
	theme.set_stylebox("background", "ProgressBar", bar_bg)
	theme.set_stylebox("fill", "ProgressBar", bar_fill)
	# Variations used by the HUD.
	theme.set_type_variation("Chip", "PanelContainer")
	var chip := _box(PANEL_LIGHT, 10, 2)
	chip.set_content_margin_all(4)
	theme.set_stylebox("panel", "Chip", chip)
	theme.set_type_variation("ChipActive", "PanelContainer")
	var active := _box(PANEL_LIGHT, 10, 3, ACCENT)
	active.set_content_margin_all(4)
	theme.set_stylebox("panel", "ChipActive", active)
	theme.set_type_variation("SlotButton", "Button")  # Spell slots: square.
	theme.set_type_variation("SelectedSlotButton", "Button")
	theme.set_stylebox("normal", "SelectedSlotButton", _box(ACCENT.darkened(0.2), 12, 3))
	theme.set_stylebox("hover", "SelectedSlotButton", _box(ACCENT, 12, 3))
	theme.set_stylebox("pressed", "SelectedSlotButton", _box(ACCENT.darkened(0.2), 12, 3))
	theme.set_stylebox("hover_pressed", "SelectedSlotButton", _box(ACCENT, 12, 3))
	theme.set_type_variation("CloseButton", "Button")
	theme.set_stylebox("normal", "CloseButton", _box(Color(0.9, 0.25, 0.3), 16, 2))
	theme.set_stylebox("hover", "CloseButton", _box(Color(1.0, 0.4, 0.45), 16, 2))
	theme.set_type_variation("HeaderLabel", "Label")
	theme.set_font_size("font_size", "HeaderLabel", 24)
	theme.set_constant("outline_size", "HeaderLabel", 6)
	theme.set_type_variation("XpBar", "ProgressBar")  # Gold, to tell it from the green HP bars.
	var xp_fill := _box(ACCENT, 7, 0)
	xp_fill.set_content_margin_all(0)
	xp_fill.shadow_size = 0
	theme.set_stylebox("fill", "XpBar", xp_fill)
	theme.set_type_variation("SmallLabel", "Label")
	theme.set_font_size("font_size", "SmallLabel", 14)
	theme.set_type_variation("PromptLabel", "Label")
	theme.set_font_size("font_size", "PromptLabel", 20)
	theme.set_color("accent", "Hud", ACCENT)
	return theme


func _box(fill: Color, radius := 12, border := 3, border_color := INK) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.set_corner_radius_all(radius)
	box.set_border_width_all(border)
	box.border_color = border_color
	box.set_content_margin_all(8)
	box.shadow_color = Color(0, 0, 0, 0.35)
	box.shadow_size = 3
	box.shadow_offset = Vector2(0, 3)
	box.anti_aliasing = true
	return box


func _save(theme: Theme, path: String) -> void:
	var uid := ResourceLoader.get_resource_uid(path) if ResourceLoader.exists(path) else ResourceUID.INVALID_ID
	var error := ResourceSaver.save(theme, path)
	if error != OK:
		push_error("build_theme: can't save %s (%s)" % [path, error_string(error)])
	elif uid != ResourceUID.INVALID_ID:
		ResourceSaver.set_uid(path, uid)
