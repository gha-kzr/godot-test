@tool
class_name Tutorial
extends RefCounted
## The guided first steps. Each step dims the screen except a spotlight (a control or an area of
## the board), shows a short card and waits until the player does that action; inputs outside the
## spotlight are blocked until then. Steps are done once: finished ids are kept in the settings'
## dismissed hints ("tutorial_<id>"), so "Show hints again" replays them, and Skip marks them all.
## Pure rules (no nodes): the battle controller and the party screen show and gate with them.

## What the player does to finish a step (and what the gate lets through).
enum Action { PLACE, READY, MOVE, SELECT_SPELL, CAST, END_TURN, EQUIP_RUNE }
## What is lit up.
enum Spot { READY_BUTTON, REACH, SPELL_BAR, TARGETS, END_TURN_BUTTON, RUNE_STASH }

const PREFIX := "tutorial_"
## The first battle, in order. `text` is an English message id ({end_turn} etc. become the bound key).
const BATTLE_STEPS: Array[Dictionary] = [
	{"id": "ready", "awaits": Action.READY, "spot": Spot.READY_BUTTON,
		"text": "Your heroes stand on the teal cells. Press Ready ({end_turn}) to start the fight."},
	{"id": "move", "awaits": Action.MOVE, "spot": Spot.REACH,
		"text": "It's your turn. Blue cells are where you can walk: each step costs MP. Click one."},
	{"id": "spell", "awaits": Action.SELECT_SPELL, "spot": Spot.SPELL_BAR,
		"text": "Spells cost AP. Pick one (or press its number) to see where it can reach."},
	{"id": "cast", "awaits": Action.CAST, "spot": Spot.TARGETS,
		"text": "Orange cells can be targeted. Click an enemy to cast the spell on it."},
	{"id": "end_turn", "awaits": Action.END_TURN, "spot": Spot.END_TURN_BUTTON,
		"text": "When you are done, end your turn ({end_turn}). The enemies play next."},
]
## In the hub, when the first rune lands in the stash.
const HUB_STEPS: Array[Dictionary] = [
	{"id": "equip", "awaits": Action.EQUIP_RUNE, "spot": Spot.RUNE_STASH,
		"text": "You found a rune! Click it in the stash to equip it on the selected hero."},
]

var _settings: Settings


func _init(settings: Settings) -> void:
	_settings = settings


func is_done(id: String) -> bool:
	return (PREFIX + id) in _settings.dismissed_hints


func complete(id: String) -> void:
	if not is_done(id):
		_settings.dismissed_hints.append(PREFIX + id)


## Marks every step done (the Skip link).
func skip_all() -> void:
	for step in BATTLE_STEPS + HUB_STEPS:
		complete(step["id"])


## The first step of `steps` not done yet ({} when all are).
func next_step(steps: Array[Dictionary]) -> Dictionary:
	for step in steps:
		if not is_done(step["id"]):
			return step
	return {}


## The step's text with the key placeholders replaced, translated.
static func text_of(step: Dictionary) -> String:
	var result := TranslationServer.translate(step["text"])
	for action in Settings.REBINDABLE:
		result = result.replace("{%s}" % action, SettingsApplier.key_text(action))
	return result


## Whether a player action goes through while `step` is the current one: the awaited action,
## and the harmless ones around it (placing heroes before Ready; changing or cancelling the spell
## while aiming).
static func allows(step: Dictionary, action: Action) -> bool:
	if step.is_empty() or action == step["awaits"]:
		return true
	match step["awaits"]:
		Action.READY: return action == Action.PLACE
		Action.CAST: return action == Action.SELECT_SPELL
	return false
