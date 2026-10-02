@tool
class_name Hints
extends RefCounted
## First-run hints: which ones the player already dismissed (kept in Settings), and their
## texts. Removing hints from the game means deleting this class, HintCard and the
## `show_hint` calls.

const TEXTS: Dictionary[String, String] = {
	"hub_intro": "Click a rune in the stash to equip it on the selected hero, then climb the tower or try a stage.",
	"first_battle": "Place your heroes on the teal cells, then press Ready ({end_turn}). Hover anything for details; click a unit to pin its card.",
}

var _settings: Settings


func _init(settings: Settings) -> void:
	_settings = settings


## Whether hint `id` is known and not yet dismissed.
func should_show(id: String) -> bool:
	return TEXTS.has(id) and id not in _settings.dismissed_hints


## The hint's text, with {action} placeholders replaced by the key bound to that action.
func text(id: String) -> String:
	var result := tr(TEXTS.get(id, ""))  # The texts stay English: they are the message ids.
	for action in Settings.REBINDABLE:
		result = result.replace("{%s}" % action, SettingsApplier.key_text(action))
	return result


func dismiss(id: String) -> void:
	if id not in _settings.dismissed_hints:
		_settings.dismissed_hints.append(id)


## Show every hint again.
func reset() -> void:
	_settings.dismissed_hints.clear()
