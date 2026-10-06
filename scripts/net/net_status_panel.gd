class_name NetStatusPanel
extends PanelContainer
## In the fight: who plays which hero (a colour for the side), who is a player, who the AI and who has
## dropped out, the seconds left on the turn, and a button to let the AI play my hero (or take it back).

const SIDE_COLORS: Array[Color] = NetUi.SIDE_COLORS

var _session: MatchSession
var _rows: VBoxContainer
var _timer_label: Label
var _toggle: Button
var _emote_bar: HFlowContainer
var _emotes_seen: Dictionary[int, Array] = {}

## How long what a player said stays next to their name.
const EMOTE_SECONDS := 5.0


func bind(session: MatchSession) -> void:
	_session = session
	mouse_filter = Control.MOUSE_FILTER_PASS
	theme_type_variation = &"Chip"
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	offset_left = 12.0
	offset_top = 12.0
	var box := VBoxContainer.new()
	add_child(box)
	var title := Label.new()
	title.theme_type_variation = &"PromptLabel"
	title.text = tr("Players")
	box.add_child(title)
	_rows = VBoxContainer.new()
	box.add_child(_rows)
	_timer_label = Label.new()
	_timer_label.theme_type_variation = &"SmallLabel"
	box.add_child(_timer_label)
	_toggle = Button.new()
	_toggle.focus_mode = Control.FOCUS_NONE
	_toggle.pressed.connect(_on_toggle)
	box.add_child(_toggle)
	_emote_bar = HFlowContainer.new()
	_emote_bar.name = "Emotes"
	_emote_bar.custom_minimum_size = Vector2(260, 0)
	box.add_child(_emote_bar)
	for index in Emotes.count():
		var emote := Button.new()
		emote.name = "Emote%d" % index
		emote.text = Emotes.TEXTS[index]
		emote.focus_mode = Control.FOCUS_NONE
		emote.pressed.connect(func() -> void: session.send_emote(index))
		_emote_bar.add_child(emote)
	session.changed.connect(refresh)
	session.emote_received.connect(_on_emote)
	refresh()


func _process(_delta: float) -> void:
	if _session == null:
		return
	var placing := _session.placement_seconds_left()
	var left := _session.turn_seconds_left()
	_timer_label.visible = left >= 0.0 or placing >= 0.0
	_timer_label.text = tr("Placement: %d s") % ceili(placing) if placing >= 0.0 else tr("Turn: %d s") % ceili(left)


func refresh() -> void:
	if _session == null:
		return
	for child in _rows.get_children():
		_rows.remove_child(child)
		child.queue_free()
	for id in _session.state.seat_ids():
		var seat := _session.state.seats[id]
		var row := Label.new()
		row.theme_type_variation = &"SmallLabel"
		row.add_theme_color_override("font_color", SIDE_COLORS[seat.side])
		row.text = describe(seat, id == _session.my_id)
		var said: Array = _emotes_seen.get(id, [])
		if not said.is_empty() and Time.get_ticks_msec() - int(said[1]) < EMOTE_SECONDS * 1000.0:
			row.text += "  “%s”" % Emotes.text(int(said[0]))
		_rows.add_child(row)
	var mine := _session.state.seats.get(_session.my_id) as MatchState.Seat
	if _session.connection_lost:
		var lost := Label.new()
		lost.theme_type_variation = &"SmallLabel"
		lost.add_theme_color_override("font_color", Color(1.0, 0.6, 0.5))
		lost.text = tr("Nobody else is connected: the others left, or your own connection broke.")
		lost.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lost.custom_minimum_size = Vector2(260, 0)
		_rows.add_child(lost)
	_toggle.visible = mine != null
	if mine != null:
		_toggle.text = tr("Play my hero again") if mine.ai else tr("Let the AI play my hero")


func _on_emote(seat_id: int, emote_id: int) -> void:
	_emotes_seen[seat_id] = [emote_id, Time.get_ticks_msec()]
	refresh()
	get_tree().create_timer(EMOTE_SECONDS).timeout.connect(refresh)


## "Alice: Knight", with the tag that matters: (AI), (away) or (you).
static func describe(seat: MatchState.Seat, is_me: bool) -> String:
	var text := "%s: %s" % [seat.name, PvpHeroes.hero_name(seat.hero)]
	if seat.ai:
		text += " " + TranslationServer.translate("(AI)")
	elif not seat.connected:
		text += " " + TranslationServer.translate("(away)")
	elif is_me:
		text += " " + TranslationServer.translate("(you)")
	return text


func _on_toggle() -> void:
	var mine := _session.state.seats.get(_session.my_id) as MatchState.Seat
	if mine != null:
		_session.hand_to_ai(not mine.ai)
