class_name TitleScreen
extends Screen
## The game's first screen: its name, Play (the hub), Settings and Quit (not on web, where
## the page is the game). Choices go up as signals; the Game root switches screens.

## Where the menu starts (share of the height) when a title picture fills the screen: under its name.
const PICTURE_MENU_TOP := 0.68

signal play_pressed
signal settings_pressed
signal quit_pressed

@onready var _title: Label = %TitleLabel
@onready var _best: Label = %BestLabel
@onready var _logo: TextureRect = %Logo
@onready var _center: CenterContainer = %Center
@onready var _spacer: Control = %Spacer
@onready var _picture: TextureRect = %Picture
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


## The owner's artwork, when there is some: the logo replaces the text title, the picture sits
## behind everything.
func apply_branding(logo: Texture2D, picture: Texture2D) -> void:
	_logo.texture = logo
	_logo.visible = logo != null and picture == null
	# The picture carries the name itself: the menu moves below it, and no text title over it.
	_title.visible = logo == null and picture == null
	_picture.texture = picture
	_picture.visible = picture != null
	_center.anchor_top = PICTURE_MENU_TOP if picture != null else 0.0
	_spacer.visible = picture == null


## The best floor reached, under the title (nothing before the first floor is won).
func show_best_floor(depth: int) -> void:
	_best.visible = depth > 0
	_best.text = tr("Best floor: %d") % depth
