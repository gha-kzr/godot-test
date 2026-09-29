@tool
extends EditorInspectorPlugin
## Adds a design preview above the fields of spells and enemies in the Inspector.

const PreviewPanel := preload("res://addons/design_tools/previews/preview_panel.gd")


func _can_handle(object: Object) -> bool:
	return object is SpellData or object is EnemyData


func _parse_begin(object: Object) -> void:
	add_custom_control(PreviewPanel.new(object as Resource))
