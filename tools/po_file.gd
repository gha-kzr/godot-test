class_name PoFile
extends RefCounted
## A gettext .po file: its header and entries (message id, optional context and plural, and the
## translation). Reads what Godot reads and writes a stable text, so the extractor can merge
## new texts into a translation without disturbing it.

class PoEntry:
	var id := ""
	var context := ""
	var plural := ""
	## One text, or two for a plural entry (singular, plural); empty text: not translated yet.
	var translations: Array[String] = [""]
	var references: Array[String] = []

	func key() -> String:
		return PoFile.key_of(context, id)

	func is_translated() -> bool:
		return not translations.is_empty() and translations.all(func(t: String) -> bool: return not t.is_empty())


var header := ""
var entries: Dictionary[String, PoEntry] = {}


static func key_of(context: String, id: String) -> String:
	return context + "\u0004" + id


static func load_file(path: String) -> PoFile:
	var result := PoFile.new()
	if not FileAccess.file_exists(path):
		return result
	result._parse(FileAccess.get_file_as_string(path))
	return result


func _parse(text: String) -> void:
	var current: PoEntry
	var field := ""
	var in_header := false
	var header_text := ""
	for raw in text.split("\n"):
		var line := raw.strip_edges()
		if line.is_empty() or line.begins_with("#"):
			continue
		if line.begins_with("\""):  # A continuation of the previous field.
			if in_header:
				header_text += _unquote(line)
			else:
				_append(current, field, _unquote(line))
			continue
		var space := line.find(" ")
		var word := line.substr(0, space) if space >= 0 else line
		var value := _unquote(line.substr(space + 1)) if space >= 0 else ""
		var starts_entry := word == "msgctxt" or (word == "msgid" and (current == null or field.begins_with("msgstr")))
		if word == "msgctxt" and current != null and field.begins_with("msgstr"):
			starts_entry = true
		if starts_entry:
			current = PoEntry.new()
			in_header = false
		field = word
		if word == "msgstr" and current != null and current.id.is_empty() and current.context.is_empty():
			in_header = true  # The entry with an empty id is the header.
			header_text = value
			continue
		_append(current, field, value)
		if current != null and not current.id.is_empty() and word.begins_with("msgstr"):
			entries[current.key()] = current
	header = header_text


func _append(entry: PoEntry, field: String, value: String) -> void:
	if entry == null:
		return
	match field:
		"msgctxt": entry.context += value
		"msgid": entry.id += value
		"msgid_plural": entry.plural += value
		_:
			var index := 0
			if field.begins_with("msgstr["):
				index = int(field.substr(7, field.length() - 8))
			while entry.translations.size() <= index:
				entry.translations.append("")
			entry.translations[index] += value


static func _unquote(quoted: String) -> String:
	var body := quoted.strip_edges()
	if body.length() >= 2 and body.begins_with("\"") and body.ends_with("\""):
		body = body.substr(1, body.length() - 2)
	var out := ""
	var i := 0
	while i < body.length():
		var c := body[i]
		if c == "\\" and i + 1 < body.length():
			i += 1
			match body[i]:
				"n": out += "\n"
				"t": out += "\t"
				"\"": out += "\""
				"\\": out += "\\"
				_: out += "\\" + body[i]
		else:
			out += c
		i += 1
	return out


static func quote(text: String) -> String:
	return "\"" + text.replace("\\", "\\\\").replace("\"", "\\\"").replace("\n", "\\n").replace("\t", "\\t") + "\""


## The file's text; `with_references` adds a `#:` line per source file (for the template).
func to_text(with_references := false) -> String:
	var out := _header_text()
	var keys := entries.keys()
	keys.sort_custom(func(a: String, b: String) -> bool:
		return entries[a].id.to_lower() < entries[b].id.to_lower() if entries[a].id.to_lower() != entries[b].id.to_lower() else a < b)
	for key: String in keys:
		var entry := entries[key]
		out += "\n"
		if with_references and not entry.references.is_empty():
			out += "#: %s\n" % " ".join(entry.references)
		if not entry.context.is_empty():
			out += "msgctxt %s\n" % quote(entry.context)
		out += "msgid %s\n" % quote(entry.id)
		if entry.plural.is_empty():
			out += "msgstr %s\n" % quote("" if with_references else entry.translations[0])
		else:
			out += "msgid_plural %s\n" % quote(entry.plural)
			for index in 2:
				var text := entry.translations[index] if index < entry.translations.size() and not with_references else ""
				out += "msgstr[%d] %s\n" % [index, quote(text)]
	return out


func _header_text() -> String:
	var out := "# Translation. The message id is the English text shown in the game.\n"
	out += "# Rebuilt and merged by tools/extract_strings.gd; translations are kept, new texts arrive empty.\n"
	out += "msgid \"\"\nmsgstr \"\"\n"
	for line in header.split("\n"):
		if not line.is_empty():
			out += "%s\n" % quote(line + "\n")
	return out
