@tool
class_name Grid
extends RefCounted
## Static battlefield terrain: size, height and type per cell. Immutable once built,
## so battle state clones can share it. Cells are Vector2i(column, row).

enum CellType { FLOOR, OBSTACLE, HOLE }

## An obstacle is a full cube: one cell wide and deep, this many height levels tall (a level
## is half a cell, so two levels make one world unit). Rules and drawing both read it
## through obstacle_levels(), so what is drawn is what blocks.
const OBSTACLE_LEVELS := 2

const DIRECTIONS: Array[Vector2i] = [Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT, Vector2i.UP]

var size: Vector2i:
	get:
		return _size
	set(_value):
		push_error("Grid is immutable: size is read-only")

var _size: Vector2i
var _heights: PackedInt32Array
var _types: PackedByteArray


func _init(grid_size: Vector2i, heights: PackedInt32Array, types: PackedByteArray) -> void:
	if heights.size() != grid_size.x * grid_size.y or types.size() != heights.size():
		push_error("Grid: %d heights / %d types for size %s" % [heights.size(), types.size(), grid_size])
		grid_size = Vector2i.ZERO
		heights = PackedInt32Array()
		types = PackedByteArray()
	_size = grid_size
	_heights = heights
	_types = types


func in_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < size.x and cell.y < size.y


func height_at(cell: Vector2i) -> int:
	if not _check_bounds(cell):
		return 0
	return _heights[_index(cell)]


## How many levels the obstacle on `cell` rises above the cell's height (0: not an obstacle).
## A per-cell value later (taller objects) only changes this function.
func obstacle_levels(cell: Vector2i) -> int:
	return OBSTACLE_LEVELS if type_at(cell) == CellType.OBSTACLE else 0


## Out-of-bounds cells read as OBSTACLE, so rules treat them as impassable and opaque.
func type_at(cell: Vector2i) -> CellType:
	if not _check_bounds(cell):
		return CellType.OBSTACLE
	return _types[_index(cell)] as CellType


## Floor cells can be stood on. Obstacles and holes can't.
func is_walkable(cell: Vector2i) -> bool:
	return in_bounds(cell) and type_at(cell) == CellType.FLOOR


func neighbors(cell: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for direction in DIRECTIONS:
		if in_bounds(cell + direction):
			result.append(cell + direction)
	return result


func _index(cell: Vector2i) -> int:
	return cell.y * size.x + cell.x


func _check_bounds(cell: Vector2i) -> bool:
	if in_bounds(cell):
		return true
	push_error("Grid: cell %s out of bounds %s" % [cell, size])
	return false
