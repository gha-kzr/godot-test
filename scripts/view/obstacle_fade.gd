class_name ObstacleFade
extends Node
## The see-through fade: an obstacle that really hides a unit from the camera turns into a
## dither of itself, and comes back when it no longer does. The board registers its obstacles (by
## cell, with the meshes that draw them); the battle controller says which ones are in the way
## (found by rays against the obstacles' own collision shapes, see BoardView.look_through).
## Only the look changes: picking and the rules never read this. Materials are copied on first
## use (the board shares them), with alpha hash (dithered), or plain alpha on the web's
## Compatibility renderer.

## How much of an obstacle stays drawn while it is in the way.
const FADED_ALPHA := 0.35
## Fade speed, in full fades per second.
const SPEED := 6.0

var _entries: Dictionary[Vector2i, Entry] = {}


class Entry extends RefCounted:
	var meshes: Array[MeshInstance3D] = []
	## Per mesh: its original material_override, and the faded copies of each surface.
	var originals: Array[Material] = []
	var faded: Array[Array] = []
	var alpha := 1.0
	var goal := 1.0
	var active := false


func clear() -> void:
	_entries.clear()


## The obstacle on `cell`, drawn by `meshes`.
func register(cell: Vector2i, meshes: Array[MeshInstance3D]) -> void:
	var entry := Entry.new()
	entry.meshes = meshes
	_entries[cell] = entry


## Fades the obstacles on `cells` (the ones in the way) and brings the others back.
func fade_only(cells: Array[Vector2i]) -> void:
	for cell in _entries:
		_entries[cell].goal = FADED_ALPHA if cell in cells else 1.0


## Moves every obstacle toward its goal.
func advance(delta: float) -> void:
	for cell in _entries:
		var entry := _entries[cell]
		if is_equal_approx(entry.alpha, entry.goal):
			continue
		entry.alpha = move_toward(entry.alpha, entry.goal, delta * SPEED * (1.0 - FADED_ALPHA))
		_apply(entry)


func _process(delta: float) -> void:
	advance(delta)


## The alpha the obstacle on `cell` is drawn with now (1: solid), for tests and tools.
func alpha_of(cell: Vector2i) -> float:
	return _entries[cell].alpha if _entries.has(cell) else 1.0


func goal_of(cell: Vector2i) -> float:
	return _entries[cell].goal if _entries.has(cell) else 1.0


func count() -> int:
	return _entries.size()


## Dithered alpha (alpha hash) where the renderer supports it; the Compatibility renderer (the web
## build) draws it opaque, so it gets plain alpha blending there.
static func transparency_mode() -> BaseMaterial3D.Transparency:
	if RenderingServer.get_current_rendering_method() == "gl_compatibility":
		return BaseMaterial3D.TRANSPARENCY_ALPHA
	return BaseMaterial3D.TRANSPARENCY_ALPHA_HASH


func _apply(entry: Entry) -> void:
	if entry.alpha >= 0.999:
		if entry.active:
			_restore(entry)
		return
	if entry.faded.is_empty():
		_build_faded(entry)
	if not entry.active:
		_swap_in(entry)
	for surfaces in entry.faded:
		for material: Material in surfaces:
			if material is BaseMaterial3D:
				var color := (material as BaseMaterial3D).albedo_color
				color.a = entry.alpha
				(material as BaseMaterial3D).albedo_color = color


func _build_faded(entry: Entry) -> void:
	for mesh_instance in entry.meshes:
		entry.originals.append(mesh_instance.material_override)
		var surfaces: Array = []
		for surface in mesh_instance.get_surface_override_material_count():
			var base := mesh_instance.get_active_material(surface)
			var copy: Material = null
			if base is BaseMaterial3D:
				copy = base.duplicate() as BaseMaterial3D
				(copy as BaseMaterial3D).transparency = transparency_mode()
			surfaces.append(copy)
		entry.faded.append(surfaces)


func _swap_in(entry: Entry) -> void:
	entry.active = true
	for index in entry.meshes.size():
		var mesh_instance := entry.meshes[index]
		if entry.originals[index] != null:
			# One material over the whole mesh: its single faded copy.
			mesh_instance.material_override = entry.faded[index][0] if not entry.faded[index].is_empty() else null
		else:
			for surface in entry.faded[index].size():
				if entry.faded[index][surface] != null:
					mesh_instance.set_surface_override_material(surface, entry.faded[index][surface])


func _restore(entry: Entry) -> void:
	entry.active = false
	for index in entry.meshes.size():
		var mesh_instance := entry.meshes[index]
		mesh_instance.material_override = entry.originals[index]
		if entry.originals[index] == null:
			for surface in entry.faded[index].size():
				mesh_instance.set_surface_override_material(surface, null)
