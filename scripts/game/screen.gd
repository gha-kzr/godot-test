class_name Screen
extends Control
## Base of the full-screen menus the Game root swaps in: Esc (ui_cancel) asks to go back
## (`back_pressed`; the root screen turns it off with `back_enabled`), and focus_first()
## puts keyboard focus on the first focusable control so arrows and Enter work at once.

signal back_pressed

var back_enabled := true


func _unhandled_input(event: InputEvent) -> void:
	if back_enabled and event.is_action_pressed(&"ui_cancel"):
		var viewport := get_viewport()  # The handler may swap this screen out of the tree.
		back_pressed.emit()
		viewport.set_input_as_handled()


## Focuses the first visible, enabled control that accepts focus (depth-first, in tree order).
func focus_first() -> void:
	if not is_inside_tree():
		return  # Deferred calls can arrive after the screen was swapped out.
	var target := _first_focusable(self)
	if target != null:
		target.grab_focus()


static func _first_focusable(node: Node) -> Control:
	for child in node.get_children():
		if child is Control:
			var control := child as Control
			if not control.visible:
				continue
			if control.focus_mode == Control.FOCUS_ALL and not (control is BaseButton and (control as BaseButton).disabled):
				return control
		var found := _first_focusable(child)
		if found != null:
			return found
	return null
