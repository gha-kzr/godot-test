class_name HintCard
extends PanelContainer
## A dismissable hint: a line of text and a "Got it" button. Hidden until show_hint();
## dismissing hides it and says so (the owner records it).

signal dismissed

@onready var _label: Label = %HintText
@onready var _button: Button = %DismissButton


func _ready() -> void:
	_button.pressed.connect(dismiss)
	hide()


func show_hint(text: String) -> void:
	_label.text = text
	show()


func dismiss() -> void:
	if visible:
		hide()
		dismissed.emit()
