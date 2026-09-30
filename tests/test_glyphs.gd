extends TestCase
## The game's font is the only font on the web (no system fallback): every non-ASCII
## character in the text of scripts and scenes must exist in it, or it shows as a box.

const FONT := preload("res://ui/fonts/Fredoka.ttf")
const DIRECTORIES := ["res://scripts", "res://scenes"]


func _files(dir: String) -> Array[String]:
	var files: Array[String] = []
	for entry in DirAccess.get_directories_at(dir):
		files.append_array(_files(dir.path_join(entry)))
	for file in DirAccess.get_files_at(dir):
		if file.ends_with(".gd") or file.ends_with(".tscn"):
			files.append(dir.path_join(file))
	return files


func test_every_character_in_game_text_is_in_the_font() -> void:
	var font := FONT as FontFile
	var problems: Array[String] = []
	for dir in DIRECTORIES:
		for path in _files(dir):
			for line in FileAccess.get_file_as_string(path).split("\n"):
				var code := line.strip_edges()
				if code.begins_with("#"):
					continue  # Comments aren't drawn.
				var quote := code.find('"')
				if quote == -1:
					continue
				for character in code.substr(quote):
					if character.unicode_at(0) > 127 and not font.has_char(character.unicode_at(0)):
						problems.append("%s: '%s' in %s" % [path, character, code.left(60)])
	assert_eq(problems, [] as Array[String], "characters the font lacks")
