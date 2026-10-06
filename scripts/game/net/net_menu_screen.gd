class_name NetMenuScreen
extends Screen
## The multiplayer front page, in cards: who you are (a name and the hero you like to play: the lobby starts with it),
## then two separate ways in: host a match, or join one with a room code (or an invite link). An invite link opened in
## the browser fills the code in and joins by itself.

signal host_requested(player_name: String)
signal join_requested(player_name: String, code: String)

var _name_edit: LineEdit
var _code_edit: LineEdit
var _status: Label
var _heroes: HBoxContainer
var _hero := 0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var background := ColorRect.new()
	background.color = Color(0.1, 0.11, 0.14)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(center)
	var column := VBoxContainer.new()
	column.custom_minimum_size = Vector2(760, 0)
	column.add_theme_constant_override("separation", 14)
	center.add_child(column)
	var title := Label.new()
	title.theme_type_variation = &"HeaderLabel"
	title.text = "Multiplayer"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(title)
	NetUi.note(column, tr("Fight other players, one hero each. Nothing to install and no server: the players connect to each other directly."))
	_build_you(column)
	var ways := HBoxContainer.new()
	ways.add_theme_constant_override("separation", 14)
	column.add_child(ways)
	_build_host(ways)
	_build_join(ways)
	_status = Label.new()
	_status.name = "Status"
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.theme_type_variation = &"SmallLabel"
	_status.add_theme_color_override("font_color", Color(1.0, 0.6, 0.5))
	column.add_child(_status)
	if not WebPage.is_web():
		NetUi.note(column, tr("Multiplayer needs the web version of the game (it uses the browser's WebRTC)."))
	var back := HubStyle.button("Back", "BackButton")
	back.pressed.connect(back_pressed.emit)
	column.add_child(back)


func _build_you(parent: Control) -> void:
	var box := NetUi.card(parent, tr("You"))
	_name_edit = LineEdit.new()
	_name_edit.name = "NameEdit"
	_name_edit.placeholder_text = "Your name"
	_name_edit.max_length = MatchState.MAX_NAME
	_name_edit.custom_minimum_size = Vector2(0, 44)
	_name_edit.text = _saved_name()
	box.add_child(_name_edit)
	NetUi.note(box, tr("Your hero (the lobby starts with it; you can change it there)"))
	_heroes = HBoxContainer.new()
	_heroes.name = "Heroes"
	_heroes.add_theme_constant_override("separation", 10)
	box.add_child(_heroes)
	_hero = NetUi.saved_hero()
	_fill_heroes()


func _fill_heroes() -> void:
	HubStyle.clear_children(_heroes)
	var group := ButtonGroup.new()
	for index in PvpHeroes.hero_count():
		var card := NetUi.hero_card(index, index == _hero, _pick_hero)
		card.button_group = group
		_heroes.add_child(card)


func _pick_hero(index: int) -> void:
	_hero = index
	NetUi.save_hero(index)


func _build_host(parent: Control) -> void:
	var box := NetUi.card(parent, tr("Host a match"), Color(0.5, 0.85, 0.55), 340)
	box.get_parent().size_flags_horizontal = Control.SIZE_EXPAND_FILL
	NetUi.note(box, tr("Start a match and get a room code to give to your friends. You choose the map and the rules."))
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(spacer)
	var host := HubStyle.button("Host a match", "HostButton")
	host.custom_minimum_size = Vector2(0, 48)
	host.pressed.connect(_on_host)
	box.add_child(host)


func _build_join(parent: Control) -> void:
	var box := NetUi.card(parent, tr("Join a match"), Color(0.5, 0.7, 1.0), 340)
	box.get_parent().size_flags_horizontal = Control.SIZE_EXPAND_FILL
	NetUi.note(box, tr("Type the room code the host gave you (or paste their room link). With an invite link instead, you will get a reply to send back to them."))
	_code_edit = LineEdit.new()
	_code_edit.name = "CodeEdit"
	_code_edit.placeholder_text = "Room code, or invite link"
	_code_edit.custom_minimum_size = Vector2(0, 44)
	_code_edit.text_submitted.connect(func(_text: String) -> void: _on_join())
	box.add_child(_code_edit)
	var join := HubStyle.button("Join", "JoinButton")
	join.custom_minimum_size = Vector2(0, 48)
	join.pressed.connect(_on_join)
	box.add_child(join)


## Fills the invite in (from a link the page was opened with).
func prefill_code(code: String) -> void:
	_code_edit.text = code


func show_message(text: String) -> void:
	_status.text = text


func player_name() -> String:
	var typed := _name_edit.text.strip_edges()
	return typed if not typed.is_empty() else "Player"


func _on_host() -> void:
	_save_name()
	host_requested.emit(player_name())


func _on_join() -> void:
	var text := _code_edit.text.strip_edges()
	if text.is_empty():
		_status.text = "Enter a room code or paste an invite first."
		return
	_save_name()
	join_requested.emit(player_name(), text)


func _saved_name() -> String:
	var file := ConfigFile.new()
	if file.load(NetUi.player_file) == OK:
		return str(file.get_value("player", "name", ""))
	return ""


func _save_name() -> void:
	var file := ConfigFile.new()
	file.load(NetUi.player_file)
	file.set_value("player", "name", _name_edit.text.strip_edges())
	file.save(NetUi.player_file)
