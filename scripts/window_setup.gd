extends Node
## Autoload: sizes the game window at startup. On macOS with mixed screens (e.g. a Retina
## laptop and a 1080p monitor), window sizes are in pixels of the densest screen, so the
## project's 1280x720 opens at a quarter of the expected area and looks blurry when shrunk
## onto a 1x screen. Scaling by the largest screen scale keeps it 1280x720 in points;
## the canvas_items stretch mode then scales the HUD with the window.

## Most of the screen the window may take, so it never opens larger than the screen.
const MAX_SCREEN_FRACTION := 0.9


func _ready() -> void:
	var window := get_window()
	# Headless runs have no real window; a game embedded in the editor's Game tab is sized
	# by the editor; in a browser the page sizes the canvas (resizing it offsets it).
	if DisplayServer.get_name() == "headless" or Engine.is_embedded_in_editor() or OS.has_feature("web") \
			or window.mode != Window.MODE_WINDOWED:
		return
	var base := Vector2(ProjectSettings.get_setting("display/window/size/viewport_width"),
			ProjectSettings.get_setting("display/window/size/viewport_height"))
	var size := base * DisplayServer.screen_get_max_scale()
	var usable := Vector2(DisplayServer.screen_get_usable_rect(window.current_screen).size) * MAX_SCREEN_FRACTION
	size *= minf(1.0, minf(usable.x / size.x, usable.y / size.y))  # Keep the aspect ratio.
	window.size = Vector2i(size)
	window.move_to_center()
