@tool
class_name MapShapes
extends RefCounted
## The board's shape for each map typology: a height field and marks ("#" a block, "." a hole,
## "" floor), from the floor's seeded RNG (the noise is seeded from it too), smoothed so every
## step climbs or drops at most one level. connect_ground() then bridges any ground the start
## zone can't walk to, so the playability check rarely has to redraw.


## A shape being built: heights and marks per row.
class Field:
	var size: Vector2i
	var heights: Array[PackedInt32Array] = []
	var marks: Array[PackedStringArray] = []

	func _init(field_size: Vector2i) -> void:
		size = field_size
		for y in size.y:
			var row := PackedInt32Array()
			row.resize(size.x)
			heights.append(row)
			var mark_row := PackedStringArray()
			mark_row.resize(size.x)
			marks.append(mark_row)

	func in_bounds(cell: Vector2i) -> bool:
		return cell.x >= 0 and cell.y >= 0 and cell.x < size.x and cell.y < size.y

	func is_ground(cell: Vector2i) -> bool:
		return in_bounds(cell) and marks[cell.y][cell.x].is_empty()

	## The rules' grid for this field (to measure walking distances).
	func to_grid() -> Grid:
		var flat_heights := PackedInt32Array()
		var types := PackedByteArray()
		for y in size.y:
			for x in size.x:
				flat_heights.append(heights[y][x])
				match marks[y][x]:
					"#": types.append(Grid.CellType.OBSTACLE)
					".": types.append(Grid.CellType.HOLE)
					_: types.append(Grid.CellType.FLOOR)
		return Grid.new(size, flat_heights, types)


static func build(rng: RandomNumberGenerator, typology: MapTypology, size: Vector2i) -> Field:
	var field := Field.new(size)
	var noise := FastNoiseLite.new()
	noise.seed = rng.randi()
	noise.frequency = typology.noise_frequency
	match typology.kind:
		MapTypology.Kind.MOUNTAIN:
			_mountain(rng, field, typology, noise)
		MapTypology.Kind.CRATER:
			_crater(field, typology, noise)
		MapTypology.Kind.ISLANDS:
			_islands(field, typology, noise)
		MapTypology.Kind.CANYON:
			_canyon(rng, field, typology, noise)
		MapTypology.Kind.RUINS:
			_ruins(rng, field, typology, noise)
		_:
			_open_field(rng, field, typology)
	_smooth(field)
	_scatter(rng, field, typology)
	return field


## Plateaus (2 to 5 cells a side) on flat ground.
static func _open_field(rng: RandomNumberGenerator, field: Field, typology: MapTypology) -> void:
	var count := roundi(typology.plateaus_per_100_cells * field.size.x * field.size.y / 100.0)
	for i in count:
		var w := rng.randi_range(2, mini(5, field.size.x))
		var h := rng.randi_range(2, mini(5, field.size.y))
		var x0 := rng.randi_range(0, field.size.x - w)
		var y0 := rng.randi_range(0, field.size.y - h)
		var level := rng.randi_range(1, typology.max_height)
		for y in range(y0, y0 + h):
			for x in range(x0, x0 + w):
				field.heights[y][x] = maxi(field.heights[y][x], level)


## Height falls from a peak (near the centre) to the edges, with noisy ridges.
static func _mountain(rng: RandomNumberGenerator, field: Field, typology: MapTypology, noise: FastNoiseLite) -> void:
	var peak := Vector2(field.size) / 2.0 + Vector2(rng.randf_range(-1.5, 1.5), rng.randf_range(-2.5, -0.5))
	var radius := minf(field.size.x, field.size.y) * 0.6
	for y in field.size.y:
		for x in field.size.x:
			var slope := 1.0 - Vector2(x, y).distance_to(peak) / radius
			var value := typology.max_height * slope + noise.get_noise_2d(x, y) * 1.2
			field.heights[y][x] = clampi(roundi(value), 0, typology.max_height)


## A rim of high ground around a low centre.
static func _crater(field: Field, typology: MapTypology, noise: FastNoiseLite) -> void:
	var center := Vector2(field.size) / 2.0
	var radius := minf(field.size.x, field.size.y) * 0.5
	for y in field.size.y:
		for x in field.size.x:
			var along := Vector2(x, y).distance_to(center) / radius  # 0 centre, ~1 edge.
			var rim := 1.0 - absf(along - 0.7) / 0.35
			var value := typology.max_height * rim + noise.get_noise_2d(x, y) * 0.8
			field.heights[y][x] = clampi(roundi(value), 0, typology.max_height)


## Land where the noise is high enough (`land_share` of the map, about), holes elsewhere; land
## rises a level here and there. connect_ground() lays the bridges.
static func _islands(field: Field, typology: MapTypology, noise: FastNoiseLite) -> void:
	var values: Array[float] = []
	for y in field.size.y:
		for x in field.size.x:
			values.append(noise.get_noise_2d(x, y))
	var sorted := values.duplicate()
	sorted.sort()
	var threshold: float = sorted[clampi(roundi((1.0 - typology.land_share) * sorted.size()), 0, sorted.size() - 1)]
	for y in field.size.y:
		for x in field.size.x:
			var value: float = values[y * field.size.x + x]
			if value < threshold:
				field.marks[y][x] = "."
			else:
				field.heights[y][x] = clampi(floori((value - threshold) * 6.0), 0, typology.max_height)


## A chasm across the map between the two halves, meandering, one or two cells wide, with
## `crossings` bridges; rolling ground on both banks.
static func _canyon(rng: RandomNumberGenerator, field: Field, typology: MapTypology, noise: FastNoiseLite) -> void:
	for y in field.size.y:
		for x in field.size.x:
			field.heights[y][x] = clampi(roundi((noise.get_noise_2d(x, y) + 0.3) * typology.max_height), 0, typology.max_height)
	var middle := field.size.y * 0.45
	var bridge_columns: Array[int] = []
	for i in typology.crossings:
		bridge_columns.append(clampi(roundi((i + 0.5) * field.size.x / float(typology.crossings)) + rng.randi_range(-1, 1), 0, field.size.x - 1))
	for x in field.size.x:
		var row := clampi(roundi(middle + noise.get_noise_2d(x * 3.0, 100.0) * 2.0), 1, field.size.y - 3)
		var width := 2 if noise.get_noise_2d(x * 3.0, 200.0) > 0.0 else 1
		for y in range(row, row + width):
			if x in bridge_columns:
				field.marks[y][x] = ""
				field.heights[y][x] = 0
			else:
				field.marks[y][x] = "."


## Walls of blocks every `room_size` cells, each wall section with a doorway (some sections
## crumbled away), raised floors here and there.
static func _ruins(rng: RandomNumberGenerator, field: Field, typology: MapTypology, noise: FastNoiseLite) -> void:
	var step := typology.room_size
	var offset := Vector2i(rng.randi_range(1, step - 1), rng.randi_range(1, step - 1))
	for y in field.size.y:
		for x in field.size.x:
			field.heights[y][x] = 1 if noise.get_noise_2d(x, y) > 0.35 and typology.max_height >= 1 else 0
	# Vertical walls: every column offset.x + k * step, in sections between horizontal walls.
	for x in range(offset.x, field.size.x, step):
		_wall_sections(rng, field, Vector2i(x, 0), Vector2i(0, 1), field.size.y, step, offset.y)
	for y in range(offset.y, field.size.y, step):
		_wall_sections(rng, field, Vector2i(0, y), Vector2i(1, 0), field.size.x, step, offset.x)


## Lays one wall line from `start` along `direction`, cut into sections at every crossing; each
## section either crumbles (one in five) or gets a doorway.
static func _wall_sections(rng: RandomNumberGenerator, field: Field, start: Vector2i, direction: Vector2i, length: int,
		step: int, section_offset: int) -> void:
	var section_start := 0
	var cuts: Array[int] = []
	for along in range(section_offset, length, step):
		cuts.append(along)
	cuts.append(length)
	for cut in cuts:
		if cut - section_start >= 2 and rng.randf() > 0.2:
			var door := rng.randi_range(section_start, cut - 1)
			for along in range(section_start, cut):
				if along != door:
					var cell := start + direction * along
					field.marks[cell.y][cell.x] = "#"
		section_start = cut + 1


## Rocks and holes sprinkled on the remaining ground.
static func _scatter(rng: RandomNumberGenerator, field: Field, typology: MapTypology) -> void:
	for y in field.size.y:
		for x in field.size.x:
			if not field.marks[y][x].is_empty():
				continue
			var roll := rng.randf()
			if roll < typology.obstacle_density:
				field.marks[y][x] = "#"
			elif roll < typology.obstacle_density + typology.hole_density:
				field.marks[y][x] = "."


## Lowers cells until no two neighbours differ by more than one level (every step climbable).
static func _smooth(field: Field) -> void:
	var changed := true
	while changed:
		changed = false
		for y in field.size.y:
			for x in field.size.x:
				var lowest := field.heights[y][x]
				for offset in Grid.DIRECTIONS:
					var next := Vector2i(x, y) + offset
					if field.in_bounds(next):
						lowest = mini(lowest, field.heights[next.y][next.x])
				if field.heights[y][x] > lowest + 1:
					field.heights[y][x] = lowest + 1
					changed = true


## Every piece of ground cut off from `start` gets a bridge: the shortest line of cells (through
## blocks and holes) from it to the ground already joined becomes floor. Heights are smooth, so
## floor next to floor is always walkable; the result is one connected piece of ground.
static func connect_ground(field: Field, start: Vector2i) -> void:
	var joined := _reachable(field, start)
	for y in field.size.y:
		for x in field.size.x:
			var cell := Vector2i(x, y)
			if field.is_ground(cell) and not joined.has(cell):
				for step in _path_to(field, cell, joined):
					field.marks[step.y][step.x] = ""
				joined = _reachable(field, start)


static func _reachable(field: Field, start: Vector2i) -> Dictionary[Vector2i, bool]:
	var seen: Dictionary[Vector2i, bool] = {start: true}
	var queue: Array[Vector2i] = [start]
	while not queue.is_empty():
		var cell: Vector2i = queue.pop_front()
		for offset in Grid.DIRECTIONS:
			var next := cell + offset
			if field.is_ground(next) and not seen.has(next):
				seen[next] = true
				queue.append(next)
	return seen


## The cells between `from` and the nearest joined cell (breadth-first over the whole grid),
## excluding both ends.
static func _path_to(field: Field, from: Vector2i, joined: Dictionary[Vector2i, bool]) -> Array[Vector2i]:
	var came_from: Dictionary[Vector2i, Vector2i] = {from: from}
	var queue: Array[Vector2i] = [from]
	while not queue.is_empty():
		var cell: Vector2i = queue.pop_front()
		if joined.has(cell):
			var path: Array[Vector2i] = []
			var back: Vector2i = came_from[cell]
			while back != from:
				path.append(back)
				back = came_from[back]
			return path
		for offset in Grid.DIRECTIONS:
			var next := cell + offset
			if field.in_bounds(next) and not came_from.has(next):
				came_from[next] = cell
				queue.append(next)
	return []
