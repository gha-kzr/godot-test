@tool
extends VBoxContainer
## The Inspector section above a spell's or enemy's fields: a grid (spells) and a text
## summary, refreshed a few times a second so it follows edits made in the Inspector.

const AreaGridView := preload("res://addons/design_tools/previews/area_grid_view.gd")
const REFRESH_SECONDS := 0.4

var resource: Resource
var _grid: Control
var _text: Label
var _last_text := ""
var _elapsed := 0.0


func _init(previewed: Resource) -> void:
	resource = previewed
	var title := Label.new()
	title.text = "Design preview"
	add_child(title)
	if resource is SpellData:
		_grid = AreaGridView.new()
		_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		add_child(_grid)
	_text = Label.new()
	use_editor_code_font(_text)
	add_child(_text)
	add_child(HSeparator.new())
	_refresh()


func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed >= REFRESH_SECONDS:
		_elapsed = 0.0
		_refresh()


func _refresh() -> void:
	var lines := PackedStringArray()
	if resource is SpellData:
		var spell := resource as SpellData
		lines = SpellPreview.summary(spell)
		(_grid as Control).set("preview", SpellPreview.grid(spell))
	elif resource is EnemyData:
		lines = EnemyPreview.summary(resource as EnemyData)
	var text := "\n".join(lines)
	if text != _last_text:
		_last_text = text
		_text.text = text


## The editor's own monospace font and size (they follow the editor's display scale and
## the user's code font settings), so tables line up and aren't tiny on HiDPI screens.
static func use_editor_code_font(label: Label) -> void:
	var theme := EditorInterface.get_editor_theme()
	if theme.has_font("source", "EditorFonts"):
		label.add_theme_font_override("font", theme.get_font("source", "EditorFonts"))
	if theme.has_font_size("source_size", "EditorFonts"):
		label.add_theme_font_size_override("font_size", theme.get_font_size("source_size", "EditorFonts"))
