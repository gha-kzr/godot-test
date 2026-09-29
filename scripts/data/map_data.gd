@tool
class_name MapData
extends Resource
## A battle map written as text: one row per line, one whitespace-separated token per cell.
##   <height>    floor cell at that height, e.g. 0, 2, 11
##   <height>p   floor cell + player spawn     <height>e   floor cell + enemy spawn
##   #           obstacle (impassable, blocks line of sight)
##   .           hole (impassable, does not block line of sight)
## Spawns are numbered in reading order (left to right, top to bottom).

const PLAYER_SPAWN := "p"
const ENEMY_SPAWN := "e"

@export var display_name := ""
## Emits `changed` when edited, so editor previews can follow.
@export_multiline var layout := "":
	set(value):
		layout = value
		emit_changed()


func get_validation_errors() -> PackedStringArray:
	return parse().errors


class ParseResult:
	var grid: Grid
	var player_spawns: Array[Vector2i] = []
	var enemy_spawns: Array[Vector2i] = []
	var errors := PackedStringArray()


func parse() -> ParseResult:
	var result := ParseResult.new()
	var rows: Array[PackedStringArray] = []
	# Tolerate Windows line endings and tabs.
	for line in layout.replace("\r", "").replace("\t", " ").split("\n"):
		var tokens := line.split(" ", false)
		if not tokens.is_empty():
			rows.append(tokens)

	if rows.is_empty():
		result.errors.append("%s: layout is empty" % display_name)
		return result

	var width := rows[0].size()
	var heights := PackedInt32Array()
	var types := PackedByteArray()
	for y in rows.size():
		if rows[y].size() != width:
			result.errors.append("%s: row %d has %d cells, expected %d" % [display_name, y + 1, rows[y].size(), width])
			continue
		for x in width:
			_parse_token(rows[y][x], Vector2i(x, y), heights, types, result)

	if result.player_spawns.is_empty():
		result.errors.append("%s: no player spawn ('%s')" % [display_name, PLAYER_SPAWN])
	if result.enemy_spawns.is_empty():
		result.errors.append("%s: no enemy spawn ('%s')" % [display_name, ENEMY_SPAWN])
	if result.errors.is_empty():
		result.grid = Grid.new(Vector2i(width, rows.size()), heights, types)
	return result


func _parse_token(token: String, cell: Vector2i, heights: PackedInt32Array, types: PackedByteArray, result: ParseResult) -> void:
	var type := Grid.CellType.FLOOR
	var height := 0
	match token:
		"#":
			type = Grid.CellType.OBSTACLE
		".":
			type = Grid.CellType.HOLE
		_:
			var digits := token
			if token.ends_with(PLAYER_SPAWN) or token.ends_with(ENEMY_SPAWN):
				digits = token.left(-1)
			if not digits.is_valid_int() or int(digits) < 0:
				result.errors.append("%s: invalid cell '%s' at %s" % [display_name, token, cell])
			else:
				height = int(digits)
				if token.ends_with(PLAYER_SPAWN):
					result.player_spawns.append(cell)
				elif token.ends_with(ENEMY_SPAWN):
					result.enemy_spawns.append(cell)
	heights.append(height)
	types.append(type)
