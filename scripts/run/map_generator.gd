@tool
class_name MapGenerator
extends RefCounted
## Generates a battle map from a seeded RNG: raised plateaus smoothed so every step
## climbs at most one level, a sprinkle of obstacles and holes, 3 player spawns along the
## bottom edge and the enemy spawns along the top. Every attempt is checked for two-way
## connectivity; failed attempts draw the next one from the same RNG, so the result is
## still fully determined by the seed.

const PLAYER_SPAWNS := 3
const ATTEMPTS := 20


static func generate(rng: RandomNumberGenerator, settings: MapGenSettings, enemy_count: int, is_boss := false) -> MapData:
	for attempt in ATTEMPTS:
		var map := _attempt(rng, settings, enemy_count, is_boss)
		if is_playable(map, enemy_count):
			return map
	return _open_map(settings.min_size, enemy_count)  # Never reached in practice; always valid.


## Parses, has the right spawns, and every floor cell can reach and be reached from the
## player spawns (climbing and dropping limits make walking one-way).
static func is_playable(map: MapData, enemy_count: int) -> bool:
	var parsed := map.parse()
	if parsed.grid == null or parsed.player_spawns.size() != PLAYER_SPAWNS or parsed.enemy_spawns.size() != enemy_count:
		return false
	var to_spawns := Movement.distances_to(parsed.grid, parsed.player_spawns)
	var from_spawn := _walkable_from(parsed.grid, parsed.player_spawns[0])
	for y in parsed.grid.size.y:
		for x in parsed.grid.size.x:
			var cell := Vector2i(x, y)
			if parsed.grid.is_walkable(cell) and (not to_spawns.has(cell) or not from_spawn.has(cell)):
				return false
	return true


static func _attempt(rng: RandomNumberGenerator, settings: MapGenSettings, enemy_count: int, is_boss: bool) -> MapData:
	var width := settings.boss_size if is_boss else rng.randi_range(settings.min_size, settings.max_size)
	var height := settings.boss_size if is_boss else rng.randi_range(settings.min_size, settings.max_size)
	var heights: Array[PackedInt32Array] = []
	for y in height:
		var row := PackedInt32Array()
		row.resize(width)
		heights.append(row)
	for i in settings.plateaus:
		var w := rng.randi_range(2, 4)
		var h := rng.randi_range(2, 4)
		var x0 := rng.randi_range(0, width - w)
		var y0 := rng.randi_range(1, maxi(1, height - h - 1))
		var level := rng.randi_range(1, settings.max_height)
		for y in range(y0, mini(height, y0 + h)):
			for x in range(x0, x0 + w):
				heights[y][x] = maxi(heights[y][x], level)
	_smooth(heights)
	# Tokens: "" floor, "#" obstacle, "." hole; spawn rows stay clear.
	var marks: Array[PackedStringArray] = []
	var density := settings.boss_obstacle_density if is_boss else settings.obstacle_density
	for y in height:
		var row := PackedStringArray()
		row.resize(width)
		for x in width:
			var roll := rng.randf()
			if y > 0 and y < height - 1:
				if roll < density:
					row[x] = "#"
				elif roll < density + settings.hole_density:
					row[x] = "."
		marks.append(row)
	var player_columns := _spread_columns(rng, width, PLAYER_SPAWNS)
	var enemy_columns := _spread_columns(rng, width, enemy_count)
	var lines: Array[String] = []
	for y in height:
		var tokens: Array[String] = []
		for x in width:
			var token := marks[y][x]
			if token.is_empty():
				token = str(heights[y][x])
				if y == height - 1 and x in player_columns:
					token += MapData.PLAYER_SPAWN
				elif y == 0 and x in enemy_columns:
					token += MapData.ENEMY_SPAWN
			tokens.append(token)
		lines.append(" ".join(tokens))
	var map := MapData.new()
	map.layout = "\n".join(lines)
	return map


## Lowers cells until no two neighbours differ by more than one level (every step climbable).
static func _smooth(heights: Array[PackedInt32Array]) -> void:
	var changed := true
	while changed:
		changed = false
		for y in heights.size():
			for x in heights[y].size():
				var lowest := heights[y][x]
				for offset in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
					var nx: int = x + offset.x
					var ny: int = y + offset.y
					if ny >= 0 and ny < heights.size() and nx >= 0 and nx < heights[y].size():
						lowest = mini(lowest, heights[ny][nx])
				if heights[y][x] > lowest + 1:
					heights[y][x] = lowest + 1
					changed = true


## `count` distinct columns spread over the width, with a little jitter.
static func _spread_columns(rng: RandomNumberGenerator, width: int, count: int) -> Array[int]:
	var columns: Array[int] = []
	for i in count:
		var center := int((i + 0.5) * width / float(count))
		var column := clampi(center + rng.randi_range(-1, 1), 0, width - 1)
		while column in columns:
			column = (column + 1) % width
		columns.append(column)
	return columns


static func _walkable_from(grid: Grid, start: Vector2i) -> Dictionary[Vector2i, bool]:
	var seen: Dictionary[Vector2i, bool] = {start: true}
	var queue: Array[Vector2i] = [start]
	while not queue.is_empty():
		var cell: Vector2i = queue.pop_front()
		for next in grid.neighbors(cell):
			if not seen.has(next) and Movement.step_cost(grid, cell, next) >= 0:
				seen[next] = true
				queue.append(next)
	return seen


static func _open_map(size: int, enemy_count: int) -> MapData:
	var lines: Array[String] = []
	for y in size:
		var tokens: Array[String] = []
		for x in size:
			var token := "0"
			if y == size - 1 and x < PLAYER_SPAWNS:
				token += MapData.PLAYER_SPAWN
			elif y == 0 and x < enemy_count:
				token += MapData.ENEMY_SPAWN
			tokens.append(token)
		lines.append(" ".join(tokens))
	var map := MapData.new()
	map.layout = "\n".join(lines)
	return map
