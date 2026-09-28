class_name BoardView
extends Node3D
## Draws a Grid: one column per cell stacked to its height, with a collider tagged with
## its cell for mouse picking, plus highlight overlays. Built from the model; never reads
## or changes battle state on its own.
##
## Picking contract: any collider on BOARD_LAYER or UNITS_LAYER with CELL_META picks that
## cell. Unit views keep their collider's CELL_META on the cell they stand on, so clicking
## a unit's body picks its cell even where the body hides the ground behind it.

## Declared in drawing order: later kinds lie above earlier ones.
enum Highlight { REACH, RANGE_BLOCKED, PATH, RANGE, AREA }

const NO_CELL := Vector2i(-1, -1)
const CELL_SIZE := 1.0
## Physics layer bits, named "board" and "units" in the project settings. Only our own
## picking colliders go on them (strip colliders from asset-pack models).
const BOARD_LAYER := 1
const UNITS_LAYER := 2
const CELL_META := &"cell"
const OBSTACLE_SIZE := Vector3(0.8, 0.9, 0.8)
## Highlights float just above the cell top; later kinds draw above earlier ones.
const HIGHLIGHT_LIFT := 0.02
const HIGHLIGHT_LAYER_GAP := 0.01
const PIT_DEPTH := 2.0

@export var board_theme: BoardTheme

var grid: Grid
var _cells := Node3D.new()
var _highlights := Node3D.new()
var _highlight_groups: Dictionary[Highlight, Node3D] = {}
var _materials: Dictionary[Color, StandardMaterial3D] = {}
var _overlay_materials: Dictionary[Color, StandardMaterial3D] = {}
var _highlight_mesh := PlaneMesh.new()


func _init() -> void:
	_cells.name = "Cells"
	_highlights.name = "Highlights"
	add_child(_cells)
	add_child(_highlights)
	for kind: Highlight in Highlight.values():
		var group := Node3D.new()
		group.name = Highlight.keys()[kind].to_pascal_case()
		_highlights.add_child(group)
		_highlight_groups[kind] = group
	_highlight_mesh.size = Vector2.ONE * CELL_SIZE * 0.9


## Rebuilds every cell for `board_grid`, clearing highlights.
func build(board_grid: Grid) -> void:
	if board_theme == null:
		board_theme = BoardTheme.new()
	grid = board_grid
	for child in _cells.get_children():
		child.free()
	clear_highlights()
	for y in grid.size.y:
		for x in grid.size.x:
			var cell := Vector2i(x, y)
			match grid.type_at(cell):
				Grid.CellType.FLOOR:
					_add_column(cell, false)
				Grid.CellType.OBSTACLE:
					_add_column(cell, true)
	_add_pit()


## Top center of a cell in local space: where units stand and highlights lie.
func cell_to_world(cell: Vector2i) -> Vector3:
	return Vector3(cell.x * CELL_SIZE, grid.height_at(cell) * board_theme.level_height, cell.y * CELL_SIZE)


## Center of the board at height 0, for the camera to orbit.
func center() -> Vector3:
	return Vector3((grid.size.x - 1) * CELL_SIZE / 2.0, 0.0, (grid.size.y - 1) * CELL_SIZE / 2.0)


## The cell under a screen position (a unit's body counts as its cell), or NO_CELL.
## Casts an explicit physics ray against the board and unit layers. Colliders exist only
## after a physics frame, so picking right after build() finds nothing. Call it from the
## main thread (input or physics callbacks).
func pick_cell(camera: Camera3D, screen_position: Vector2) -> Vector2i:
	var origin := camera.project_ray_origin(screen_position)
	var query := PhysicsRayQueryParameters3D.create(origin,
			origin + camera.project_ray_normal(screen_position) * camera.far, BOARD_LAYER | UNITS_LAYER)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return NO_CELL
	return cell_from_collider(hit.collider)


func cell_from_collider(collider: Object) -> Vector2i:
	if collider == null or not collider.has_meta(CELL_META):
		return NO_CELL
	return collider.get_meta(CELL_META)


## Shows `cells` as the given kind, replacing what that kind showed before.
func show_highlight(kind: Highlight, cells: Array[Vector2i]) -> void:
	clear_highlight(kind)
	var group := _highlight_groups[kind]
	var material := _material(_highlight_color(kind), true)
	for cell in cells:
		var overlay := MeshInstance3D.new()
		overlay.mesh = _highlight_mesh
		overlay.material_override = material
		overlay.position = cell_to_world(cell) + Vector3.UP * (HIGHLIGHT_LIFT + kind * HIGHLIGHT_LAYER_GAP)
		group.add_child(overlay)


func clear_highlight(kind: Highlight) -> void:
	for child in _highlight_groups[kind].get_children():
		child.free()


func clear_highlights() -> void:
	for kind: Highlight in Highlight.values():
		clear_highlight(kind)


func highlighted_count(kind: Highlight) -> int:
	return _highlight_groups[kind].get_child_count()


func _add_column(cell: Vector2i, is_obstacle: bool) -> void:
	var top := grid.height_at(cell) * board_theme.level_height
	var bottom := -board_theme.base_thickness
	var body := StaticBody3D.new()
	body.name = "Cell_%d_%d" % [cell.x, cell.y]
	body.collision_layer = BOARD_LAYER
	body.collision_mask = 0
	body.set_meta(CELL_META, cell)
	body.position = Vector3(cell.x * CELL_SIZE, 0.0, cell.y * CELL_SIZE)
	_cells.add_child(body)

	if board_theme.floor_scene != null and not is_obstacle:
		var model := board_theme.floor_scene.instantiate() as Node3D
		model.position.y = top
		body.add_child(model)
	else:
		var fill := CELL_SIZE * board_theme.block_fill
		var column := _box(Vector3(fill, top - bottom, fill), (top + bottom) / 2.0, _floor_color(cell))
		column.name = "Column"
		body.add_child(column)

	var collider_top := top
	if is_obstacle:
		if board_theme.obstacle_scene != null:
			var model := board_theme.obstacle_scene.instantiate() as Node3D
			model.position.y = top
			body.add_child(model)
		else:
			var block := _box(OBSTACLE_SIZE, top + OBSTACLE_SIZE.y / 2.0, board_theme.obstacle_color)
			block.name = "Obstacle"
			body.add_child(block)
		collider_top = top + OBSTACLE_SIZE.y

	# The collider fills the whole cell (no gaps), so every pixel of the board picks a cell.
	var shape := BoxShape3D.new()
	shape.size = Vector3(CELL_SIZE, collider_top - bottom, CELL_SIZE)
	var collision := CollisionShape3D.new()
	collision.name = "Collision"
	collision.shape = shape
	collision.position.y = (collider_top + bottom) / 2.0
	body.add_child(collision)


func _add_pit() -> void:
	var pit := _box(Vector3(grid.size.x * CELL_SIZE + 2.0, 0.1, grid.size.y * CELL_SIZE + 2.0),
			-board_theme.base_thickness - PIT_DEPTH, board_theme.pit_color)
	pit.name = "Pit"
	pit.position.x = center().x
	pit.position.z = center().z
	_cells.add_child(pit)


func _box(size: Vector3, center_y: float, color: Color) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = _material(color, false)
	instance.position.y = center_y
	return instance


func _floor_color(cell: Vector2i) -> Color:
	return board_theme.floor_color.lightened(grid.height_at(cell) * board_theme.lighten_per_level)


func _highlight_color(kind: Highlight) -> Color:
	match kind:
		Highlight.REACH: return board_theme.reach_color
		Highlight.PATH: return board_theme.path_color
		Highlight.RANGE: return board_theme.range_color
		Highlight.RANGE_BLOCKED: return board_theme.range_blocked_color
		_: return board_theme.area_color


## One shared material per color (and kind), so the board batches well.
func _material(color: Color, overlay: bool) -> StandardMaterial3D:
	var cache := _overlay_materials if overlay else _materials
	if cache.has(color):
		return cache[color]
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	if overlay:
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
	cache[color] = material
	return material
