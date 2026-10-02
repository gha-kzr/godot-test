class_name TutorialOverlay
extends Control
## A spotlight: the screen dimmed except one rectangle, with a card of text next to it. Four dim
## rectangles surround the hole and take the mouse, so clicks inside the hole reach whatever is
## below (a HUD control, the board) and every other click is swallowed. Keys that would activate a
## focused control outside the hole are swallowed too. It only shows and gates; the owner decides
## the step and when it ends.

signal skipped

const DIM := Color(0.0, 0.0, 0.0, 0.62)
const HOLE_PADDING := 10.0
const CARD_WIDTH := 340.0
const CARD_GAP := 14.0
const OUTLINE := Color(1.0, 0.78, 0.25)

var hole := Rect2()
## Also swallows Esc (the hub's "back to the title").
var block_cancel := false

var _dims: Array[ColorRect] = []
var _outline: Panel
var _card: PanelContainer
var _text: Label
var _skip: Button
var _pulse: Tween


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	for i in 4:
		var dim := ColorRect.new()
		dim.color = DIM
		dim.mouse_filter = Control.MOUSE_FILTER_STOP
		add_child(dim)
		_dims.append(dim)
	_outline = Panel.new()
	_outline.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.draw_center = false
	style.set_border_width_all(4)
	style.border_color = OUTLINE
	style.set_corner_radius_all(12)
	_outline.add_theme_stylebox_override("panel", style)
	add_child(_outline)
	_card = PanelContainer.new()
	_card.theme_type_variation = &"Chip"
	_card.custom_minimum_size = Vector2(CARD_WIDTH, 0)
	_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var rows := VBoxContainer.new()
	_card.add_child(rows)
	_text = Label.new()
	_text.theme_type_variation = &"PromptLabel"
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.custom_minimum_size = Vector2(CARD_WIDTH - 24.0, 0.0)  # Wrapping needs a width before the first layout.
	rows.add_child(_text)
	_skip = Button.new()
	_skip.name = "SkipButton"
	_skip.text = tr("Skip tutorial")
	_skip.focus_mode = Control.FOCUS_NONE
	# A small quiet link in the card's corner: the step's instruction is the thing to do, not Skip.
	_skip.flat = true
	_skip.add_theme_font_size_override("font_size", 13)
	_skip.size_flags_horizontal = Control.SIZE_SHRINK_END
	_skip.modulate = Color(1.0, 1.0, 1.0, 0.6)
	_skip.pressed.connect(skipped.emit)
	rows.add_child(_skip)
	add_child(_card)
	hide()


func is_active() -> bool:
	return visible


## Lights `area` (screen coordinates) with `text` on the card.
func show_step(text: String, area: Rect2) -> void:
	_text.text = text
	show()
	set_hole(area)
	if _pulse != null:
		_pulse.kill()
	_pulse = create_tween().set_loops()
	_pulse.tween_property(_outline, "modulate:a", 0.45, 0.6)
	_pulse.tween_property(_outline, "modulate:a", 1.0, 0.6)


func clear() -> void:
	if _pulse != null:
		_pulse.kill()
		_pulse = null
	hide()


## Moves the spotlight (the board moves under a camera that turns).
func set_hole(area: Rect2) -> void:
	var screen := get_viewport_rect()
	hole = area.grow(HOLE_PADDING).intersection(screen)
	if not hole.has_area():
		hole = Rect2(screen.get_center() - Vector2(40, 40), Vector2(80, 80))
	var right := hole.end.x
	var bottom := hole.end.y
	_place(_dims[0], Vector2.ZERO, Vector2(screen.size.x, hole.position.y))  # Above.
	_place(_dims[1], Vector2(0.0, bottom), Vector2(screen.size.x, screen.size.y - bottom))  # Below.
	_place(_dims[2], Vector2(0.0, hole.position.y), Vector2(hole.position.x, hole.size.y))  # Left.
	_place(_dims[3], Vector2(right, hole.position.y), Vector2(screen.size.x - right, hole.size.y))  # Right.
	_place(_outline, hole.position, hole.size)
	_card.reset_size()
	_card.position = _card_position(screen)


## Where the card goes: below the hole, else above, else beside it: the first place where it fits
## on screen; when none does (a huge hole), the one that covers the least of the hole. The card
## never takes the mouse (only its Skip button does), so even then the cells under it can be clicked.
func _card_position(screen: Rect2) -> Vector2:
	var size_ := _card.size
	var margin := 12.0
	var x := clampf(hole.get_center().x - size_.x / 2.0, margin, maxf(margin, screen.size.x - size_.x - margin))
	var y := clampf(hole.get_center().y - size_.y / 2.0, margin, maxf(margin, screen.size.y - size_.y - margin))
	var candidates: Array[Vector2] = [
		Vector2(x, hole.end.y + CARD_GAP), Vector2(x, hole.position.y - CARD_GAP - size_.y),
		Vector2(hole.end.x + CARD_GAP, y), Vector2(hole.position.x - CARD_GAP - size_.x, y)]
	var fits := screen.grow(-margin + 0.01)
	for candidate in candidates:
		if fits.encloses(Rect2(candidate, size_)):
			return candidate
	var best := candidates[0]
	var least := INF
	for candidate in candidates:
		var spot := Vector2(clampf(candidate.x, margin, maxf(margin, screen.size.x - size_.x - margin)),
				clampf(candidate.y, margin, maxf(margin, screen.size.y - size_.y - margin)))
		var overlap := Rect2(spot, size_).intersection(hole)
		var area := overlap.size.x * overlap.size.y if overlap.has_area() else 0.0
		if area < least:
			least = area
			best = spot
	return best


func _place(control: Control, at: Vector2, size_: Vector2) -> void:
	control.position = at
	control.size = Vector2(maxf(size_.x, 0.0), maxf(size_.y, 0.0))


## Keys: Enter or Space on a control that has focus outside the hole would act through the dim.
func _input(event: InputEvent) -> void:
	if not visible or event is not InputEventKey or not (event as InputEventKey).pressed:
		return
	var focused := get_viewport().gui_get_focus_owner()
	if event.is_action(&"ui_accept") and focused != null and not hole.intersects(focused.get_global_rect()):
		get_viewport().set_input_as_handled()
	elif block_cancel and event.is_action(&"ui_cancel"):
		get_viewport().set_input_as_handled()
