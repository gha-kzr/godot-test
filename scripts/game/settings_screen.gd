class_name SettingsScreen
extends Screen
## Display (language, window mode, UI scale), audio (volumes, mute), controls (rebinding), game (reset save, show hints
## again) and a button to the credits screen. Edits the Settings it was given in place and says so with `changed`;
## the Game root applies and saves them. Esc goes back, except while a key is being
## captured, where it cancels the capture.

signal changed
## An audio slider moved (mid-drag too): apply it live; `changed` follows once it is released.
signal audio_live
signal credits_pressed
signal reset_save_confirmed

var _settings: Settings
## The action waiting for its new key, or &"".
var _capturing: StringName = &""
## An audio slider's knob is being dragged.
var _dragging := false
var _key_buttons: Dictionary[StringName, Button] = {}

@onready var _language: OptionButton = %Language
@onready var _master: HSlider = %MasterVolume
@onready var _music: HSlider = %MusicVolume
@onready var _effects: HSlider = %EffectsVolume
@onready var _muted: CheckButton = %Muted
@onready var _battle_speed: OptionButton = %BattleSpeed
@onready var _auto_end_turn: CheckButton = %AutoEndTurn
@onready var _window_row: HBoxContainer = %WindowRow
@onready var _window_mode: OptionButton = %WindowMode
@onready var _ui_scale: OptionButton = %UiScale
@onready var _bindings: GridContainer = %Bindings
@onready var _message: Label = %Message
@onready var _reset_keys: Button = %ResetKeysButton
@onready var _reset_save: Button = %ResetSaveButton
@onready var _confirm_row: HBoxContainer = %ConfirmRow
@onready var _confirm_yes: Button = %ConfirmYesButton
@onready var _confirm_no: Button = %ConfirmNoButton
@onready var _show_hints: Button = %ShowHintsButton
@onready var _credits_button: Button = %CreditsButton
@onready var _back: Button = %BackButton


func _ready() -> void:
	_back.pressed.connect(back_pressed.emit)
	_language.add_item("Automatic")  # Index 0; the others are the languages, named in themselves.
	for code in Localization.LANGUAGES:
		_language.add_item(Localization.LANGUAGES[code])
		_language.set_item_metadata(_language.item_count - 1, code)
		_language.set_item_auto_translate_mode(_language.item_count - 1, Node.AUTO_TRANSLATE_MODE_DISABLED)
	_language.item_selected.connect(_on_language_selected)
	_window_mode.add_item("Windowed", Settings.WindowMode.WINDOWED)
	_window_mode.add_item("Fullscreen", Settings.WindowMode.FULLSCREEN)
	for scale_value in Settings.UI_SCALES:
		_ui_scale.add_item("%d%%" % roundi(scale_value * 100.0))
	_window_row.visible = SettingsApplier.supports_window_mode()
	for pair: Array in [[_master, "master_volume"], [_music, "music_volume"], [_effects, "effects_volume"]]:
		var slider := pair[0] as HSlider
		var field: String = pair[1]
		slider.value_changed.connect(func(value: float) -> void: _on_volume_changed(field, value, slider))
		slider.drag_started.connect(func() -> void: _dragging = true)
		slider.drag_ended.connect(func(_moved: bool) -> void:
			_dragging = false
			changed.emit())  # Saved once, when the knob is let go.
	_muted.toggled.connect(_on_muted_toggled)
	_battle_speed.add_item("Normal", Settings.BattleSpeed.NORMAL)
	_battle_speed.add_item("Fast (x2)", Settings.BattleSpeed.FAST)
	_battle_speed.add_item("Instant (skip animations)", Settings.BattleSpeed.INSTANT)
	_battle_speed.item_selected.connect(func(index: int) -> void:
		_settings.battle_speed = _battle_speed.get_item_id(index) as Settings.BattleSpeed
		changed.emit())
	_auto_end_turn.toggled.connect(func(pressed: bool) -> void:
		_settings.auto_end_turn = pressed
		changed.emit())
	_window_mode.item_selected.connect(_on_window_mode_selected)
	_ui_scale.item_selected.connect(_on_ui_scale_selected)
	_reset_keys.pressed.connect(_on_reset_keys)
	_reset_save.pressed.connect(_on_reset_save_pressed)
	_confirm_yes.pressed.connect(_on_reset_save_confirmed)
	_confirm_no.pressed.connect(_hide_confirm)
	_show_hints.pressed.connect(_on_show_hints)
	_credits_button.pressed.connect(credits_pressed.emit)
	_confirm_row.hide()
	_message.text = ""


## The key rows' names are built in code, so a language change rebuilds them.
func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and _settings != null and is_node_ready():
		_build_bindings()
		_link_focus()


## Shows `settings` (edited in place from now on).
func show_settings(settings: Settings) -> void:
	_settings = settings
	_language.select(0)
	for index in range(1, _language.item_count):
		if _language.get_item_metadata(index) == settings.language:
			_language.select(index)
	_master.set_value_no_signal(settings.master_volume)
	_music.set_value_no_signal(settings.music_volume)
	_effects.set_value_no_signal(settings.effects_volume)
	_muted.set_pressed_no_signal(settings.muted)
	_battle_speed.select(_battle_speed.get_item_index(settings.battle_speed))
	_auto_end_turn.set_pressed_no_signal(settings.auto_end_turn)
	_window_mode.select(_window_mode.get_item_index(settings.window_mode))
	_ui_scale.select(Settings.UI_SCALES.find(settings.ui_scale))
	_build_bindings()
	_hide_confirm()
	_link_focus()


## Shows the audio settings again (the mute button in the corner changed one).
func sync_audio(settings: Settings) -> void:
	_master.set_value_no_signal(settings.master_volume)
	_music.set_value_no_signal(settings.music_volume)
	_effects.set_value_no_signal(settings.effects_volume)
	_muted.set_pressed_no_signal(settings.muted)


## A line under the controls for errors and confirmations ("" clears it).
func show_message(text: String) -> void:
	_message.text = text


func is_capturing() -> bool:
	return _capturing != &""


## Starts waiting for the key of `action` (what clicking its button does).
func begin_capture(action: StringName) -> void:
	_capturing = action
	_message.text = tr("Press a key for %s (Esc to cancel).") % Settings.action_label(action)
	_refresh_bindings()


func _input(event: InputEvent) -> void:
	if not is_capturing() or not (event is InputEventKey) or not event.pressed or event.echo:
		return
	get_viewport().set_input_as_handled()  # Before Esc can go back, or a key reach the game.
	var key := event as InputEventKey
	var action := _capturing
	# Some platforms (web, IMEs) report only the logical key.
	var code: int = key.physical_keycode if key.physical_keycode != KEY_NONE else key.keycode
	_capturing = &""
	if code == KEY_ESCAPE:
		_message.text = ""
	elif code in Settings.MODIFIER_KEYS or code <= 0:
		_capturing = action  # A modifier alone isn't a binding: keep waiting.
		return
	else:
		var error := SettingsApplier.set_binding(_settings, action, code)
		_message.text = error
		if error.is_empty():
			changed.emit()
	_refresh_bindings()


## Links the controls top to bottom (arrows and Tab): the page scrolls, and Godot's
## geometric focus search doesn't reach controls scrolled out of view.
func _link_focus() -> void:
	var chain: Array[Control] = [_back, _language]
	if _window_row.visible:
		chain.append(_window_mode)
	chain.append(_ui_scale)
	chain.append_array([_master, _music, _effects, _muted, _battle_speed, _auto_end_turn])
	for action in Settings.REBINDABLE:
		chain.append(_key_buttons[action])
	chain.append_array([_reset_keys, _show_hints, _reset_save, _credits_button])
	for i in chain.size():
		var control := chain[i]
		var above := chain[maxi(i - 1, 0)]
		var below := chain[mini(i + 1, chain.size() - 1)]
		control.focus_neighbor_top = control.get_path_to(above)
		control.focus_neighbor_bottom = control.get_path_to(below)
		control.focus_previous = control.get_path_to(above)
		control.focus_next = control.get_path_to(below)
	_confirm_no.focus_neighbor_right = _confirm_no.get_path_to(_confirm_yes)
	_confirm_yes.focus_neighbor_left = _confirm_yes.get_path_to(_confirm_no)
	_confirm_no.focus_neighbor_top = _confirm_no.get_path_to(_show_hints)
	_confirm_yes.focus_neighbor_top = _confirm_yes.get_path_to(_show_hints)


func _build_bindings() -> void:
	for child in _bindings.get_children():
		_bindings.remove_child(child)
		child.queue_free()
	_key_buttons.clear()
	for action in Settings.REBINDABLE:
		var label := Label.new()
		label.text = Settings.action_label(action)
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_bindings.add_child(label)
		var button := Button.new()
		button.name = "Key_%s" % action
		button.custom_minimum_size = Vector2(160, 40)
		button.pressed.connect(begin_capture.bind(action))
		_bindings.add_child(button)
		_key_buttons[action] = button
	_refresh_bindings()


func _refresh_bindings() -> void:
	for action in _key_buttons:
		_key_buttons[action].text = "Press a key..." if action == _capturing else SettingsApplier.key_text(action)


func _on_language_selected(index: int) -> void:
	_settings.language = "" if index == 0 else str(_language.get_item_metadata(index))
	changed.emit()


func _on_volume_changed(field: String, value: float, _slider: HSlider) -> void:
	_settings.set(field, value)
	if _dragging:
		audio_live.emit()  # Heard at once; saved when released.
	else:
		changed.emit()  # A key press or a programmatic change: no drag to wait for.


func _on_muted_toggled(pressed: bool) -> void:
	_settings.muted = pressed
	changed.emit()


func _on_window_mode_selected(index: int) -> void:
	_settings.window_mode = _window_mode.get_item_id(index) as Settings.WindowMode
	changed.emit()


func _on_ui_scale_selected(index: int) -> void:
	_settings.ui_scale = Settings.UI_SCALES[index]
	changed.emit()


func _on_reset_keys() -> void:
	_capturing = &""
	SettingsApplier.reset_bindings(_settings)
	_message.text = "Keys reset."
	_refresh_bindings()
	changed.emit()


func _on_reset_save_pressed() -> void:
	_confirm_row.show()
	_reset_save.hide()
	_confirm_no.grab_focus()  # The safe answer first.


func _hide_confirm() -> void:
	var focused := get_viewport().gui_get_focus_owner() if is_inside_tree() else null
	var had_focus := focused != null and _confirm_row.is_ancestor_of(focused)
	_confirm_row.hide()
	_reset_save.show()
	if had_focus:
		_reset_save.grab_focus()  # The focused answer just vanished: keep the keyboard somewhere.


func _on_reset_save_confirmed() -> void:
	_hide_confirm()
	reset_save_confirmed.emit()


func _on_show_hints() -> void:
	_settings.dismissed_hints.clear()
	_message.text = "Hints will show again."
	changed.emit()
