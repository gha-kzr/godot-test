class_name TitleScreen
extends Screen
## The game's first screen: its name, Play (the hub), Settings and Quit (not on web, where
## the page is the game). Choices go up as signals; the Game root switches screens.

signal play_pressed
signal settings_pressed
signal quit_pressed

@onready var _title: Label = %TitleLabel
@onready var _play: Button = %PlayButton
@onready var _settings: Button = %SettingsButton
@onready var _quit: Button = %QuitButton


func _ready() -> void:
	back_enabled = false  # The root screen: nowhere to go back to.
	_play.pressed.connect(play_pressed.emit)
	_settings.pressed.connect(settings_pressed.emit)
	_quit.pressed.connect(quit_pressed.emit)
	_quit.visible = not OS.has_feature("web")


func show_title(title: String) -> void:
	_title.text = title
