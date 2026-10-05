@tool
class_name MapGenerator
extends RefCounted
## Generates a battle map from a seeded RNG: the typology's shape (MapShapes: open field,
## mountain, crater, islands, canyon, ruins), a 3 x 3 player start zone placed by layout (near
## the bottom edge, a bottom corner, or the centre for an ambush) with every piece of ground
## bridged to it, and the enemy spawns a bounded walk away (`min_enemy_distance` to
## `max_enemy_distance` MP) in the layout's direction. Every attempt is checked for two-way
## connectivity and the enemies' distance; failed attempts draw the next one from the same RNG,
## so the result is still fully determined by the seed.

enum Layout { EDGE, CORNER, AMBUSH }

## The start zone is a 3 x 3 square.
const ZONE_SIZE := 9
const ATTEMPTS := 20


## At most this many enemies can be placed by every layout (CORNER has 6 candidate cells).
const MAX_ENEMIES := 6


## `typology` shapes the board (null: an open field from the settings); `size_range` is the
## width and height range (x to y; zero: the settings', boss floors their `boss_size`).
static func generate(rng: RandomNumberGenerator, settings: MapGenSettings, enemy_count: int, is_boss := false,
		layout := Layout.EDGE, typology: MapTypology = null, size_range := Vector2i.ZERO) -> MapData:
	if enemy_count < 1 or enemy_count > MAX_ENEMIES:
		push_error("MapGenerator: %d enemies (1 to %d supported)" % [enemy_count, MAX_ENEMIES])
		enemy_count = clampi(enemy_count, 1, MAX_ENEMIES)
	if typology == null:
		typology = _settings_typology(settings, is_boss)
	if size_range == Vector2i.ZERO:
		size_range = Vector2i(settings.boss_size, settings.boss_size) if is_boss else Vector2i(settings.min_size, settings.max_size)
	for attempt in ATTEMPTS:
		var map := _attempt(rng, settings, enemy_count, layout, typology, size_range)
		if map != null and is_playable(map, enemy_count, settings.min_enemy_distance):
			return map
	push_warning("MapGenerator: no valid %s %s map in %d attempts; using an open map" % [
			MapTypology.Kind.keys()[typology.kind], Layout.keys()[layout], ATTEMPTS])
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
	for cell in parsed.enemy_spawns:
		if to_zone.get(cell, 0) < min_enemy_distance:
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


## An open field with the settings' own plateaus and densities (no band typology).
static func _settings_typology(settings: MapGenSettings, is_boss: bool) -> MapTypology:
	var typology := MapTypology.new()
	typology.max_height = settings.max_height
	var area := float(settings.boss_size * settings.boss_size) if is_boss else pow((settings.min_size + settings.max_size) / 2.0, 2.0)
	typology.plateaus_per_100_cells = settings.plateaus * 100.0 / area
	typology.obstacle_density = settings.boss_obstacle_density if is_boss else settings.obstacle_density
	typology.hole_density = settings.hole_density
	return typology


## One try: the typology's shape, the zone cleared on it, every piece of ground joined to the
## zone by a bridge, then the enemies a bounded walk away. Null when the enemies don't fit.
static func _attempt(rng: RandomNumberGenerator, settings: MapGenSettings, enemy_count: int, layout: Layout,
		typology: MapTypology, size_range: Vector2i) -> MapData:
	var width := rng.randi_range(size_range.x, size_range.y)
	var height := rng.randi_range(size_range.x, size_range.y)
	if layout == Layout.AMBUSH:
		width = maxi(width, settings.ambush_size)
		height = maxi(height, settings.ambush_size)
	var size := Vector2i(width, height)
	var field := MapShapes.build(rng, typology, size)
	var center := _zone_center(rng, size, layout)
	var zone: Array[Vector2i] = []
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			zone.append(center + Vector2i(dx, dy))
	for cell in zone:
		field.marks[cell.y][cell.x] = ""
	MapShapes.connect_ground(field, center)
	var enemies := _enemy_cells(rng, settings, field, layout, center, zone, enemy_count)
	if enemies.size() < enemy_count:
		return null
	return _to_map(field, zone, enemies)


static func _to_map(field: MapShapes.Field, zone: Array[Vector2i], enemies: Array[Vector2i]) -> MapData:
	var lines: Array[String] = []
	for y in field.size.y:
		var tokens: Array[String] = []
		for x in field.size.x:
			var cell := Vector2i(x, y)
			var token := field.marks[y][x]
			if token == "#" and field.heights[y][x] > 0:
				token = "%d#" % field.heights[y][x]  # A block stands on its plateau, not sunk to level 0.
			if token.is_empty() or cell in zone or cell in enemies:
				token = str(field.heights[y][x])
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


## Enemy spawns: floor cells a bounded walk from the zone (`min_enemy_distance` to
## `max_enemy_distance` MP both ways: climbing costs more than dropping), in the layout's direction
## (in front of the zone for EDGE, along the diagonal toward the far corner for CORNER, anywhere
## for AMBUSH), spread apart: the first at random, then each
## the farthest from those already chosen. Fewer than `count` when the map lacks room.
static func _enemy_cells(rng: RandomNumberGenerator, settings: MapGenSettings, field: MapShapes.Field, layout: Layout,
		center: Vector2i, zone: Array[Vector2i], count: int) -> Array[Vector2i]:
	var grid := field.to_grid()
	var to_zone := Movement.distances_to(grid, zone)
	var from_zone := Movement.distances_from(grid, zone)
	var far_side := -1 if center.x >= field.size.x / 2 else 1
	var candidates: Array[Vector2i] = []
	for y in field.size.y:
		for x in field.size.x:
			var cell := Vector2i(x, y)
			if not grid.is_walkable(cell) or cell in zone:
				continue
			var nearest: int = mini(to_zone.get(cell, -1), from_zone.get(cell, -1))
			var farthest: int = maxi(to_zone.get(cell, -1), from_zone.get(cell, -1))
			if nearest < settings.min_enemy_distance or farthest > settings.max_enemy_distance:
				continue
			match layout:
				Layout.EDGE:
					if cell.y >= center.y - 1:
						continue
				Layout.CORNER:
					# At least half as far across as up: toward the far corner, not above the zone.
					if 2 * (cell.x - center.x) * far_side < center.y - cell.y or cell.y >= center.y - 1:
						continue
			candidates.append(cell)
	var cells: Array[Vector2i] = []
	if candidates.is_empty():
		return cells
	cells.append(candidates[rng.randi_range(0, candidates.size() - 1)])
	while cells.size() < count:
		var best := Vector2i(-1, -1)
		var best_gap := 0
		for cell in candidates:
			if cell in cells:
				continue
			var gap := 1 << 20
			for chosen in cells:
				gap = mini(gap, Targeting.distance(cell, chosen))
			if gap > best_gap:
				best = cell
				best_gap = gap
		if best_gap == 0:
			break  # No candidate left.
		cells.append(best)
	return cells


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
