class_name FloorStrip
extends HBoxContainer
## A window of ten tower floors around the next one: cleared floors tinted, the next one
## highlighted, elite floors marked "E" and boss floors with a skull.

const WINDOW := 10
## How many cleared floors stay visible before the next one.
const LOOK_BACK := 4
const CLEARED_TINT := Color(0.65, 1.0, 0.65)
const AHEAD_TINT := Color(0.8, 0.8, 0.85)
const SKULL := preload("res://ui/icons/skull.svg")


## `next_floor`: the floor to play next.
func show_floors(next_floor: int) -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	var first := maxi(1, next_floor - LOOK_BACK)
	for floor_number in range(first, first + WINDOW):
		add_child(_cell(floor_number, next_floor))


func _cell(floor_number: int, next_floor: int) -> PanelContainer:
	var cell := PanelContainer.new()
	cell.name = "Floor%d" % floor_number
	cell.theme_type_variation = &"ChipActive" if floor_number == next_floor else &"Chip"
	cell.self_modulate = CLEARED_TINT if floor_number < next_floor else AHEAD_TINT
	cell.custom_minimum_size = Vector2(56, 0)
	var rows := VBoxContainer.new()
	rows.alignment = BoxContainer.ALIGNMENT_CENTER
	var number := Label.new()
	number.name = "Number"
	number.text = str(floor_number)
	number.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rows.add_child(number)
	var marker_box := CenterContainer.new()
	marker_box.custom_minimum_size = Vector2(0, 22)
	if TowerConfig.is_boss_floor(floor_number):
		var skull := TextureRect.new()
		skull.name = "BossMark"
		skull.texture = SKULL
		skull.custom_minimum_size = Vector2(22, 22)
		skull.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		skull.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		marker_box.add_child(skull)
	elif TowerConfig.is_elite_floor(floor_number):
		var elite := Label.new()
		elite.name = "EliteMark"
		elite.theme_type_variation = &"SmallLabel"
		elite.text = "E"
		marker_box.add_child(elite)
	rows.add_child(marker_box)
	cell.add_child(rows)
	return cell
