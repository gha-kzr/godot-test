class_name NetJoinScreen
extends Screen
## While the connection to the game server opens (a host waits for its room, a joiner for its seat): what is going on,
## and a way out. A sleeping free server takes about a minute to wake, which the text says.

signal cancelled

var _title: Label
var _status: Label


func _ready() -> void:
	back_enabled = false
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var background := ColorRect.new()
	background.color = Color(0.1, 0.11, 0.14)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(560, 0)
	box.add_theme_constant_override("separation", 12)
	center.add_child(box)
	_title = Label.new()
	_title.theme_type_variation = &"HeaderLabel"
	_title.text = "Joining the match"
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_title)
	_status = Label.new()
	_status.name = "Status"
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.theme_type_variation = &"PromptLabel"
	box.add_child(_status)
	var cancel := HubStyle.button("Cancel", "CancelButton")
	cancel.pressed.connect(cancelled.emit)
	box.add_child(cancel)


## The screen of a host: the room is being made.
func show_opening() -> void:
	_title.text = tr("Opening the match")


func show_status(text: String) -> void:
	_status.text = text


func show_message(text: String) -> void:
	_status.text = text
