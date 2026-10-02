@tool
class_name Hints
extends RefCounted
## First-run hints: which ones the player already dismissed (kept in Settings), and their
## texts. Removing hints from the game means deleting this class, HintCard and the
## `show_hint` calls.

const TEXTS: Dictionary[String, String] = {
	"hub_intro": "Climb the tower to fight floor after floor, or try a stage: one hard battle that unlocks higher floors.",
	"first_status": "A status is on a unit: its icon shows the turns left. Hover the unit to read what it does.",
	"first_elite": "An elite floor: its enemies are stronger and drop better runes. Take your time.",
	"first_stage": "A stage: one hard boss fight. Win it to raise the tower's top floor and start your climbs higher.",
	"first_boss": "A boss floor! The boss is much stronger. Winning offers a boon (a bonus for the whole run) or a full heal.",
	"first_level_up": "A hero gained a level: its stats grow, and some levels teach a new spell.",
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
