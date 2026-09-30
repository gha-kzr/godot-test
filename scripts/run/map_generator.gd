@tool
class_name MapGenerator
extends RefCounted
## Generates a battle map from a seeded RNG: raised plateaus smoothed so every step
## climbs at most one level, a sprinkle of obstacles and holes, a 3 x 3 player start zone
## and the enemy spawns, placed by layout: facing edges, opposite corners, or an ambush
## (the zone in the centre, enemies on 2-3 sides). Every attempt is checked for two-way
## connectivity and for the enemies' distance to the zone; failed attempts draw the next
## one from the same RNG, so the result is still fully determined by the seed.

enum Layout { EDGE, CORNER, AMBUSH }

## The start zone is a 3 x 3 square.
const ZONE_SIZE := 9
const ATTEMPTS := 20
const SIDES: Array[Vector2i] = [Vector2i.UP, Vector2i.LEFT, Vector2i.RIGHT, Vector2i.DOWN]


## At most this many enemies can be placed by every layout (CORNER has 6 candidate cells).
const MAX_ENEMIES := 6


static func generate(rng: RandomNumberGenerator, settings: MapGenSettings, enemy_count: int, is_boss := false,
		layout := Layout.EDGE) -> MapData:
	if enemy_count < 1 or enemy_count > MAX_ENEMIES:
		push_error("MapGenerator: %d enemies (1 to %d supported)" % [enemy_count, MAX_ENEMIES])
		enemy_count = clampi(enemy_count, 1, MAX_ENEMIES)
	for attempt in ATTEMPTS:
		var map := _attempt(rng, settings, enemy_count, is_boss, layout)
		if is_playable(map, enemy_count, settings.min_enemy_distance):
			return map
	push_warning("MapGenerator: no valid %s map in %d attempts; using an open map" % [Layout.keys()[layout], ATTEMPTS])
	return _open_map(maxi(settings.min_size, settings.min_enemy_distance + 4), enemy_count)  # Always valid.


## Parses, has the zone and the enemy spawns, every floor cell can reach and be reached
## from the zone (climbing and dropping limits make walking one-way), and no zone cell is
## closer than `min_enemy_distance` MP to an enemy spawn.
static func is_playable(map: MapData, enemy_count: int, min_enemy_distance := 0) -> bool:
	var parsed := map.parse()
	if parsed.grid == null or parsed.player_spawns.size() != ZONE_SIZE or parsed.enemy_spawns.size() != enemy_count:
		return false
	var to_zone := Movement.distances_to(parsed.grid, parsed.player_spawns)
	var from_zone := _walkable_from(parsed.grid, parsed.player_spawns[0])
	for y in parsed.grid.size.y:
		for x in parsed.grid.size.x:
			var cell := Vector2i(x, y)
			if parsed.grid.is_walkable(cell) and (not to_zone.has(cell) or not from_zone.has(cell)):
				return false
	var to_enemies := Movement.distances_to(parsed.grid, parsed.enemy_spawns)
	for cell in parsed.player_spawns:
		if to_enemies.get(cell, 0) < min_enemy_distance:
			return false
	return true


## Picks a floor's layout from the settings' weights (no ambush before `ambush_from_floor`).
static func pick_layout(rng: RandomNumberGenerator, settings: MapGenSettings, floor_number: int) -> Layout:
	var weights := [settings.edge_weight, settings.corner_weight,
			settings.ambush_weight if floor_number >= settings.ambush_from_floor else 0]
	var total := 0
	for weight: int in weights:
		total += weight
	if total <= 0:
		return Layout.EDGE
	var roll := rng.randi_range(1, total)
	for i in weights.size():
		roll -= weights[i]
		if roll <= 0:
			return i as Layout
	return Layout.EDGE


static func _attempt(rng: RandomNumberGenerator, settings: MapGenSettings, enemy_count: int, is_boss: bool,
		layout: Layout) -> MapData:
	var width := settings.boss_size if is_boss else rng.randi_range(settings.min_size, settings.max_size)
	var height := settings.boss_size if is_boss else rng.randi_range(settings.min_size, settings.max_size)
	if layout == Layout.AMBUSH:
		width = maxi(width, settings.ambush_size)
		height = maxi(height, settings.ambush_size)
	var heights: Array[PackedInt32Array] = []
	for y in height:
		var row := PackedInt32Array()
		row.resize(width)
		heights.append(row)
	for i in settings.plateaus:
		var w := rng.randi_range(2, 4)
		var h := rng.randi_range(2, 4)
		var x0 := rng.randi_range(0, width - w)
		var y0 := rng.randi_range(0, height - h)
		var level := rng.randi_range(1, settings.max_height)
		for y in range(y0, mini(height, y0 + h)):
			for x in range(x0, x0 + w):
				heights[y][x] = maxi(heights[y][x], level)
	_smooth(heights)
	# Tokens: "" floor, "#" obstacle, "." hole.
	var marks: Array[PackedStringArray] = []
	var density := settings.boss_obstacle_density if is_boss else settings.obstacle_density
	for y in height:
		var row := PackedStringArray()
		row.resize(width)
		for x in width:
			var roll := rng.randf()
			if roll < density:
				row[x] = "#"
			elif roll < density + settings.hole_density:
				row[x] = "."
		marks.append(row)
	var size := Vector2i(width, height)
	var center := _zone_center(rng, size, layout)
	var zone: Array[Vector2i] = []
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			zone.append(center + Vector2i(dx, dy))
	var enemies := _enemy_cells(rng, size, layout, center, enemy_count)
	var lines: Array[String] = []
	for y in height:
		var tokens: Array[String] = []
		for x in width:
			var cell := Vector2i(x, y)
			var token := marks[y][x]
			if token == "#" and heights[y][x] > 0:
				token = "%d#" % heights[y][x]  # A block stands on its plateau, not sunk to level 0.
			if token.is_empty() or cell in zone or cell in enemies:
				token = str(heights[y][x])
				if cell in zone:
					token += MapData.PLAYER_SPAWN
				elif cell in enemies:
					token += MapData.ENEMY_SPAWN
			tokens.append(token)
		lines.append(" ".join(tokens))
	var map := MapData.new()
	map.layout = "\n".join(lines)
	return map


## The zone's centre: one row in from the bottom edge, around the middle (EDGE), a bottom corner (CORNER) or
## near the middle (AMBUSH).
static func _zone_center(rng: RandomNumberGenerator, size: Vector2i, layout: Layout) -> Vector2i:
	match layout:
		Layout.CORNER:
			return Vector2i(1 if rng.randi_range(0, 1) == 0 else size.x - 2, size.y - 2)
		Layout.AMBUSH:
			return Vector2i(size.x / 2 + rng.randi_range(-1, 0), size.y / 2 + rng.randi_range(-1, 0))
		_:
			return Vector2i(size.x / 2 + rng.randi_range(-2, 1), size.y - 2)


## Enemy spawns: spread along the top edge (EDGE), around the corner opposite the zone
## (CORNER), or on 2-3 sides of the map around the zone (AMBUSH).
static func _enemy_cells(rng: RandomNumberGenerator, size: Vector2i, layout: Layout, center: Vector2i,
		count: int) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	match layout:
		Layout.CORNER:
			var corner := Vector2i(size.x - 1 if center.x < size.x / 2 else 0, 0)
			var step := Vector2i(-1 if corner.x > 0 else 1, 1)
			var candidates: Array[Vector2i] = [corner, corner + Vector2i(step.x * 2, 0), corner + Vector2i(0, 2),
					corner + Vector2i(step.x, step.y), corner + Vector2i(step.x * 3, 1), corner + Vector2i(1 * step.x, 3)]
			var offset := rng.randi_range(0, 2)
			for i in count:
				cells.append(candidates[(offset + i) % candidates.size()])
		Layout.AMBUSH:
			var sides := SIDES.duplicate()
			_shuffle(rng, sides)
			sides.resize(clampi(count, 1, rng.randi_range(2, 3)))
			for i in count:
				var side: Vector2i = sides[i % sides.size()]
				var along := rng.randi_range(-2, 2) + (i / sides.size()) * 3
				var cell := center
				if side.x == 0:
					cell = Vector2i(clampi(center.x + along, 0, size.x - 1), 0 if side.y < 0 else size.y - 1)
				else:
					cell = Vector2i(0 if side.x < 0 else size.x - 1, clampi(center.y + along, 0, size.y - 1))
				# Slide along the side (wrapping) to a free cell; give up if the side is full.
				var tries := 0
				while cell in cells and tries < size.x + size.y:
					cell = Vector2i((cell.x + absi(side.y)) % size.x, (cell.y + absi(side.x)) % size.y)
					tries += 1
				cells.append(cell)
		_:
			for column in _spread_columns(rng, size.x, count):
				cells.append(Vector2i(column, 0))
	return cells


static func _shuffle(rng: RandomNumberGenerator, list: Array) -> void:
	for i in range(list.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var swap: Variant = list[i]
		list[i] = list[j]
		list[j] = swap


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


## An open EDGE map: the zone at the bottom centre, enemies along the top.
static func _open_map(size: int, enemy_count: int) -> MapData:
	var center := Vector2i(size / 2, size - 2)
	var lines: Array[String] = []
	for y in size:
		var tokens: Array[String] = []
		for x in size:
			var token := "0"
			if absi(x - center.x) <= 1 and absi(y - center.y) <= 1:
				token += MapData.PLAYER_SPAWN
			elif y == 0 and x < enemy_count:
				token += MapData.ENEMY_SPAWN
			tokens.append(token)
		lines.append(" ".join(tokens))
	var map := MapData.new()
	map.layout = "\n".join(lines)
	return map
