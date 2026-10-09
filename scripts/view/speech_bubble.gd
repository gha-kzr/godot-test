class_name SpeechBubble
extends Node3D
## A comic-style speech bubble over a unit's head: white, with a dark outline, rounded, and a little tail pointing
## down at the speaker. It is drawn by a small SubViewport of Controls (so it uses the game's font and the same
## look at any zoom) and shown on a billboard sprite that keeps its size on screen. The node's position is where
## the tail points; it fades out after a few seconds and removes itself.

const SECONDS := 5.0
const FADE := 0.6
## Same scale as the units' HP labels, so the text is as sharp.
const PIXEL_SIZE := 0.0012
const FONT_SIZE := 44
const OUTLINE := Color(0.08, 0.08, 0.1)
const BORDER := 4

var text := ""
var _sprite: Sprite3D


func _init(message := "") -> void:
	name = "Speech"
	text = message


func _ready() -> void:
	var message := text
	var viewport := SubViewport.new()
	viewport.transparent_bg = true
	viewport.disable_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", -BORDER)  # The tail covers the bubble's bottom outline where it joins.
	var style := StyleBoxFlat.new()
	style.bg_color = Color.WHITE
	style.border_color = OUTLINE
	style.set_border_width_all(BORDER)
	style.set_corner_radius_all(20)
	style.content_margin_left = 20
	style.content_margin_right = 20
	style.content_margin_top = 10
	style.content_margin_bottom = 12
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", style)
	var label := Label.new()
	label.text = message
	label.add_theme_font_size_override("font_size", FONT_SIZE)
	label.add_theme_color_override("font_color", OUTLINE)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(label)
	column.add_child(panel)
	var tail := Tail.new()
	tail.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	column.add_child(tail)
	viewport.add_child(column)
	add_child(viewport)
	var size := column.get_combined_minimum_size()
	column.size = size
	viewport.size = Vector2i(ceili(size.x), ceili(size.y))
	_sprite = Sprite3D.new()
	_sprite.texture = viewport.get_texture()
	_sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_sprite.no_depth_test = true
	_sprite.fixed_size = true
	_sprite.shaded = false
	_sprite.pixel_size = PIXEL_SIZE
	_sprite.offset = Vector2(0, size.y / 2.0)  # The bottom of the tail is on the node's position.
	add_child(_sprite)
	var tween := _sprite.create_tween()
	tween.tween_interval(SECONDS - FADE)
	tween.tween_property(_sprite, "modulate:a", 0.0, FADE)
	tween.tween_callback(queue_free)


## The tail: a small triangle with its two outer sides outlined (the top is open, into the bubble).
class Tail extends Control:
	func _init() -> void:
		custom_minimum_size = Vector2(34, 24)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var corners := PackedVector2Array([Vector2(size.x * 0.18, 0.0), Vector2(size.x * 0.5, size.y), Vector2(size.x * 0.82, 0.0)])
		draw_colored_polygon(corners, Color.WHITE)
		draw_polyline(corners, SpeechBubble.OUTLINE, float(SpeechBubble.BORDER), true)
