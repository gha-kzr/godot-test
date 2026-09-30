class_name Hud
extends CanvasLayer
## Battle HUD, the controller's single entry point: it forwards to component scenes (turn
## timeline, full-order overlay, unit cards, spell bar) and owns the round label, actions,
## turn banner and result. The controller updates it with show_* calls (calls down) and
## listens to its signals (signals up); the HUD never reads or changes battle state itself.
##
## Buttons never take keyboard focus, so Space can't press a focused button; spells and
## End turn have keyboard shortcuts (1-9, the end_turn action) that respect disabled state.

signal spell_selected(index: int)
signal end_turn_pressed
signal view_toggle_pressed
signal restart_pressed
## A turn-order chip is hovered (unit id) or left, or clicked.
signal chip_hovered(unit_id: int)
signal chip_unhovered
signal chip_pressed(unit_id: int)
## The inspect card's ✕ was pressed.
signal card_closed

const BANNER_FADE := 0.2
const BANNER_HOLD := 0.9
const END_TURN_PULSE_COLOR := Color(1.6, 1.5, 0.7)
const END_TURN_PULSE_TIME := 0.5

var _controls_enabled := true
var _placing := false
var _banner_tween: Tween
var _pulse_tween: Tween

@onready var _round_label: Label = %RoundLabel
@onready var _prompt_label: Label = %PromptLabel
@onready var _timeline: TurnTimeline = %TurnTimeline
@onready var _order_overlay: OrderOverlay = %OrderOverlay
@onready var _active_card: UnitCard = %ActiveCard
@onready var _inspect_card: UnitCard = %InspectCard
@onready var _spell_bar: SpellBar = %SpellBar
@onready var _end_turn_button: Button = %EndTurnButton
@onready var _view_button: Button = %ViewButton
@onready var _banner: Label = %Banner
@onready var _result_panel: Control = %ResultPanel
@onready var _result_label: Label = %ResultLabel
@onready var _restart_button: Button = %RestartButton
@onready var _seed_label: Label = %SeedLabel


func _ready() -> void:
	_end_turn_button.pressed.connect(end_turn_pressed.emit)
	_view_button.pressed.connect(view_toggle_pressed.emit)
	_restart_button.pressed.connect(restart_pressed.emit)
	_spell_bar.spell_pressed.connect(spell_selected.emit)
	_timeline.chip_hovered.connect(chip_hovered.emit)
	_timeline.chip_unhovered.connect(chip_unhovered.emit)
	_timeline.chip_pressed.connect(chip_pressed.emit)
	_timeline.order_button_pressed.connect(_order_overlay.toggle)
	# Shortcuts fire before GUI input, so the overlay's dim can't block them: lock the buttons.
	_order_overlay.opened.connect(_refresh_buttons)
	_order_overlay.closed.connect(_refresh_buttons)
	_inspect_card.closed.connect(card_closed.emit)
	# Spells listed on the inspect card show their details above the spell bar.
	_inspect_card.spell_hovered.connect(_spell_bar.show_details)
	_inspect_card.spell_unhovered.connect(_spell_bar.hide_details)
	var end_turn_shortcut := Shortcut.new()
	var end_turn_event := InputEventAction.new()
	end_turn_event.action = &"end_turn"
	end_turn_shortcut.events = [end_turn_event]
	_end_turn_button.shortcut = end_turn_shortcut
	_banner.modulate.a = 0.0
	_result_panel.hide()
	_inspect_card.hide()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"show_order"):
		_order_overlay.toggle()
		get_viewport().set_input_as_handled()


## Units in the order they'll act, the current one first (every living unit: the timeline
## shows the next few, the overlay all of them); `title` (e.g. "Floor 3") goes before the
## round number.
func show_turn_order(units: Array[UnitInfo], round_number: int, title := "") -> void:
	_round_label.text = ("%s · Round %d" % [title, round_number]) if not title.is_empty() else "Round %d" % round_number
	_timeline.show_order(units)
	_order_overlay.show_order(units)


## The active unit's card.
func show_unit(info: UnitInfo) -> void:
	_active_card.show_unit(info)


## The card for the unit under the mouse, or the pinned one (with its ✕).
func show_inspected(info: UnitInfo, pinned := false) -> void:
	_inspect_card.show_unit(info)
	_inspect_card.set_closable(pinned)
	_inspect_card.show()


func hide_inspected() -> void:
	_inspect_card.hide()
	_spell_bar.hide_details()


## Whether a control belongs to the (visible) inspect card.
func is_inspect_control(control: Control) -> bool:
	return _inspect_card.visible and (control == _inspect_card or _inspect_card.is_ancestor_of(control))


## Closes the full-order overlay if it's open; true if it was (Esc closes it first).
func close_order_overlay() -> bool:
	if not _order_overlay.is_open():
		return false
	_order_overlay.close()
	return true


## One slot per spell; spells costing more than `ap` are disabled.
func show_spells(spells: Array[SpellData], ap: int) -> void:
	_spell_bar.show_spells(spells, ap)


## The active unit's AP changed (spells it can't afford are disabled).
func set_spell_ap(ap: int) -> void:
	_spell_bar.set_ap(ap)


## Shows which spell is being aimed (-1 for none). Doesn't emit spell_selected.
func set_selected_spell(index: int) -> void:
	_spell_bar.set_selected(index)


## Spells and End turn only work on the player's turn, outside animations.
func set_player_controls_enabled(enabled: bool) -> void:
	_controls_enabled = enabled
	_refresh_buttons()


## While heroes are placed before the battle: no spells, and End turn becomes Ready.
func set_placing(placing: bool) -> void:
	_placing = placing
	_end_turn_button.text = "Ready (Space)" if placing else "End turn (Space)"
	_refresh_buttons()


## The persistent guidance line under the turn order ("" hides it).
func set_prompt(text: String) -> void:
	_prompt_label.text = text
	_prompt_label.visible = not text.is_empty()


## Makes End turn pulse while the active hero has nothing left to do.
func set_end_turn_pulse(pulsing: bool) -> void:
	if pulsing == is_end_turn_pulsing():
		return
	if _pulse_tween != null:
		_pulse_tween.kill()
		_pulse_tween = null
	_end_turn_button.modulate = Color.WHITE
	if pulsing:
		_pulse_tween = create_tween().set_loops()
		_pulse_tween.tween_property(_end_turn_button, "modulate", END_TURN_PULSE_COLOR, END_TURN_PULSE_TIME)
		_pulse_tween.tween_property(_end_turn_button, "modulate", Color.WHITE, END_TURN_PULSE_TIME)


func is_end_turn_pulsing() -> bool:
	return _pulse_tween != null


func set_overhead_view(enabled: bool) -> void:
	_view_button.text = "Side view (T)" if enabled else "Top view (T)"


## Fades a short message in and out. Await it to wait until it's gone.
func show_banner(text: String) -> void:
	_banner.text = text
	if _banner_tween != null:
		_banner_tween.kill()
	_banner_tween = create_tween()
	_banner_tween.tween_property(_banner, "modulate:a", 1.0, BANNER_FADE)
	_banner_tween.tween_interval(BANNER_HOLD)
	_banner_tween.tween_property(_banner, "modulate:a", 0.0, BANNER_FADE)
	await _banner_tween.finished


## `battle_seed` is shown so a battle can be replayed (BattleController.rng_seed).
func show_result(won: bool, battle_seed := 0) -> void:
	_result_label.text = "Victory!" if won else "Defeat"
	_seed_label.text = "Battle seed %d" % battle_seed
	set_player_controls_enabled(false)
	_result_panel.show()


## The result screen's button: "Play again" standalone, "Continue" in the game flow.
func set_result_action_text(text: String) -> void:
	_restart_button.text = text


func hide_result() -> void:
	_result_panel.hide()


## A spell in one sentence, e.g. "Range 2-6, line of sight. Circle area 1. 5-7 damage."
static func spell_description(spell: SpellData) -> String:
	return ". ".join(SpellBar.detail_lines(spell)) + "."


func _refresh_buttons() -> void:
	var overlay_open := _order_overlay.is_open()
	_spell_bar.set_locked(not _controls_enabled or _placing or overlay_open)
	_end_turn_button.disabled = not _controls_enabled or overlay_open
