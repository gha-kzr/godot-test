@tool
extends Control
## Draws a SpellPreview.Grid2D: caster, cells in range, the area around a sample target.

## Cell size before the editor scale; the grid grows to the Inspector's width up to MAX_CELL.
const MIN_CELL := 12.0
const MAX_CELL := 30.0
const CASTER_COLOR := Color(0.3, 0.6, 1.0)
const RANGE_COLOR := Color(1.0, 0.55, 0.15, 0.55)
const AREA_COLOR := Color(1.0, 0.2, 0.15, 0.8)
const EMPTY_COLOR := Color(0.2, 0.22, 0.26)

var preview: SpellPreview.Grid2D:
	set(value):
		preview = value
		_update_minimum_size()
		queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_update_minimum_size()
		queue_redraw()


## The cell size that fits the width, between MIN_CELL and MAX_CELL (times the editor scale).
func _cell() -> float:
	var scale := EditorInterface.get_editor_scale()
	if preview == null or preview.size == 0:
		return MIN_CELL * scale
	return clampf(size.x / preview.size, MIN_CELL * scale, MAX_CELL * scale)


func _update_minimum_size() -> void:
	var side := preview.size * _cell() + 2.0 if preview != null else 0.0
	custom_minimum_size = Vector2(MIN_CELL * EditorInterface.get_editor_scale() * (preview.size if preview != null else 0), side)


func _draw() -> void:
	if preview == null:
		return
	var cell_size := _cell()
	for y in preview.size:
		for x in preview.size:
			var cell := Vector2i(x, y)
			var color := EMPTY_COLOR
			if cell in preview.in_range:
				color = RANGE_COLOR
			if cell in preview.area:
				color = AREA_COLOR
			if cell == preview.caster:
				color = CASTER_COLOR
			draw_rect(Rect2(Vector2(x, y) * cell_size + Vector2.ONE, Vector2.ONE * (cell_size - 1.0)), color)
	var target := Rect2(Vector2(preview.target) * cell_size + Vector2.ONE, Vector2.ONE * (cell_size - 1.0))
	draw_rect(target, Color.WHITE, false, 1.5)
