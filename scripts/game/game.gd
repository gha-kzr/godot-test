class_name Game
extends Node
## The game's root: owns the profile and its save, and swaps its one child screen between
## the party screen and a battle. A battle is injected (BattleController.setup) and
## reports back through battle_finished; rewards are applied here, then the profile saved.
## No global state: everything a screen needs is passed to it (calls down, signals up).

const PARTY_SCENE := preload("res://scenes/game/party_screen.tscn")
const BATTLE_SCENE := preload("res://scenes/battle/battle.tscn")
const SAVE_FAILED := "Progress couldn't be saved."

@export var roster: Roster
## The battle every fight uses for now (milestone 4 generates them).
@export var map: MapData
@export var enemies: Array[UnitData] = []
@export var ai_profile: AIProfile
@export var save_path := SaveStore.DEFAULT_PATH
## 0 picks a random seed per battle.
@export var rng_seed := 0

var profile: Profile
var screen: Node
var _store: SaveStore
var _summary := ""
## The state whose rewards were applied, so a battle can't be rewarded twice.
var _rewarded_state: BattleState


func _ready() -> void:
	_store = SaveStore.new(save_path)
	profile = _store.load_or_create(roster)
	show_party()


func show_party(message := "") -> void:
	var party := PARTY_SCENE.instantiate() as PartyScreen
	_replace_screen(party)
	party.start_pressed.connect(start_battle)
	party.equip_requested.connect(_on_equip_requested)
	party.unequip_requested.connect(_on_unequip_requested)
	party.show_profile(profile, _summary, message)


func start_battle() -> void:
	var spawns := map.parse().player_spawns.size()
	if profile.party.is_empty() or profile.party.size() > spawns:
		show_party("The party needs 1 to %d heroes to fight on this map." % spawns)
		return
	var battle := BATTLE_SCENE.instantiate() as BattleController
	battle.setup(map, profile.battle_units(), profile.battle_modifiers(), enemies, ai_profile, rng_seed)
	battle.battle_ended.connect(_apply_battle_result)
	battle.battle_finished.connect(_on_battle_finished)
	_replace_screen(battle)
	if battle.battle == null:
		show_party("The battle couldn't start (see the log).")


## Back to the party screen; rewards were applied when the battle ended (applied here if
## that was skipped).
func _on_battle_finished(state: BattleState) -> void:
	_apply_battle_result(state)
	show_party()


## A won battle's rewards go to the profile (XP, levels, runes); a lost one gives nothing.
## Either way the profile is saved and the next party screen shows what happened.
func _apply_battle_result(state: BattleState) -> void:
	if state == _rewarded_state:
		return
	_rewarded_state = state
	var won := state.outcome() == BattleState.Outcome.PLAYER_WON
	var rewards := BattleRewards.compute(state)
	var lines: Array[String] = []
	if won:
		lines.append("Victory! +%d XP for each hero." % rewards.xp)
		for level_up in profile.apply_rewards(rewards):
			lines.append("%s reached level %d." % [profile.heroes[level_up.hero_index].hero.display_name(), level_up.to_level])
		if rewards.runes.is_empty():
			lines.append("No rune found.")
		else:
			lines.append("Found: %s." % ", ".join(rewards.runes.map(func(r: RuneData) -> String: return r.display_name)))
	else:
		lines.append("Defeat. Nothing gained from this fight; earlier progress is kept.")
	_summary = "\n".join(lines)
	_save()


func _on_equip_requested(hero_index: int, stash_index: int) -> void:
	var error := profile.equip(hero_index, stash_index)
	if error.is_empty() and not _save():
		error = SAVE_FAILED
	(screen as PartyScreen).show_profile(profile, _summary, error)


func _on_unequip_requested(hero_index: int, slot: int) -> void:
	var error := profile.unequip(hero_index, slot)
	if error.is_empty() and not _save():
		error = SAVE_FAILED
	(screen as PartyScreen).show_profile(profile, _summary, error)


## Saves the profile; a failure is added to the summary so the player knows.
func _save() -> bool:
	if _store.save(profile):
		return true
	if not _summary.contains(SAVE_FAILED):
		_summary = "\n".join([_summary, SAVE_FAILED].filter(func(t: String) -> bool: return not t.is_empty()))
	return false


## Swaps the current screen for `next`. The old one leaves the tree now and is freed at
## the end of the frame: it may be the one whose signal led here (a battle's Continue).
func _replace_screen(next: Node) -> void:
	if screen != null:
		remove_child(screen)
		screen.queue_free()
	screen = next
	add_child(next)
