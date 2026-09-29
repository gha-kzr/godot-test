@tool
extends EditorPlugin
## Design Tools: Inspector previews for spells and enemies, and a Design bottom panel with
## content creation and the balance lab.

const DesignInspector := preload("res://addons/design_tools/design_inspector.gd")
const DesignPanel := preload("res://addons/design_tools/design_panel.gd")

var _inspector: EditorInspectorPlugin
var _panel: Control


func _enter_tree() -> void:
	_inspector = DesignInspector.new()
	add_inspector_plugin(_inspector)
	_panel = DesignPanel.new()
	add_control_to_bottom_panel(_panel, "Design")


func _exit_tree() -> void:
	remove_inspector_plugin(_inspector)
	_inspector = null
	remove_control_from_bottom_panel(_panel)
	_panel.queue_free()
	_panel = null
