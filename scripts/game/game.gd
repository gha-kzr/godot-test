class_name Game
extends Node
## The game's root: owns the profile and its save, and swaps its one child screen between
## the party screen (the hub), a battle and the run screen between floors. The run's rules
## are RunDirector's: this root asks it for the next battle, hands it each result and boss
## choice, saves the profile after every step (so a run resumes at the next floor) and shows
## the report. No global state: everything a screen needs is passed to it (calls down,
## signals up).

const PARTY_SCENE := preload("res://scenes/game/party_screen.tscn")
const RUN_SCENE := preload("res://scenes/game/run_screen.tscn")
const BATTLE_SCENE := preload("res://scenes/battle/battle.tscn")
const SAVE_FAILED := "Progress couldn't be saved."

@export var roster: Roster
## The tower's floors, boons and stages.
@export var tower: TowerConfig
@export var save_path := SaveStore.DEFAULT_PATH
## 0 picks a random seed per battle (floors are deterministic anyway; this is the dice).
@export var rng_seed := 0

var profile: Profile
var screen: Node
var _store: SaveStore
## What the last run brought, shown on the hub.
var _summary := ""
## The state whose result was applied, so a battle can't count twice, and its report.
var _applied_state: BattleState
var _report: RunDirector.Report
var _battle_title := ""


func _ready() -> void:
	_store = SaveStore.new(save_path)
	profile = _store.load_or_create(roster)
	show_party()


func show_party(message := "") -> void:
	var party := PARTY_SCENE.instantiate() as PartyScreen
	_replace_screen(party)
	party.tower_pressed.connect(start_tower)
	party.stage_pressed.connect(start_stage)
	party.continue_pressed.connect(next_step)
	party.abandon_pressed.connect(_on_abandon_pressed)
	party.equip_requested.connect(_on_equip_requested)
	party.unequip_requested.connect(_on_unequip_requested)
	party.show_profile(profile, _summary, message, tower)


func start_tower(start_floor: int) -> void:
	if _tower_invalid():
		return
	_start_run(RunDirector.start_tower(profile, tower, start_floor))


func start_stage(stage_index: int) -> void:
	if _tower_invalid():
		return
	var stage := tower.stages[stage_index] if stage_index >= 0 and stage_index < tower.stages.size() else null
	_start_run(RunDirector.start_stage(profile, tower, stage))


## The run's next step: its pending boss choice, or its next battle (the hub when none).
func next_step() -> void:
	if profile.run == null:
		show_party()
	elif profile.run.awaiting_choice():
		var report := RunDirector.Report.new()
		report.won = true
		report.lines.append("Pick a boon, or heal the party instead.")
		_show_run_screen(report, "Floor %d boss defeated" % profile.run.floor_number)
	else:
		start_battle()


func start_battle() -> void:
	if _tower_invalid():
		return
	var setup := RunDirector.battle_setup(profile, tower)
	var errors := setup.encounter.get_validation_errors() if setup.encounter != null else PackedStringArray(["no encounter"])
	if not errors.is_empty():
		show_party("The floor's encounter is invalid: %s" % "; ".join(errors))
		return
	var spawns := setup.encounter.map.parse().player_spawns.size()
	if profile.party.is_empty() or profile.party.size() > spawns:
		show_party("The party needs 1 to %d heroes to fight on this map." % spawns)
		return
	var battle := BATTLE_SCENE.instantiate() as BattleController
	battle.setup(setup.encounter, setup.units, setup.modifiers, rng_seed, setup.hero_hp,
			setup.sudden_death_round, setup.sudden_death_percent, setup.title)
	battle.battle_ended.connect(_apply_battle_result)
	battle.battle_finished.connect(_on_battle_finished)
	_battle_title = setup.title
	_replace_screen(battle)
	if battle.battle == null:
		show_party("The battle couldn't start (see the log).")


## Shows the hub with the tower's errors, if any (a battle can't be generated from them).
func _tower_invalid() -> bool:
	var errors := tower.get_validation_errors() if tower != null else PackedStringArray(["no tower set"])
	if errors.is_empty():
		return false
	show_party("The tower is invalid: %s" % "; ".join(errors))
	return true


func _start_run(error: String) -> void:
	if not error.is_empty():
		show_party(error)
		return
	_summary = ""
	_save()
	next_step()


## The battle's result screen was closed: the run screen shows what happened (the result
## is applied here if that was skipped).
func _on_battle_finished(state: BattleState) -> void:
	_apply_battle_result(state)
	var title := ("%s cleared" if _report.won else "%s lost") % _battle_title
	_show_run_screen(_report, title)


## As soon as a battle ends, its result goes to the director (rewards, HP, next floor or
## run end) and the profile is saved.
func _apply_battle_result(state: BattleState) -> void:
	if state == _applied_state:
		return
	_applied_state = state
	_report = RunDirector.apply_result(profile, tower, state)
	_save()


func _show_run_screen(report: RunDirector.Report, title: String) -> void:
	var run_screen := RUN_SCENE.instantiate() as RunScreen
	_replace_screen(run_screen)
	run_screen.next_pressed.connect(next_step)
	run_screen.boss_choice_made.connect(_on_boss_choice_made)
	run_screen.back_pressed.connect(_on_back_pressed.bind(report))
	run_screen.show_report(report, profile, title)


func _on_boss_choice_made(choice: int, keep_going: bool) -> void:
	var report := RunDirector.apply_boss_choice(profile, choice, keep_going)
	_save()
	if report.run_over:
		_show_run_screen(report, "Run complete")
	else:
		next_step()


## Back to the hub, with the run's last report as its summary.
func _on_back_pressed(report: RunDirector.Report) -> void:
	_summary = "\n".join(report.lines)
	show_party()


func _on_abandon_pressed() -> void:
	profile.run = null
	_summary = "Run abandoned."
	_save()
	show_party()


func _on_equip_requested(hero_index: int, stash_index: int) -> void:
	var error := profile.equip(hero_index, stash_index)
	if error.is_empty() and not _save():
		error = SAVE_FAILED
	(screen as PartyScreen).show_profile(profile, _summary, error, tower)


func _on_unequip_requested(hero_index: int, slot: int) -> void:
	var error := profile.unequip(hero_index, slot)
	if error.is_empty() and not _save():
		error = SAVE_FAILED
	(screen as PartyScreen).show_profile(profile, _summary, error, tower)


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
