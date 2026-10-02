class_name StartScreen
extends Screen
## Web only: a first screen that asks for a click. Browsers keep sound off until the page has been
## clicked or a key pressed, so this click makes the title's music play from its very beginning.
## Any click, tap or key (not Esc or a modifier alone) goes on.

signal started

@onready var _title: Label = %TitleLabel
@onready var _picture: TextureRect = %Picture
@onready var _center: CenterContainer = %Center


func _ready() -> void:
	back_enabled = false
	_title.text = Game.TITLE


func show_title(title: String) -> void:
	_title.text = title


## The title picture (it carries the name) behind a prompt near the bottom; the text title otherwise.
func apply_branding(picture: Texture2D) -> void:
	_picture.texture = picture
	_picture.visible = picture != null
	_title.visible = picture == null
	_center.anchor_top = 0.82 if picture != null else 0.0


func _unhandled_input(event: InputEvent) -> void:
	var clicked := event is InputEventMouseButton and (event as InputEventMouseButton).pressed
	var touched := event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed
	var key := event as InputEventKey
	# Esc and a lone modifier don't count as a gesture for the browser, which would keep sound locked.
	var pressed_key := key != null and key.pressed and not key.echo and key.keycode not in [KEY_ESCAPE, KEY_SHIFT, KEY_CTRL, KEY_ALT, KEY_META]
	if clicked or touched or pressed_key:
		get_viewport().set_input_as_handled()
		started.emit()
