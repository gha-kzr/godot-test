class_name StringScanner
extends RefCounted
## Finds every text the game can show, as message ids: `tr()` / `tr_n()` /
## `TranslationServer.translate()` calls with a literal in the scripts, text properties in the
## scenes, `display_name` and `tag` in the data files, plain literals put on a Control
## (`label.text = "Hello"`, `add_item("Hello")`: Controls translate their own text), and the
## constant tables (hint texts, action labels, area shape names). Also lists formatted literals handed to a
## Control without `tr()` (`label.text = "Round %d" % n`), which would never be translated.

const SCRIPT_DIRS: Array[String] = ["res://scripts"]
## Developer tools stay in English.
const EXCLUDED_SCRIPT_DIRS: Array[String] = ["res://scripts/tools"]
const SCENE_DIR := "res://scenes"
const DATA_DIR := "res://data"
const SCENE_PROPERTIES: Array[String] = ["text", "tooltip_text", "title", "placeholder_text"]
const DATA_PROPERTIES: Array[String] = ["display_name", "tag"]

## Functions that put a text argument on a Control: name → the index of that argument.
const TEXT_HELPERS: Dictionary[String, int] = {
	"_choice_button": 1, "_button": 1, "_action": 1, "_label": 0, "HubStyle.button": 0,
	"show_banner": 0, "show_message": 0, "set_result_action_text": 0,
}

## Message id (with context) → PoFile.PoEntry, with the files that use it as references.
var entries: Dictionary[String, PoFile.PoEntry] = {}
## "file:line: text" for formatted literals set on a Control without tr().
var unrouted: Array[String] = []

var _call_pattern := RegEx.create_from_string("(?<![\\w.])(?:tr|atr|tr_n|TranslationServer\\.translate|TranslationServer\\.translate_plural)\\(\\s*\"")
var _control_pattern := RegEx.create_from_string("(?:\\.text|\\.tooltip_text|\\.placeholder_text|\\.title)\\s*=\\s*\"|\\badd_item\\(\\s*\"")
var _helper_pattern := RegEx.create_from_string("(?<![\\w])(%s)\\(" % "|".join(TEXT_HELPERS.keys().map(func(n: String) -> String: return n.replace(".", "\\."))))
var _scene_pattern := RegEx.create_from_string("^(?:%s) = \"" % "|".join(SCENE_PROPERTIES))
var _data_pattern := RegEx.create_from_string("^(?:%s) = \"" % "|".join(DATA_PROPERTIES))


func scan_all() -> void:
	for dir in SCRIPT_DIRS:
		for path in _files(dir, "gd"):
			if not EXCLUDED_SCRIPT_DIRS.any(func(excluded: String) -> bool: return path.begins_with(excluded + "/")):
				_scan_script(path)
	for path in _files(SCENE_DIR, "tscn"):
		_scan_lines(path, _scene_pattern)
	for path in _files(DATA_DIR, "tres"):
		_scan_lines(path, _data_pattern)
	for text in Hints.TEXTS.values():
		_add(text, "", "", "scripts/progression/hints.gd")
	for text in Settings.ACTION_LABELS.values():
		_add(text, "", "", "scripts/progression/settings.gd")
	for kind_name in AreaShape.Kind.keys():  # Shown by SpellBar.detail_lines as the capitalized name.
		_add(kind_name.capitalize(), "", "", "scripts/data/area_shape.gd")


## Whether a literal is something to translate: it has a word of letters and isn't only
## placeholders or symbols.
static func is_text(text: String) -> bool:
	var letters := RegEx.create_from_string("[A-Za-z]{2,}")
	var stripped := RegEx.create_from_string("\\{[a-z_]+\\}|%[sdf]").sub(text, "", true)
	return letters.search(stripped) != null


func _add(id: String, plural: String, context: String, file: String) -> void:
	if not is_text(id):
		return
	var key := PoFile.key_of(context, id)
	var entry: PoFile.PoEntry = entries.get(key)
	if entry == null:
		entry = PoFile.PoEntry.new()
		entry.id = id
		entry.context = context
		entry.plural = plural
		if not plural.is_empty():
			entry.translations = ["", ""]
		entries[key] = entry
	if file not in entry.references:
		entry.references.append(file)


func _scan_script(path: String) -> void:
	var source := FileAccess.get_file_as_string(path)
	var file := path.trim_prefix("res://")
	for match in _call_pattern.search_all(source):
		var call := source.substr(match.get_start(), match.get_end() - match.get_start())
		var plural_call := call.contains("tr_n(") or call.contains("translate_plural(")
		var first := _literal(source, match.get_end() - 1)
		if first.is_empty():
			continue
		var position := int(first["end"])
		var second := ""
		var context := ""
		if plural_call:
			var comma := source.find(",", position)
			var plural := _literal(source, source.find("\"", comma)) if comma >= 0 else {}
			if plural.is_empty():
				continue
			second = plural["text"]
		else:
			var rest := source.substr(position, 80).strip_edges(true, false)
			if rest.begins_with(","):
				var quote := source.find("\"", position)
				var between := source.substr(position, quote - position) if quote >= 0 else ""
				if between.strip_edges() == ",":
					var ctx := _literal(source, quote)
					if not ctx.is_empty():
						context = ctx["text"]
		_add(first["text"], second, context, file)
	_scan_helpers(source, file)
	for match in _control_pattern.search_all(source):
		var literal := _literal(source, match.get_end() - 1)
		if literal.is_empty():
			continue
		var after := source.substr(int(literal["end"]), 40).strip_edges(true, false)
		if after.begins_with("%") or after.begins_with("+"):
			if is_text(literal["text"]):
				unrouted.append("%s:%d: %s" % [file, source.count("\n", 0, match.get_start()) + 1, literal["text"]])
			continue
		_add(literal["text"], "", "", file)


## Literal text arguments of the helpers that build Controls (`_label("Stages")`).
func _scan_helpers(source: String, file: String) -> void:
	for match in _helper_pattern.search_all(source):
		var args := _arguments(source, match.get_end() - 1)
		var index: int = TEXT_HELPERS[match.get_string(1)]
		if index >= args.size():
			continue
		var arg := args[index].strip_edges()
		var literal := _literal(arg, 0)
		if literal.is_empty():
			continue
		var after := arg.substr(int(literal["end"])).strip_edges(true, false)
		if after.begins_with("%") or after.begins_with("+"):
			if is_text(literal["text"]):
				unrouted.append("%s:%d: %s" % [file, source.count("\n", 0, match.get_start()) + 1, literal["text"]])
			continue
		_add(literal["text"], "", "", file)


## The top-level arguments of the call whose "(" is at `open`, as source text.
static func _arguments(source: String, open: int) -> Array[String]:
	var args: Array[String] = []
	var depth := 0
	var start := open + 1
	var i := open
	while i < source.length():
		var c := source[i]
		if c == "\"":
			var literal := _literal(source, i)
			if literal.is_empty():
				break
			i = int(literal["end"])
			continue
		if c == "(" or c == "[" or c == "{":
			depth += 1
		elif c == ")" or c == "]" or c == "}":
			depth -= 1
			if depth == 0:
				args.append(source.substr(start, i - start))
				return args
		elif c == "," and depth == 1:
			args.append(source.substr(start, i - start))
			start = i + 1
		i += 1
	return args


func _scan_lines(path: String, pattern: RegEx) -> void:
	var file := path.trim_prefix("res://")
	for line in FileAccess.get_file_as_string(path).split("\n"):
		var match := pattern.search(line)
		if match == null:
			continue
		var literal := _literal(line, match.get_end() - 1)
		if not literal.is_empty():
			_add(literal["text"], "", "", file)


## The string literal opening at `start` (a quote): {"text", "end"}, or {} if there is none.
static func _literal(source: String, start: int) -> Dictionary:
	if start < 0 or start >= source.length() or source[start] != "\"":
		return {}
	var out := ""
	var i := start + 1
	while i < source.length():
		var c := source[i]
		if c == "\\" and i + 1 < source.length():
			i += 1
			match source[i]:
				"n": out += "\n"
				"t": out += "\t"
				_: out += source[i]
		elif c == "\"":
			return {"text": out, "end": i + 1}
		elif c == "\n":
			return {}
		else:
			out += c
		i += 1
	return {}


static func _files(dir_path: String, extension: String) -> Array[String]:
	var found: Array[String] = []
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return found
	for sub in dir.get_directories():
		found.append_array(_files(dir_path.path_join(sub), extension))
	for file in dir.get_files():
		if file.get_extension() == extension:
			found.append(dir_path.path_join(file))
	found.sort()
	return found
