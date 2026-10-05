class_name ModelKit
extends RefCounted
## Builds a low-poly unit model out of a few flat-shaded solids on a tree of joints, then saves
## it as a scene a `UnitData.model_scene` can use.
##
## A model is a root `Model` node (faces +Z, feet on y = 0), joints (plain `Node3D`s that the
## animations turn, named after the body part: "Arm.R", "Head") and parts (`MeshInstance3D`s,
## one solid each). All meshes are flat-shaded, with one shared material per color.
## Solids (all built around their own center unless noted):
##   prism(): a rectangle / n-gon section that tapers, a cone or a pyramid (limbs, torsos, hats)
##   blob(): a low-poly ellipsoid (heads, caps, hands)
##   wedge(): a triangular ramp (ears, fins, blades)

## The battle's light is bright: a color given to part() is how it should look on screen, and
## the material's albedo is that times this.
const ALBEDO_FACTOR := 0.62

var root: Node3D
## Every joint by the name it was given ("Arm.L"; the node itself is "Arm_L").
var joints: Dictionary[String, Node3D] = {}

var _materials: Dictionary[String, StandardMaterial3D] = {}


func _init(model_name := "Model") -> void:
	root = Node3D.new()
	root.name = model_name


## A joint (a pivot) under `parent` (null: the root). Names are unique per model.
func joint(parent: Node3D, joint_name: String, position := Vector3.ZERO, rotation_degrees := Vector3.ZERO) -> Node3D:
	var node := Node3D.new()
	node.name = joint_name.validate_node_name()  # "Arm.L" becomes "Arm_L": nodes can't have dots.
	node.position = position
	node.rotation_degrees = rotation_degrees
	(parent if parent != null else root).add_child(node)
	joints[joint_name] = node
	return node


## A solid under `parent`, in the flat color `color` (as it should look on screen).
func part(parent: Node3D, part_name: String, mesh: Mesh, color: Color, position := Vector3.ZERO,
		rotation_degrees := Vector3.ZERO, emissive := 0.0) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = part_name.validate_node_name()
	instance.mesh = mesh
	instance.position = position
	instance.rotation_degrees = rotation_degrees
	instance.material_override = material(color, emissive)
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	(parent if parent != null else root).add_child(instance)
	return instance


func material(color: Color, emissive := 0.0) -> StandardMaterial3D:
	var key := "%s|%s" % [color.to_html(), emissive]
	if not _materials.has(key):
		var made := StandardMaterial3D.new()
		made.albedo_color = Color(color.r * ALBEDO_FACTOR, color.g * ALBEDO_FACTOR, color.b * ALBEDO_FACTOR, color.a)
		made.roughness = 0.85
		made.metallic = 0.0
		if emissive > 0.0:
			made.emission_enabled = true
			made.emission = color
			made.emission_energy_multiplier = emissive
		_materials[key] = made
	return _materials[key]


## Saves the model as a scene at `path`: owners set, the AnimationPlayer (if any) included.
## A rebuilt model keeps its UID (the unit files refer to it); a new one gets one.
func save(path: String) -> Error:
	_own(root, root)
	var scene := PackedScene.new()
	var error := scene.pack(root)
	if error != OK:
		return error
	var uid := ResourceLoader.get_resource_uid(path)
	error = ResourceSaver.save(scene, path)
	if error != OK:
		return error
	if uid == ResourceUID.INVALID_ID:
		uid = ResourceUID.create_id()
		ResourceUID.add_id(uid, path)
	elif ResourceUID.has_id(uid):
		ResourceUID.set_id(uid, path)
	else:
		ResourceUID.add_id(uid, path)
	ResourceSaver.set_uid(path, uid)
	return OK


func _own(node: Node, owner_: Node) -> void:
	for child in node.get_children():
		child.owner = owner_
		_own(child, owner_)


# --- Solids --------------------------------------------------------------------------------

## An `sides`-sided solid along Y, centered on its origin: `bottom` and `top` are the half
## extents (x, z) at each end (a flat side at that distance from the axis, so sides = 4 is a
## box of size 2 * extent). A zero end makes a cone / pyramid. `top_offset` slides the top end.
static func prism(sides: int, bottom: Vector2, top: Vector2, height: float, top_offset := Vector2.ZERO) -> ArrayMesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var k := 1.0 / cos(PI / sides)
	var low: Array[Vector3] = []
	var high: Array[Vector3] = []
	for i in sides:
		var angle := (i + 0.5) * TAU / sides
		var direction := Vector2(sin(angle), cos(angle)) * k
		low.append(Vector3(direction.x * bottom.x, -height * 0.5, direction.y * bottom.y))
		high.append(Vector3(direction.x * top.x + top_offset.x, height * 0.5, direction.y * top.y + top_offset.y))
	for i in sides:
		var j := (i + 1) % sides
		_quad(tool, low[i], low[j], high[j], high[i])
	_fan(tool, low, Vector3(0, -height * 0.5, 0), true)
	_fan(tool, high, Vector3(top_offset.x, height * 0.5, top_offset.y), false)
	return tool.commit()


## A box of `size`.
static func box(size: Vector3) -> ArrayMesh:
	return prism(4, Vector2(size.x, size.z) * 0.5, Vector2(size.x, size.z) * 0.5, size.y)


## A low-poly ellipsoid with the given half extents: `segments` around, `rings` pole to pole.
static func blob(radius: Vector3, segments := 8, rings := 4) -> ArrayMesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rows: Array = []
	for r in rings + 1:
		var latitude := PI * r / rings
		var ring: Array[Vector3] = []
		var count := 1 if r == 0 or r == rings else segments
		for s in count:
			var longitude := (s + 0.5) * TAU / segments
			ring.append(Vector3(sin(latitude) * sin(longitude) * radius.x, cos(latitude) * radius.y,
					sin(latitude) * cos(longitude) * radius.z))
		rows.append(ring)
	for r in rings:
		var upper: Array = rows[r]
		var lower: Array = rows[r + 1]
		for s in segments:
			var t := (s + 1) % segments
			if r == 0:
				_tri(tool, upper[0], lower[s], lower[t])
			elif r == rings - 1:
				_tri(tool, upper[s], lower[0], upper[t])
			else:
				_quad(tool, upper[s], lower[s], lower[t], upper[t])
	return tool.commit()


## A triangular ramp: a `width` x `depth` base on the bottom, rising to a ridge `height` high at
## the back edge (z = -depth / 2) when `lean` is 0, at the front edge when 1, in between for 0.5.
## Ears, fins, a plume, a blade's point.
static func wedge(width: float, height: float, depth: float, lean := 0.5) -> ArrayMesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var half := width * 0.5
	var front := depth * 0.5
	var back := -depth * 0.5
	var top_z := back + depth * lean
	var a := Vector3(-half, -height * 0.5, back)
	var b := Vector3(half, -height * 0.5, back)
	var c := Vector3(half, -height * 0.5, front)
	var d := Vector3(-half, -height * 0.5, front)
	var e := Vector3(-half, height * 0.5, top_z)
	var f := Vector3(half, height * 0.5, top_z)
	_quad(tool, a, b, c, d)  # Bottom.
	_quad(tool, e, f, b, a)  # Back.
	_quad(tool, f, e, d, c)  # Front.
	_tri(tool, a, d, e)  # Left end.
	_tri(tool, b, f, c)  # Right end.
	return tool.commit()


# --- Triangles -----------------------------------------------------------------------------

## A triangle a, b, c given counter-clockwise seen from outside; flat normal.
static func _tri(tool: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
	var normal := (b - a).cross(c - a)
	if normal.length_squared() < 0.0000001:
		return  # A collapsed triangle (the tip of a cone).
	normal = normal.normalized()
	# Godot's front face is clockwise, so the vertices go out reversed.
	for vertex in [a, c, b]:
		tool.set_normal(normal)
		tool.add_vertex(vertex)


static func _quad(tool: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
	_tri(tool, a, b, c)
	_tri(tool, a, c, d)


## A polygon closed with a fan to `center`; `down` when it faces down.
static func _fan(tool: SurfaceTool, ring: Array[Vector3], center: Vector3, down: bool) -> void:
	for i in ring.size():
		var j := (i + 1) % ring.size()
		if down:
			_tri(tool, center, ring[j], ring[i])
		else:
			_tri(tool, center, ring[i], ring[j])
