extends TestCase
## The Screen base: Esc asks to go back (unless turned off) and focus_first finds the first
## usable control.


func _screen() -> Screen:
	var screen := Screen.new()
	var column := VBoxContainer.new()
	var label := Label.new()
	var locked := Button.new()
	locked.name = "Locked"
	locked.disabled = true
	var hidden := Button.new()
	hidden.name = "Hidden"
	hidden.visible = false
	var first := Button.new()
	first.name = "First"
	var second := Button.new()
	second.name = "Second"
	for node: Node in [label, locked, hidden, first, second]:
		column.add_child(node)
	screen.add_child(column)
	(Engine.get_main_loop() as SceneTree).root.add_child(screen)
	return screen


func _escape() -> InputEventAction:
	var escape := InputEventAction.new()
	escape.action = &"ui_cancel"
	escape.pressed = true
	return escape


func test_escape_emits_back_pressed_unless_disabled() -> void:
	var screen := _screen()
	var backs := {"count": 0}
	screen.back_pressed.connect(func() -> void: backs.count += 1)
	screen._unhandled_input(_escape())
	assert_eq(backs.count, 1)
	screen.back_enabled = false
	screen._unhandled_input(_escape())
	assert_eq(backs.count, 1, "the root screen ignores Esc")
	screen.free()


func test_focus_first_skips_disabled_and_hidden_controls() -> void:
	var screen := _screen()
	screen.focus_first()
	assert_eq(screen.get_viewport().gui_get_focus_owner().name, &"First")
	screen.free()
