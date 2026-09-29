@tool
extends VBoxContainer
## The Design bottom panel: create or duplicate content, and the balance lab.
## Creation goes through ContentFactory; the new file is scanned and opened in the Inspector.

const LabPanel := preload("res://addons/design_tools/lab_panel.gd")

var _kind: OptionButton
var _name: LineEdit
var _status: Label
var _factory := ContentFactory.new()


func _init() -> void:
	name = "Design"
	custom_minimum_size = Vector2(0, 260)
	var row := HBoxContainer.new()
	add_child(row)
	_kind = OptionButton.new()
	for kind: int in ContentFactory.Kind.values():
		_kind.add_item(ContentFactory.kind_name(kind), kind)
	row.add_child(_kind)
	_name = LineEdit.new()
	_name.placeholder_text = "Name, e.g. Frost Bolt"
	_name.custom_minimum_size = Vector2(220, 0)
	row.add_child(_name)
	var create := Button.new()
	create.text = "New"
	create.pressed.connect(_on_create)
	row.add_child(create)
	var duplicate := Button.new()
	duplicate.text = "Duplicate selected"
	duplicate.tooltip_text = "Copies the spell / enemy / encounter / preset open in the Inspector under the new name."
	duplicate.pressed.connect(_on_duplicate)
	row.add_child(duplicate)
	_status = Label.new()
	_status.text = "Create content from a template, or copy the one open in the Inspector."
	add_child(_status)
	add_child(HSeparator.new())
	add_child(LabPanel.new())


func _on_create() -> void:
	_report(_factory.create(_kind.get_selected_id() as ContentFactory.Kind, _name.text))


func _on_duplicate() -> void:
	var edited := EditorInterface.get_inspector().get_edited_object() as Resource
	if edited == null:
		_status.text = "Open a spell, enemy, encounter or preset in the Inspector first."
		return
	_report(_factory.duplicate_resource(edited, _name.text))


func _report(error: String) -> void:
	if not error.is_empty():
		_status.text = error
		return
	_status.text = "Created %s." % _factory.last_path
	EditorInterface.get_resource_filesystem().update_file(_factory.last_path)
	EditorInterface.edit_resource(load(_factory.last_path))
