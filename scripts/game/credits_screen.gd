class_name CreditsScreen
extends Screen
## The credits, on a screen of their own under the settings: every external asset with its
## author and license, read from CREDITS.md. The back arrow (or Esc) returns to the settings.

const CREDITS_PATH := "res://CREDITS.md"
const CREDITS_FALLBACK := "Credits are listed in CREDITS.md."

@onready var _back: Button = %BackButton
@onready var _text: Label = %Credits


func _ready() -> void:
	_back.pressed.connect(back_pressed.emit)
	_text.text = credits_text()


## The credits as plain lines, from CREDITS.md: its tables, bullet lists and headings (other prose is
## instructions for contributors, not for players). A five-column asset row (Asset, Files, Source,
## Author, License) reads "Asset — Source — Author — License": the link text names the source.
## Markdown links and backticks are cleaned. Limits: no "|" inside a cell, no nested brackets.
static func credits_text(path := CREDITS_PATH) -> String:
	if not FileAccess.file_exists(path):
		return CREDITS_FALLBACK
	var link := RegEx.create_from_string("\\[([^\\]]*)\\]\\([^)]*\\)")
	var lines: Array[String] = []
	for raw in FileAccess.get_file_as_string(path).split("\n"):
		var line := raw.strip_edges()
		if line.begins_with("|"):
			var cells: Array[String] = []
			for cell in line.trim_prefix("|").trim_suffix("|").split("|"):
				cells.append(link.sub(cell.strip_edges(), "$1", true).replace("`", ""))
			if cells.all(func(c: String) -> bool: return c.replace("-", "").replace(":", "").is_empty()):
				continue  # The |---|---| separator.
			if cells.size() == 5:
				cells = [cells[0], cells[2], cells[3], cells[4]]
			line = " — ".join(cells)
		elif line.begins_with("- ") or line.begins_with("* "):
			line = link.sub(line.substr(2), "$1", true).replace("`", "")
		elif line.begins_with("#"):
			line = line.lstrip("# ")
			if not lines.is_empty():
				lines.append("")
		else:
			continue  # Prose: for contributors.
		lines.append(line)
	return "\n".join(lines)
