class_name HintCard
extends PanelContainer
## A dismissable hint: a line of text and a "Got it" button. Hidden until show_hint();
## dismissing hides it and says so (the owner records it). While shown it is modal: a dim
## over the whole screen, just under the card, eats clicks until the hint is dismissed.
## A hint can light an area (the dim leaves a hole around it, outlined) and then the card
## sits next to it instead of in its corner.

signal dismissed

const DIM := Color(0.0, 0.0, 0.0, 0.45)
const HOLE_PADDING := 10.0
const CARD_GAP := 14.0
const MARGIN := 12.0
const OUTLINE := Color(1.0, 0.78, 0.25)

var _blocker: Control
var _spotlight := Callable()  ## Returns the lit area (a Rect2 in screen coordinates; empty for none).

@onready var _label: Label = %HintText
@onready var _button: Button = %DismissButton


func _ready() -> void:
	_button.pressed.connect(dismiss)
	visibility_changed.connect(_sync_blocker)
	hide()
	set_process(false)


## `spotlight`: returns the screen area to light up, asked every frame so it follows what moves
## (optional; `around()` makes one for a control).
func show_hint(text: String, spotlight := Callable()) -> void:
	_label.text = text
	_spotlight = spotlight
	show()
	set_process(_spotlight.is_valid())  # The layout settles after the first frame.
	_update_spotlight()


## A spotlight on a control (nothing while it is not shown).
static func around(control: Control) -> Callable:
	return func() -> Rect2:
		return control.get_global_rect() if is_instance_valid(control) and control.is_visible_in_tree() else Rect2()


func dismiss() -> void:
	if visible:
		hide()
		_spotlight = Callable()
		set_process(false)
		dismissed.emit()


func _process(_delta: float) -> void:
	_update_spotlight()


## The dim follows the card's visibility; on show both go last among their siblings, so the
## card is on top of everything it blocks.
func _sync_blocker() -> void:
	if not visible:
		if _blocker != null:
			_blocker.hide()
		return
	var host := get_parent()
	if host == null:
		return
	if _blocker == null:
		_blocker = Control.new()
		_blocker.name = "HintBlocker"
		_blocker.mouse_filter = Control.MOUSE_FILTER_STOP
		_blocker.set_anchors_preset(Control.PRESET_FULL_RECT)
		_blocker.draw.connect(_draw_blocker)
		host.add_child(_blocker)
	_blocker.show()
	host.move_child(_blocker, -1)
	host.move_child(self, -1)
	_blocker.queue_redraw()


## The lit area's rectangle in the blocker's own coordinates (empty without a spotlight).
func _hole() -> Rect2:
	if not _spotlight.is_valid() or _blocker == null:
		return Rect2()
	var rect: Rect2 = _spotlight.call()
	if not rect.has_area():
		return Rect2()
	rect.position -= _blocker.global_position
	return rect.grow(HOLE_PADDING)


func _draw_blocker() -> void:
	var screen := Rect2(Vector2.ZERO, _blocker.size)
	var hole := _hole().intersection(screen)
	if not hole.has_area():
		_blocker.draw_rect(screen, DIM)
		return
	_blocker.draw_rect(Rect2(0, 0, screen.size.x, hole.position.y), DIM)
	_blocker.draw_rect(Rect2(0, hole.end.y, screen.size.x, screen.size.y - hole.end.y), DIM)
	_blocker.draw_rect(Rect2(0, hole.position.y, hole.position.x, hole.size.y), DIM)
	_blocker.draw_rect(Rect2(hole.end.x, hole.position.y, screen.size.x - hole.end.x, hole.size.y), DIM)
	_blocker.draw_rect(hole, OUTLINE, false, 4.0)


## Redraws the dim around the lit control and puts the card beside it: above, else below.
func _update_spotlight() -> void:
	if _blocker == null:
		return
	_blocker.queue_redraw()
	var hole := _hole()
	if not hole.has_area():
		return
	var screen := Rect2(Vector2.ZERO, _blocker.size)
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	reset_size()
	var x := clampf(hole.get_center().x - size.x / 2.0, MARGIN, maxf(MARGIN, screen.size.x - size.x - MARGIN))
	var above := hole.position.y - CARD_GAP - size.y
	var y := above if above >= MARGIN else minf(hole.end.y + CARD_GAP, maxf(MARGIN, screen.size.y - size.y - MARGIN))
	position = _blocker.global_position + Vector2(x, y) - get_parent_control().global_position \
			if get_parent_control() != null else Vector2(x, y)


func _exit_tree() -> void:
	if _blocker != null and is_instance_valid(_blocker):
		_blocker.queue_free()
		_blocker = null
