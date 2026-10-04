class_name StartScreen
extends Screen
## The first screen, on every platform: it asks for a click. Browsers keep sound off until the page
## has been clicked or a key pressed, so this click makes the title's music play from its very
## beginning; desktop builds show it too, so both versions open the same way.
## Any click, tap or key (not Esc or a modifier alone) goes on. Clicks and taps arrive through
## _gui_input: the screen is a Control that takes the mouse, so they never reach _unhandled_input.

signal started

## "Click to start" breathes: it grows to this scale and back, each way in PULSE_TIME seconds.
const PULSE_SCALE := 1.08
const PULSE_TIME := 0.8

@onready var _title: Label = %TitleLabel
@onready var _picture: TextureRect = %Picture
@onready var _center: CenterContainer = %Center
@onready var _prompt: Label = %Prompt


func _ready() -> void:
	back_enabled = false
	_title.text = Game.TITLE
	_prompt.resized.connect(func() -> void: _prompt.pivot_offset = _prompt.size / 2.0)  # Grows from its center.
	var pulse := _prompt.create_tween().set_loops().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	pulse.tween_property(_prompt, "scale", Vector2.ONE * PULSE_SCALE, PULSE_TIME)
	pulse.tween_property(_prompt, "scale", Vector2.ONE, PULSE_TIME)


func show_title(title: String) -> void:
	_title.text = title


## The title picture (it carries the name) behind a prompt near the bottom; the text title otherwise.
func apply_branding(picture: Texture2D) -> void:
	_picture.texture = picture
	_picture.visible = picture != null
	_title.visible = picture == null
	_center.anchor_top = 0.82 if picture != null else 0.0


func _gui_input(event: InputEvent) -> void:
	var clicked := event is InputEventMouseButton and (event as InputEventMouseButton).pressed
	var touched := event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed
	if clicked or touched:
		accept_event()
		started.emit()


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	# Esc and a lone modifier don't count as a gesture for the browser, which would keep sound locked.
	if key != null and key.pressed and not key.echo and key.keycode not in [KEY_ESCAPE, KEY_SHIFT, KEY_CTRL, KEY_ALT, KEY_META]:
		get_viewport().set_input_as_handled()
		started.emit()
