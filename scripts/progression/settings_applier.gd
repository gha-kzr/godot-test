@tool
class_name SettingsApplier
extends RefCounted
## Puts Settings into effect: language, UI scale, window mode (not on mobile, not in the editor's
## embedded game window) and the InputMap. The one place where platforms differ.

## Project defaults of the rebindable actions, captured before the first remap so keys
## can be reset.
static var _default_events: Dictionary[StringName, Array] = {}


## `from_user`: false at startup, where browsers refuse fullscreen without a user gesture.
static func apply(settings: Settings, window: Window, from_user := true) -> void:
	Localization.apply(settings.language)
	apply_audio(settings)
	if window != null:
		window.content_scale_factor = settings.ui_scale
		if supports_window_mode() and (from_user or not OS.has_feature("web")):
			window.mode = Window.MODE_FULLSCREEN if settings.window_mode == Settings.WindowMode.FULLSCREEN else Window.MODE_WINDOWED
	apply_bindings(settings)


## The volume sliders and the mute onto the audio buses.
static func apply_audio(settings: Settings) -> void:
	AudioService.ensure_buses()
	AudioService.set_bus_volume(AudioService.MASTER_BUS, settings.master_volume)
	AudioService.set_bus_volume(AudioService.MUSIC_BUS, settings.music_volume)
	AudioService.set_bus_volume(AudioService.EFFECTS_BUS, settings.effects_volume)
	AudioServer.set_bus_mute(AudioServer.get_bus_index(AudioService.MASTER_BUS), settings.muted)


## Fullscreen and windowed are offered everywhere but on phones and tablets, and not in the
## editor's embedded game window (the editor sizes it).
static func supports_window_mode() -> bool:
	return not OS.has_feature("mobile") and not Engine.is_embedded_in_editor()


## Rewrites the rebindable actions: the project defaults, with the key swapped for the
## player's where they changed it.
static func apply_bindings(settings: Settings) -> void:
	_capture_defaults()
	for action in Settings.REBINDABLE:
		InputMap.action_erase_events(action)
		for event: InputEvent in _default_events[action]:
			InputMap.action_add_event(action, event)
		if settings.bindings.has(action):
			_replace_key(action, settings.bindings[action])


## Binds `action` to a key. Returns an error text (nothing changes) if another rebindable
## action already uses it, else "".
static func set_binding(settings: Settings, action: StringName, keycode: int) -> String:
	if not Settings.is_bindable_key(keycode):
		return TranslationServer.translate("That key can't be used.") if keycode <= 0 or keycode in Settings.MODIFIER_KEYS \
				else TranslationServer.translate("%s is reserved for the menus.") % OS.get_keycode_string(keycode as Key)
	var other := action_using_key(keycode, action)
	if other != &"":
		return TranslationServer.translate("%s is already used by %s.") % [OS.get_keycode_string(keycode as Key), Settings.action_label(other)]
	settings.bindings[action] = keycode
	apply_bindings(settings)
	return ""


static func reset_bindings(settings: Settings) -> void:
	settings.bindings.clear()
	apply_bindings(settings)


## The physical keycode an action currently uses (0: none).
static func key_of(action: StringName) -> int:
	for event in InputMap.action_get_events(action):
		if event is InputEventKey:
			return (event as InputEventKey).physical_keycode
	return 0


## What the key of `action` is called on the player's keyboard layout (e.g. "A" on AZERTY
## for the physical Q), "" when unbound.
static func key_text(action: StringName) -> String:
	var physical := key_of(action)
	if physical == 0:
		return ""
	if physical >= KEY_0 and physical <= KEY_9:
		return str(physical - KEY_0)  # The number row reads "1".."9" on any layout (AZERTY has "&" there).
	# The headless display server has no keyboard layout; the physical key names it then.
	var label := KEY_NONE if DisplayServer.get_name() == "headless" else DisplayServer.keyboard_get_label_from_physical(physical as Key)
	return OS.get_keycode_string((label if label != KEY_NONE else physical) as Key)


## The other action using `keycode` (rebindable, or a fixed spell key), or &"".
static func action_using_key(keycode: int, except: StringName) -> StringName:
	for action in Settings.REBINDABLE + Settings.FIXED_KEYED_ACTIONS:
		if action != except and key_of(action) == keycode:
			return action
	return &""


static func _replace_key(action: StringName, keycode: int) -> void:
	for event in InputMap.action_get_events(action):
		if event is InputEventKey:
			InputMap.action_erase_event(action, event)
	var key := InputEventKey.new()
	key.physical_keycode = keycode as Key
	InputMap.action_add_event(action, key)


static func _capture_defaults() -> void:
	if not _default_events.is_empty():
		return
	for action in Settings.REBINDABLE:
		var events: Array = []
		for event in InputMap.action_get_events(action):
			events.append(event.duplicate())
		_default_events[action] = events
