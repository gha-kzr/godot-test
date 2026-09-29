extends SceneTree
## Writes .tres / .tscn files the way the editor would, for files made from the CLI:
## gives each file a UID if it has none, and adds uid="..." to every ext_resource line
## that only has a path. Run after generating or hand-editing resources, so opening the
## editor doesn't rewrite them (no formatting-only diffs in git):
##   godot --headless --script res://tools/fill_uid_refs.gd

const ROOTS: Array[String] = ["res://data", "res://scenes"]


func _initialize() -> void:
	var files := _resource_files()
	var headers := 0
	for path in files:
		if ResourceLoader.get_resource_uid(path) == ResourceUID.INVALID_ID:
			var id := ResourceUID.create_id()
			ResourceSaver.set_uid(path, id)
			ResourceUID.add_id(id, path)
			headers += 1
	var references := 0
	for path in files:
		references += _fill_references(path)
	print("fill_uid_refs: %d file UIDs added, %d references filled" % [headers, references])
	quit()


func _resource_files() -> Array[String]:
	var files: Array[String] = []
	var dirs: Array[String] = ROOTS.duplicate()
	while not dirs.is_empty():
		var dir: String = dirs.pop_back()
		for sub in DirAccess.get_directories_at(dir):
			dirs.append(dir.path_join(sub))
		for file in DirAccess.get_files_at(dir):
			if file.ends_with(".tres") or file.ends_with(".tscn"):
				files.append(dir.path_join(file))
	return files


## Adds uid="..." to the file's path-only ext_resource lines; returns how many.
func _fill_references(path: String) -> int:
	var lines := FileAccess.get_file_as_string(path).split("\n")
	var filled := 0
	var pattern := RegEx.create_from_string('^\\[ext_resource (.*) path="([^"]+)"(.*)\\]$')
	for i in lines.size():
		var line := lines[i]
		if not line.begins_with("[ext_resource") or line.contains(' uid="'):
			continue
		var found := pattern.search(line)
		if found == null:
			continue
		var id := ResourceLoader.get_resource_uid(found.get_string(2))
		if id == ResourceUID.INVALID_ID:
			push_warning("fill_uid_refs: %s refers to %s, which has no UID" % [path, found.get_string(2)])
			continue
		lines[i] = '[ext_resource %s uid="%s" path="%s"%s]' % [found.get_string(1), ResourceUID.id_to_text(id),
				found.get_string(2), found.get_string(3)]
		filled += 1
	if filled > 0:
		var file := FileAccess.open(path, FileAccess.WRITE)
		file.store_string("\n".join(lines))
		file.close()
	return filled
