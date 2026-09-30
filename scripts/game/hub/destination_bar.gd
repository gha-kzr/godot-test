class_name DestinationBar
extends VBoxContainer
## Where to fight next: the saved run (Continue / Abandon), or the tower from a starting
## floor and the stages. Choices go up as signals.

signal tower_pressed(start_floor: int)
signal stage_pressed(stage_index: int)
signal continue_pressed
signal abandon_pressed

const LOCKED_TEXT := "%s (locked)"


func show_destinations(profile: Profile, tower: TowerConfig) -> void:
	HubStyle.clear_children(self)
	if tower == null:
		return
	var run := profile.run
	if run != null:
		var where := run.stage.display_name if run.mode == RunState.Mode.STAGE else "Tower, floor %d" % run.floor_number
		if run.awaiting_choice():
			where += " (boss reward to pick)"
		add_child(_label("Run in progress: " + where))
		add_child(_row([_action("ContinueButton", "Continue run", continue_pressed.emit),
				_action("AbandonButton", "Abandon run", abandon_pressed.emit)]))
		return
	var best := "best floor %d" % profile.best_depth if profile.best_depth > 0 else "not climbed yet"
	add_child(_label("Tower — up to floor %d, %s" % [profile.tower_cap(tower), best]))
	var floors := OptionButton.new()
	floors.name = "StartFloor"
	floors.custom_minimum_size = Vector2(180, 44)
	for start in profile.start_floors(tower):
		floors.add_item("From floor %d" % start, start)
	floors.select(floors.item_count - 1)
	var climb := _action("TowerButton", "Climb the tower", func() -> void: tower_pressed.emit(floors.get_selected_id()))
	add_child(_row([floors, climb]))
	add_child(_label("Stages"))
	var stages: Array[Control] = []
	for index in tower.stages.size():
		var stage := tower.stages[index]
		var button := _action("Stage%d" % index, stage.display_name + (" (cleared)" if stage in profile.cleared_stages else ""),
				stage_pressed.emit.bind(index))
		if not profile.is_stage_available(tower, stage):
			button.text = LOCKED_TEXT % stage.display_name
			button.disabled = true
			button.tooltip_text = "Clear the previous stage first."
		else:
			button.tooltip_text = "One battle. Clearing it lets the tower go up to floor %d and start at floor %d." % [
					stage.unlocks_cap, stage.unlocks_start_floor]
		stages.append(button)
	add_child(_row(stages))


func _action(node_name: String, text: String, on_pressed: Callable) -> Button:
	var button := HubStyle.button(text, node_name)
	button.custom_minimum_size = Vector2(200, 44)
	button.pressed.connect(on_pressed)
	return button


func _row(controls: Array) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	for control: Control in controls:
		row.add_child(control)
	return row


func _label(text: String) -> Label:
	var label := Label.new()
	label.theme_type_variation = &"PromptLabel"
	label.text = text
	return label
