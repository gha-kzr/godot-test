extends RefCounted
## Medium-poly solids for ModelKit.part(): finer than prism / blob / wedge. All return an
## ArrayMesh built from triangles given counter-clockwise seen from outside (like ModelKit._tri).
## `smooth` averages the normals of faces that share a position (cloth, skin), otherwise every
## face is flat (carved stone, crystals).
##   ellipsoid(): a UV ellipsoid; `jitter` > 0 roughens it into a carved chunk (muscles, rocks)
##   lathe(): a surface of revolution from a profile of (radius, y); `wobble` adds folds
##   sweep() / tube() / band(): a section moved along a path (arms, veins, cloth, trim)
##   crystal(): a pointed hexagonal prism


static func ellipsoid(radius: Vector3, segments := 14, rings := 9, jitter := 0.0, seed_ := 0, smooth := true) -> ArrayMesh:
	var rows: Array = []
	for r in rings + 1:
		var latitude := PI * r / rings
		var ring: Array[Vector3] = []
		var count := 1 if r == 0 or r == rings else segments
		for s in count:
			var longitude := s * TAU / segments
			var scale := 1.0
			if jitter > 0.0 and r > 0 and r < rings:
				scale += jitter * (_noise(r, s, seed_) * 2.0 - 1.0)
			ring.append(Vector3(sin(latitude) * sin(longitude) * radius.x, cos(latitude) * radius.y,
					sin(latitude) * cos(longitude) * radius.z) * scale)
		rows.append(ring)
	var tris: Array = []
	for r in rings:
		var upper: Array = rows[r]
		var lower: Array = rows[r + 1]
		for s in segments:
			var t := (s + 1) % segments
			if r == 0:
				tris.append([upper[0], lower[s], lower[t]])
			elif r == rings - 1:
				tris.append([upper[s], lower[0], upper[t]])
			else:
				tris.append([upper[s], lower[s], lower[t]])
				tris.append([upper[s], lower[t], upper[t]])
	return _mesh(tris, smooth)


## `profile`: Vector2(radius, y) points from the bottom up. `wobble(angle, y) -> float` scales the
## radius (folds). A first / last radius above zero closes that end with a flat cap.
static func lathe(profile: Array, segments := 16, smooth := true, wobble := Callable()) -> ArrayMesh:
	var rings: Array = []
	for point: Vector2 in profile:
		var ring: Array[Vector3] = []
		for s in segments:
			var angle := s * TAU / segments
			var radius := point.x * (float(wobble.call(angle, point.y)) if wobble.is_valid() else 1.0)
			ring.append(Vector3(sin(angle) * radius, point.y, cos(angle) * radius))
		rings.append(ring)
	var tris: Array = []
	for i in rings.size() - 1:
		var low: Array = rings[i]
		var high: Array = rings[i + 1]
		for s in segments:
			var t := (s + 1) % segments
			tris.append([low[s], low[t], high[t]])
			tris.append([low[s], high[t], high[s]])
	var bottom: Array = rings[0]
	var top: Array = rings[rings.size() - 1]
	if (profile[0] as Vector2).x > 0.0:
		var center := Vector3(0, (profile[0] as Vector2).y, 0)
		for s in segments:
			tris.append([center, bottom[(s + 1) % segments], bottom[s]])
	if (profile[profile.size() - 1] as Vector2).x > 0.0:
		var center := Vector3(0, (profile[profile.size() - 1] as Vector2).y, 0)
		for s in segments:
			tris.append([center, top[s], top[(s + 1) % segments]])
	return _mesh(tris, smooth)


## A circle of `radii[i]` swept along `points` (one radius per point), `sides` around.
static func tube(points: Array, radii: Array, sides := 8, smooth := true, caps := true) -> ArrayMesh:
	var sections: Array = []
	for radius: float in radii:
		var polygon: Array[Vector2] = []
		for s in sides:
			var angle := s * TAU / sides
			polygon.append(Vector2(cos(angle), sin(angle)) * radius)
		sections.append(polygon)
	return sweep(points, sections, Vector3.UP, smooth, caps)


## A flat strip `widths[i]` wide and `thickness` thick swept along `points`; `up` orients the
## width (the strip's side is up x tangent).
static func band(points: Array, widths: Array, thickness: float, up := Vector3.UP, smooth := false) -> ArrayMesh:
	var sections: Array = []
	for width: float in widths:
		var half := Vector2(width * 0.5, thickness * 0.5)
		sections.append([Vector2(-half.x, -half.y), Vector2(half.x, -half.y), Vector2(half.x, half.y), Vector2(-half.x, half.y)] as Array[Vector2])
	return sweep(points, sections, up, smooth, true)


## `sections[i]`: the polygon (Vector2 in the frame side / normal) at `points[i]`; all polygons
## have the same number of corners.
static func sweep(points: Array, sections: Array, up := Vector3.UP, smooth := true, caps := true) -> ArrayMesh:
	var rings: Array = []
	var count := points.size()
	for i in count:
		var tangent: Vector3 = ((points[mini(i + 1, count - 1)] as Vector3) - (points[maxi(i - 1, 0)] as Vector3)).normalized()
		var side := up.cross(tangent)
		if side.length() < 0.001:
			side = Vector3.RIGHT.cross(tangent)
		side = side.normalized()
		var normal := tangent.cross(side).normalized()
		var ring: Array[Vector3] = []
		for corner: Vector2 in sections[i]:
			ring.append((points[i] as Vector3) + side * corner.x + normal * corner.y)
		rings.append(ring)
	var corners := (sections[0] as Array).size()
	var tris: Array = []
	for i in count - 1:
		var low: Array = rings[i]
		var high: Array = rings[i + 1]
		for k in corners:
			var n := (k + 1) % corners
			tris.append([low[k], low[n], high[n]])
			tris.append([low[k], high[n], high[k]])
	if caps:
		var first: Array = rings[0]
		var last: Array = rings[count - 1]
		var first_center: Vector3 = points[0]
		var last_center: Vector3 = points[count - 1]
		for k in corners:
			var n := (k + 1) % corners
			tris.append([first_center, first[n], first[k]])
			tris.append([last_center, last[k], last[n]])
	# The winding of the section decides which way the strip faces: make it face outward.
	var middle := Vector3.ZERO
	for point: Vector3 in points:
		middle += point
	var probe: Array = tris[0]
	var outward := ((probe[0] as Vector3) + (probe[1] as Vector3) + (probe[2] as Vector3)) / 3.0 - (points[0] as Vector3)
	var face := ((probe[1] as Vector3) - (probe[0] as Vector3)).cross((probe[2] as Vector3) - (probe[0] as Vector3))
	if face.dot(outward) < 0.0:
		var flipped: Array = []
		for tri: Array in tris:
			flipped.append([tri[0], tri[2], tri[1]])
		tris = flipped
	return _mesh(tris, smooth)


## A pointed crystal along +Y centered on the origin: a `sides`-sided column of `radius` with
## a tip of `tip` * height on top and a short point below. `skew` leans the top point.
static func crystal(radius: float, height: float, tip := 0.35, sides := 6, skew := Vector2.ZERO) -> ArrayMesh:
	var body_top := height * (0.5 - tip)
	var body_bottom := -height * 0.5 + height * 0.12
	var low: Array[Vector3] = []
	var high: Array[Vector3] = []
	for s in sides:
		var angle := (s + 0.5) * TAU / sides
		var x := sin(angle) * radius
		var z := cos(angle) * radius
		low.append(Vector3(x, body_bottom, z))
		high.append(Vector3(x * 0.9, body_top, z * 0.9))
	var apex := Vector3(skew.x, height * 0.5, skew.y)
	var foot := Vector3(0, -height * 0.5, 0)
	var tris: Array = []
	for s in sides:
		var t := (s + 1) % sides
		tris.append([low[s], low[t], high[t]])
		tris.append([low[s], high[t], high[s]])
		tris.append([high[s], high[t], apex])
		tris.append([low[t], low[s], foot])
	return _mesh(tris, false)


# --- Mesh building ----------------------------------------------------------------------------

static func _noise(a: int, b: int, seed_: int) -> float:
	return fposmod(sin(a * 12.9898 + b * 78.233 + seed_ * 37.719) * 43758.5453, 1.0)


## `tris`: [a, b, c] counter-clockwise seen from outside. Godot's front face is clockwise, so the
## vertices go out reversed; normals are the face's (flat) or the area-weighted average of the
## faces sharing the position (smooth).
static func _mesh(tris: Array, smooth: bool) -> ArrayMesh:
	var sums: Dictionary[Vector3i, Vector3] = {}
	if smooth:
		for tri: Array in tris:
			var normal := ((tri[1] as Vector3) - (tri[0] as Vector3)).cross((tri[2] as Vector3) - (tri[0] as Vector3))
			for vertex: Vector3 in tri:
				var key := _key(vertex)
				sums[key] = sums.get(key, Vector3.ZERO) + normal
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for tri: Array in tris:
		var face := ((tri[1] as Vector3) - (tri[0] as Vector3)).cross((tri[2] as Vector3) - (tri[0] as Vector3))
		if face.length_squared() < 0.0000001:
			continue
		for index in [0, 2, 1]:
			var vertex: Vector3 = tri[index]
			var normal: Vector3 = sums[_key(vertex)] if smooth else face
			tool.set_normal(normal.normalized() if normal.length_squared() > 0.0 else face.normalized())
			tool.add_vertex(vertex)
	return tool.commit()


static func _key(vertex: Vector3) -> Vector3i:
	return Vector3i((vertex * 10000.0).round())
