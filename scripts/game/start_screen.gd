class_name StartScreen
extends Screen
## The first screen, on every platform: it asks for a click. Browsers keep sound off until the page
## has been clicked or a key pressed, so this click makes the title's music play from its very
## beginning; desktop builds show it too, so both versions open the same way.
## Any click, tap or key (not Esc or a modifier alone) goes on. Clicks and taps arrive through
## _gui_input: the screen is a Control that takes the mouse, so they never reach _unhandled_input.

signal started

## The "Click to start" pill breathes: it grows to this scale and back (from its center), each
## way in PULSE_TIME seconds.
const PULSE_SCALE := 1.08
const PULSE_TIME := 0.8
## With the title picture, the prompt sits in this band of the screen's height, just under the
## name painted on the picture.
const PROMPT_TOP := 0.7
const PROMPT_BOTTOM := 0.84

@onready var _title: Label = %TitleLabel
@onready var _picture: TextureRect = %Picture
@onready var _center: CenterContainer = %Center
@onready var _prompt_box: PanelContainer = %PromptBox


func _ready() -> void:
	back_enabled = false
	_title.text = Game.TITLE
	_prompt_box.pivot_offset_ratio = Vector2(0.5, 0.5)  # Grows from its center, whatever its size.
	var pulse := _prompt_box.create_tween().set_loops().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	pulse.tween_property(_prompt_box, "scale", Vector2.ONE * PULSE_SCALE, PULSE_TIME)
	pulse.tween_property(_prompt_box, "scale", Vector2.ONE, PULSE_TIME)


func show_title(title: String) -> void:
	_title.text = title


## The title picture (it carries the name) with the prompt just under the name; the text title
## and the prompt in the middle otherwise.
func apply_branding(picture: Texture2D) -> void:
	_picture.texture = picture
	_picture.visible = picture != null
	_title.visible = picture == null
	_center.anchor_top = PROMPT_TOP if picture != null else 0.0
	_center.anchor_bottom = PROMPT_BOTTOM if picture != null else 1.0


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
