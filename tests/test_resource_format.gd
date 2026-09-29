extends TestCase
## Content and scene files are in the editor's canonical form (a UID, and uid= on every
## reference), so opening the editor doesn't rewrite them. Fix a failure with:
##   godot --headless --script res://tools/fill_uid_refs.gd


func _files() -> Array[String]:
	var files: Array[String] = []
	var dirs: Array[String] = ["res://data", "res://scenes"]
	while not dirs.is_empty():
		var dir: String = dirs.pop_back()
		for sub in DirAccess.get_directories_at(dir):
			dirs.append(dir.path_join(sub))
		for file in DirAccess.get_files_at(dir):
			if file.ends_with(".tres") or file.ends_with(".tscn"):
				files.append(dir.path_join(file))
	return files


func test_every_file_and_reference_has_a_uid() -> void:
	var problems: Array[String] = []
	for path in _files():
		var lines := FileAccess.get_file_as_string(path).split("\n")
		if not lines[0].contains(' uid="uid://'):
			problems.append("%s: no file UID" % path)
		for line in lines:
			if line.begins_with("[ext_resource") and not line.contains(' uid="uid://'):
				problems.append("%s: %s" % [path, line])
	assert_eq(problems, [] as Array[String], "run tools/fill_uid_refs.gd")
