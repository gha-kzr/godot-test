@tool
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
enum Highlight { ZONE, REACH, RANGE_BLOCKED, PATH, RANGE, AREA }

const NO_CELL := Vector2i(-1, -1)
const CELL_SIZE := 1.0
## Physics layer bits, named "board" and "units" in the project settings. Only our own
## picking colliders go on them (strip colliders from asset-pack models).
const BOARD_LAYER := 1
const UNITS_LAYER := 2
const CELL_META := &"cell"
## Highlights float just above the cell top; later kinds draw above earlier ones.
const HIGHLIGHT_LIFT := 0.02
const HIGHLIGHT_LAYER_GAP := 0.01
const PIT_DEPTH := 2.0
const NOISE_SIZE := 16
## Path cost labels: height above the cell, size, and colors (total, climbing steps).
const PATH_LABEL_HEIGHT := 0.9
const PATH_LABEL_PIXEL_SIZE := 0.008
const PATH_TOTAL_COLOR := Color(1.0, 1.0, 1.0)
const PATH_CLIMB_COLOR := Color(1.0, 0.75, 0.25)

@export var board_theme: BoardTheme
## Editor only: a map drawn in the 3D viewport so the scene isn't empty, rebuilt live when
## the map's layout changes. At runtime the battle builds the real board instead.
@export var preview_map: MapData:
	set(value):
		if preview_map != null and preview_map.changed.is_connected(show_preview):
			preview_map.changed.disconnect(show_preview)
		preview_map = value
		if preview_map != null and Engine.is_editor_hint():
			preview_map.changed.connect(show_preview)
		if Engine.is_editor_hint() and is_inside_tree():
			show_preview()

var grid: Grid
## Used when board_theme is empty; never written to the export, so the editor preview
## doesn't save a theme into the scene.
var _default_theme := BoardTheme.new()
var _cells := Node3D.new()
var _highlights := Node3D.new()
var _highlight_groups: Dictionary[Highlight, Node3D] = {}
var _materials: Dictionary[Color, StandardMaterial3D] = {}
var _overlay_materials: Dictionary[Color, StandardMaterial3D] = {}
var _highlight_mesh := PlaneMesh.new()
var _noise: ImageTexture
var _noise_strength := -1.0
var _path_labels := Node3D.new()


func _init() -> void:
	_cells.name = "Cells"
	_highlights.name = "Highlights"
	add_child(_cells)
	add_child(_highlights)
	_path_labels.name = "PathLabels"
	add_child(_path_labels)
	for kind: Highlight in Highlight.values():
		var group := Node3D.new()
		group.name = Highlight.keys()[kind].to_pascal_case()
		_highlights.add_child(group)
		_highlight_groups[kind] = group
	_highlight_mesh.size = Vector2.ONE * CELL_SIZE * 0.9


func _ready() -> void:
	if Engine.is_editor_hint():
		show_preview()


## Draws `preview_map` (the generated nodes have no owner, so they're never saved into the
## scene). Clears the board when there's no valid map.
func show_preview() -> void:
	if preview_map == null:
		_clear_cells()
		return
	var parsed := preview_map.parse()
	if parsed.grid != null:
		build(parsed.grid)


func _clear_cells() -> void:
	for child in _cells.get_children():
		child.free()
	grid = null


## Rebuilds every cell for `board_grid`, clearing highlights.
func build(board_grid: Grid) -> void:
	grid = board_grid
	for child in _cells.get_children():
		child.free()
	clear_highlights()
	clear_path_cost()
	for y in grid.size.y:
		for x in grid.size.x:
			var cell := Vector2i(x, y)
			match grid.type_at(cell):
				Grid.CellType.FLOOR:
					_add_column(cell, false)
				Grid.CellType.OBSTACLE:
					_add_column(cell, true)
	_add_pit()


## The theme in use: board_theme, or the defaults.
func active_theme() -> BoardTheme:
	return board_theme if board_theme != null else _default_theme


## Top center of a cell in local space: where units stand and highlights lie.
func cell_to_world(cell: Vector2i) -> Vector3:
	return Vector3(cell.x * CELL_SIZE, grid.height_at(cell) * active_theme().level_height, cell.y * CELL_SIZE)


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


## Labels the hovered path: its total MP over the destination and "+n" over each climbing
## step (`climbs`: cell → extra MP). Replaces the previous labels.
func show_path_cost(destination: Vector2i, total_mp: int, climbs: Dictionary[Vector2i, int]) -> void:
	clear_path_cost()
	_path_labels.add_child(_cost_label("Total", "%d MP" % total_mp, destination, PATH_TOTAL_COLOR, PATH_LABEL_HEIGHT))
	for cell in climbs:
		_path_labels.add_child(_cost_label("Climb", "+%d" % climbs[cell], cell, PATH_CLIMB_COLOR, PATH_LABEL_HEIGHT * 0.6))


func clear_path_cost() -> void:
	for child in _path_labels.get_children():
		child.free()


## The path labels' texts, total first ("" parts omitted), e.g. ["4 MP", "+1"].
func path_cost_texts() -> Array[String]:
	var texts: Array[String] = []
	for child in _path_labels.get_children():
		texts.append((child as Label3D).text)
	return texts


func _cost_label(label_name: String, text: String, cell: Vector2i, color: Color, height: float) -> Label3D:
	var label := Label3D.new()
	label.name = label_name
	label.text = text
	label.modulate = color
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.fixed_size = false
	label.pixel_size = PATH_LABEL_PIXEL_SIZE
	label.font_size = 48
	label.outline_size = 14
	label.render_priority = 2
	label.position = cell_to_world(cell) + Vector3.UP * height
	return label


func clear_highlights() -> void:
	for kind: Highlight in Highlight.values():
		clear_highlight(kind)
	clear_path_cost()


func highlighted_count(kind: Highlight) -> int:
	return _highlight_groups[kind].get_child_count()


func _add_column(cell: Vector2i, is_obstacle: bool) -> void:
	var top := grid.height_at(cell) * active_theme().level_height
	var bottom := -active_theme().base_thickness
	var body := StaticBody3D.new()
	body.name = "Cell_%d_%d" % [cell.x, cell.y]
	body.collision_layer = BOARD_LAYER
	body.collision_mask = 0
	body.set_meta(CELL_META, cell)
	body.position = Vector3(cell.x * CELL_SIZE, 0.0, cell.y * CELL_SIZE)
	_cells.add_child(body)

	if active_theme().floor_scene != null and not is_obstacle:
		var model := active_theme().floor_scene.instantiate() as Node3D
		model.position.y = top
		body.add_child(model)
	else:
		var fill := CELL_SIZE * active_theme().block_fill
		var column := _box(Vector3(fill, top - bottom, fill), (top + bottom) / 2.0, _floor_color(cell))
		column.name = "Column"
		body.add_child(column)

	var collider_top := top
	if is_obstacle:
		# The rules' own height (Grid.obstacle_levels): what is drawn is what blocks sight.
		var block_height := grid.obstacle_levels(cell) * active_theme().level_height
		var fill_width := CELL_SIZE * active_theme().block_fill
		if not active_theme().obstacle_scenes.is_empty():
			var scenes := active_theme().obstacle_scenes
			body.add_child(_fitted_model(scenes[posmod(hash(cell), scenes.size())], top, fill_width, block_height))
		else:
			var block := _box(Vector3(fill_width, block_height, fill_width), top + block_height / 2.0, active_theme().obstacle_color)
			block.name = "Obstacle"
			body.add_child(block)
		collider_top = top + block_height

	# The collider fills the whole cell (no gaps), so every pixel of the board picks a cell.
	var shape := BoxShape3D.new()
	shape.size = Vector3(CELL_SIZE, collider_top - bottom, CELL_SIZE)
	var collision := CollisionShape3D.new()
	collision.name = "Collision"
	collision.shape = shape
	collision.position.y = (collider_top + bottom) / 2.0
	body.add_child(collision)


## `scene` stretched to exactly `width` × `height` × `width`, standing with its base centered at
## height `base` on the cell.
func _fitted_model(scene: PackedScene, base: float, width: float, height: float) -> Node3D:
	var wrapper := Node3D.new()
	wrapper.name = "Obstacle"
	var model := scene.instantiate() as Node3D
	wrapper.add_child(model)
	var bounds := model_bounds(model)
	var size := Vector3(maxf(bounds.size.x, 0.0001), maxf(bounds.size.y, 0.0001), maxf(bounds.size.z, 0.0001))
	model.position -= Vector3(bounds.get_center().x, bounds.position.y, bounds.get_center().z)  # Keeps the model's own origin.
	wrapper.scale = Vector3(width / size.x, height / size.y, width / size.z)
	wrapper.position.y = base
	return wrapper


## The box around every mesh of a static model, in the model's parent space.
static func model_bounds(root: Node3D) -> AABB:
	var box := AABB()
	var first := true
	var stack: Array = [[root, root.transform]]
	while not stack.is_empty():
		var entry: Array = stack.pop_back()
		var node := entry[0] as Node3D
		var xform := entry[1] as Transform3D
		if node is MeshInstance3D:
			var mesh_box := xform * (node as MeshInstance3D).get_aabb()
			box = mesh_box if first else box.merge(mesh_box)
			first = false
		for child in node.get_children():
			if child is Node3D:
				stack.append([child, xform * (child as Node3D).transform])
	return box


func _add_pit() -> void:
	var pit := _box(Vector3(grid.size.x * CELL_SIZE + 2.0, 0.1, grid.size.y * CELL_SIZE + 2.0),
			-active_theme().base_thickness - PIT_DEPTH, active_theme().pit_color)
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
	return active_theme().floor_color.lightened(grid.height_at(cell) * active_theme().lighten_per_level)


func _highlight_color(kind: Highlight) -> Color:
	match kind:
		Highlight.ZONE: return active_theme().zone_color
		Highlight.REACH: return active_theme().reach_color
		Highlight.PATH: return active_theme().path_color
		Highlight.RANGE: return active_theme().range_color
		Highlight.RANGE_BLOCKED: return active_theme().range_blocked_color
		_: return active_theme().area_color


## One shared material per color (and kind), so the board batches well.
## A small grayscale speckle around white, multiplied with the terrain colors (one per strength).
func _noise_texture(strength: float) -> ImageTexture:
	if _noise != null and is_equal_approx(_noise_strength, strength):
		return _noise
	var rng := RandomNumberGenerator.new()
	rng.seed = 11  # The same speckle on every run.
	var image := Image.create(NOISE_SIZE, NOISE_SIZE, false, Image.FORMAT_RGB8)
	for y in NOISE_SIZE:
		for x in NOISE_SIZE:
			var shade := 1.0 - rng.randf() * strength
			image.set_pixel(x, y, Color(shade, shade, shade))
	_noise = ImageTexture.create_from_image(image)
	_noise_strength = strength
	return _noise


## One shared material per color (and kind), so the board batches well.
func _material(color: Color, overlay: bool) -> StandardMaterial3D:
	var cache := _overlay_materials if overlay else _materials
	if cache.has(color):
		return cache[color]
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	if not overlay:
		if active_theme().toon:
			material.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
			material.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
		if active_theme().noise_strength > 0.0:
			material.albedo_texture = _noise_texture(active_theme().noise_strength)
			material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	if overlay:
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
	cache[color] = material
	return material
