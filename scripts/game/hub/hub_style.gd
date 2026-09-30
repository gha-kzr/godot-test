class_name HubStyle
extends RefCounted
## Small helpers the hub components share.


## Removes children right away and frees them at the end of the frame (a button may be
## rebuilt from inside its own pressed signal).
static func clear_children(parent: Node) -> void:
	for child in parent.get_children():
		parent.remove_child(child)
		child.queue_free()


## A button that takes keyboard focus (the hub is navigated with arrows and Enter).
static func button(text: String, node_name := "") -> Button:
	var result := Button.new()
	result.text = text
	if not node_name.is_empty():
		result.name = node_name
	return result


## Colors a button's background (a rune's rarity), keeping the theme's shape.
static func tint(target: Button, color: Color) -> void:
	for state in ["normal", "hover", "pressed", "hover_pressed"]:
		var box := target.get_theme_stylebox(state).duplicate() as StyleBox
		if box is StyleBoxFlat:
			(box as StyleBoxFlat).bg_color = color.lightened(0.15) if state == "hover" else color
		target.add_theme_stylebox_override(state, box)
