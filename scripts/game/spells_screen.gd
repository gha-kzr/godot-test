class_name SpellsScreen
extends Screen
## One hero's spells, every description in full: the 5 loadout slots, then the known spells
## that aren't in it. Reading changes nothing; to change the loadout, press Move on a spell,
## then Put here on a slot (an active spell swaps with the slot's, an inactive one replaces
## it). Esc cancels a move, then goes back. The change is reported up; the Game root applies
## it and calls show_spells again.

signal assign_requested(slot: int, spell: SpellData)

## A spell row's background, a little lighter than the screen's.
const ROW_COLOR := Color(1.0, 1.0, 1.0, 0.05)
const MOVING_COLOR := Color(0.35, 0.6, 1.0, 0.25)
const ICON_SIZE := Vector2(40, 40)
const NUMBER_WIDTH := 28

## The spell being moved (null: none).
var moving: SpellData
var _record: HeroRecord

@onready var _back: Button = %BackButton
@onready var _title: Label = %Title
@onready var _prompt: Label = %Prompt
@onready var _list: VBoxContainer = %List


func _ready() -> void:
	_back.pressed.connect(back_pressed.emit)


func _unhandled_input(event: InputEvent) -> void:
	if moving != null and event.is_action_pressed(&"ui_cancel"):
		_cancel_move()
		get_viewport().set_input_as_handled()
		return
	super(event)


func show_spells(record: HeroRecord) -> void:
	_record = record
	moving = null
	_title.text = tr("%s — spells") % tr(record.hero.display_name())
	_rebuild()


func _rebuild() -> void:
	HubStyle.clear_children(_list)
	var active := _record.spells()
	_list.add_child(_section(tr("Loadout: the spells brought to a fight (slot 1 is key 1)")))
	for slot in HeroRecord.LOADOUT_SLOTS:
		_list.add_child(_row(slot, active[slot] if slot < active.size() else null))
	var inactive := _record.inactive_spells()
	if not inactive.is_empty():
		_list.add_child(_section(tr("Known, not in the loadout")))
		for spell in inactive:
			_list.add_child(_row(-1, spell))
	if moving == null:
		_prompt.text = tr("Press Move on a spell to change the loadout.")
	else:
		_prompt.text = tr("Where does %s go? Put here on a slot, or Cancel (Esc).") % tr(moving.display_name)


func _section(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.theme_type_variation = &"PromptLabel"
	return label


## A slot (slot >= 0; spell null: empty) or an inactive spell (slot -1): icon, name, cost,
## the full description, and the action button.
func _row(slot: int, spell: SpellData) -> PanelContainer:
	var row := PanelContainer.new()
	row.name = "Slot%d" % (slot + 1) if slot >= 0 else "Known_%s" % spell.display_name
	var box := StyleBoxFlat.new()
	box.bg_color = MOVING_COLOR if spell != null and spell == moving else ROW_COLOR
	box.set_corner_radius_all(6)
	box.set_content_margin_all(8)
	row.add_theme_stylebox_override("panel", box)
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 12)
	row.add_child(line)
	# The slot number; an empty column for a spell outside the loadout, so every description
	# starts at the same place.
	var number := Label.new()
	number.text = str(slot + 1) if slot >= 0 else ""
	number.theme_type_variation = &"HeaderLabel"
	number.custom_minimum_size = Vector2(NUMBER_WIDTH, 0)
	line.add_child(number)
	var icon := TextureRect.new()
	icon.custom_minimum_size = ICON_SIZE
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	line.add_child(icon)
	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.add_child(text)
	var title := Label.new()
	title.name = "Name"
	var body := Label.new()
	body.name = "Description"
	body.theme_type_variation = &"SmallLabel"
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.add_child(title)
	text.add_child(body)
	if spell == null:
		title.text = tr("(empty)")
		body.text = tr("A spell learned later takes this slot.")
		title.modulate.a = 0.5
		return row
	icon.texture = spell.display_icon()
	icon.modulate = SpellBar.spell_tint(spell)
	title.text = "%s — %s" % [tr(spell.display_name), tr("%d AP") % spell.ap_cost]
	body.text = Hud.spell_description(spell)
	var button := _action_button(slot, spell)
	if button != null:
		line.add_child(button)
	return row


## Move (nothing moving), Cancel (on the moving spell), Put here (a slot, while moving).
func _action_button(slot: int, spell: SpellData) -> Button:
	var button: Button
	if moving == null:
		button = HubStyle.button(tr("Move"), "Move")
		button.pressed.connect(_start_move.bind(spell))
	elif spell == moving:
		button = HubStyle.button(tr("Cancel"), "Cancel")
		button.pressed.connect(_cancel_move)
	elif slot >= 0:
		button = HubStyle.button(tr("Put here"), "PutHere")
		button.pressed.connect(_put.bind(slot))
	else:
		return null  # An inactive spell can't take another inactive one's place.
	button.custom_minimum_size = Vector2(130, 40)
	return button


func _start_move(spell: SpellData) -> void:
	moving = spell
	_rebuild()
	_focus_first_put_here.call_deferred()


func _cancel_move() -> void:
	moving = null
	_rebuild()
	focus_first.call_deferred()


func _put(slot: int) -> void:
	var spell := moving
	moving = null
	assign_requested.emit(slot, spell)


func _focus_first_put_here() -> void:
	if not is_inside_tree():
		return
	var target := _list.find_child("PutHere", true, false) as Button
	if target != null:
		target.grab_focus()
