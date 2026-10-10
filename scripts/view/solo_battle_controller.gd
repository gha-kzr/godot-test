class_name SoloBattleController
extends BattleController
## The single-player fight: the battle comes from an encounter (a tower floor, a stage, a QA battle, or battle.tscn's own
## exports), the AI plays every unit that is not the player's, and the first-run help lives here: the guided tutorial,
## the one-time tips and the QA tools (cheats and Auto).
##
## Standalone (battle.tscn run on its own) it plays from its exports and the result screen offers "Play again". Run by
## the Game root, setup() injects the battle before it enters the tree, and the result screen's "Continue" emits
## battle_finished.

## A tutorial step was finished or skipped (the Game root saves the settings).
signal tutorial_changed

## Pause before each AI action, so the player can follow what happens.
const ENEMY_ACTION_DELAY := 0.35

## The fight: map, enemies (levels, presets) and their AI profile.
@export var encounter: Encounter
@export var players: Array[UnitData] = []
## Fallback AI profile when neither the enemy's preset nor the encounter sets one.
@export var ai_profile: AIProfile
## 0 picks a random seed for each battle.
@export var rng_seed := 0
## Permanent modifiers of each player unit (levels, runes), parallel to `players`.
var player_modifiers: Array = []
## Starting HP per player (-1: full), from a run.
var player_hp: Array = []

## The first-run hints (null: none) and the id of the one to show when the battle opens ("" for none).
var hints: Hints
var opening_tip := ""
var _tip_id := ""

## A QA battle (from the QA screen): the cheat bar is offered; nothing of it is saved.
var qa_battle := false
## QA tools: the AI plays the heroes (EnemyAI is team-agnostic) until switched off.
var auto_play := false
## The guided first steps (null: none, as in a standalone battle); the Game root hands it in.
var tutorial: Tutorial
var _step: Dictionary = {}


## Injects a battle. Call before the controller enters the tree (its _ready starts it).
## `hero_hp`: starting HP per player (-1: full); `title`: shown in the HUD (e.g. "Floor 3").
func setup(battle_encounter: Encounter, player_units: Array[UnitData], modifiers: Array, battle_rng_seed := 0,
		hero_hp: Array = [], death_round := 0, death_percent := 10, title := "", levels: Array = []) -> void:
	encounter = battle_encounter
	players = player_units
	player_modifiers = modifiers
	rng_seed = battle_rng_seed
	player_hp = hero_hp
	sudden_death_round = death_round
	sudden_death_percent = death_percent
	battle_title = title
	player_levels = levels
	standalone = false


## Auto (QA tools): the AI plays the heroes from their next decision on; switched off, the
## player takes over at the next hero turn (or at once, between two of the AI's actions).
func set_auto_play(on: bool) -> void:
	auto_play = on
	hud.set_auto(on)
	if on and input_state in [State.IDLE, State.TARGETING] and battle.state.current_unit().team == UnitState.Team.PLAYER:
		selected_spell = -1
		selected_card = -1
		_set_state(State.ENEMY_TURN)
		_run_enemy_action()


## Whether Auto may be offered: QA tools on, and no tutorial step waiting for the player.
func _auto_available() -> bool:
	return settings.qa_tools and (tutorial == null or tutorial.next_step(Tutorial.BATTLE_STEPS).is_empty())


## QA battles' cheats, on the player's turn: win, lose, kill the pinned unit, heal the
## heroes, refill the acting hero's AP and MP.
func qa_cheat(action: StringName) -> void:
	if not qa_battle or not input_state in [State.IDLE, State.TARGETING]:
		return
	var events: Array[BattleEvents.Event] = []
	match action:
		&"win", &"lose":
			var team := UnitState.Team.ENEMY if action == &"win" else UnitState.Team.PLAYER
			for unit in battle.state.units:
				if unit.team == team:
					events.append_array(battle.qa_set_hp(unit.id, 0))
		&"kill":
			if _pinned_unit != -1:
				events.append_array(battle.qa_set_hp(_pinned_unit, 0))
		&"heal":
			for unit in battle.state.units:
				if unit.team == UnitState.Team.PLAYER:
					events.append_array(battle.qa_set_hp(unit.id, unit.max_hp()))
		&"refill":
			var unit := battle.state.current_unit()
			unit.ap = unit.max_ap()
			unit.mp = unit.max_mp()
			unit.commit_position()
			_refresh_hud()
			_enter_idle()
			return
	if not events.is_empty():
		_play(events)


func _process(delta: float) -> void:
	super._process(delta)
	if not _step.is_empty():
		hud.update_tutorial_area(_tutorial_rect(_step["spot"]))  # The camera may be moving; the HUD settles after its first frame.


func _run_enemy_action() -> void:
	var generation := _battle_generation
	if event_player.instant:
		await get_tree().process_frame
	else:
		await create_tween().tween_interval(ENEMY_ACTION_DELAY).finished
	if generation != _battle_generation:
		return
	var unit_id := battle.state.current_unit().id
	var result := battle.perform(EnemyAI.choose_next(battle.state, unit_id, _ai_profile_for(battle.state.units[unit_id])))
	if not result.ok():
		push_error("Battle: AI chose an invalid action: %s" % result.error)
		result = battle.perform(BattleActions.EndTurn.new(unit_id))
	_play(result.events)


## The unit's own profile (its preset), else the encounter's, else the fallback.
func _ai_profile_for(unit: UnitState) -> AIProfile:
	if unit.ai_profile != null:
		return unit.ai_profile
	return encounter.ai_profile if encounter.ai_profile != null else ai_profile


## Shows a one-time tip card (not while a tutorial step is up, and never twice), lighting
## the screen area `spotlight` returns (none by default).
func _show_tip(id: String, spotlight := Callable()) -> void:
	if hints == null or not hints.should_show(id) or hud.is_tutorial_active():
		return
	_tip_id = id
	hud.show_hint(hints.text(id), spotlight)


## A spotlight on a unit (feet to head), followed as it moves.
func _unit_spotlight(unit_id: int) -> Callable:
	return func() -> Rect2: return _unit_screen_rect(unit_id)


## A spotlight on the status icons above a unit.
func _status_spotlight(unit_id: int) -> Callable:
	return func() -> Rect2:
		var view := units_view.find_view(unit_id)
		return view.status_row_rect(camera_rig.camera) if view != null and camera_rig.camera != null else Rect2()


func _connect_extras() -> void:
	hud.hint_dismissed.connect(_on_tip_dismissed)
	hud.auto_toggled.connect(set_auto_play)
	hud.qa_cheat.connect(qa_cheat)
	hud.tutorial_skipped.connect(_skip_tutorial)


## The elite or boss opens the enemy list.
func _battle_started() -> void:
	if not opening_tip.is_empty():
		_show_tip(opening_tip, _unit_spotlight(_first_enemy_id()))


func _first_enemy_id() -> int:
	for unit in battle.state.units:
		if unit.team == UnitState.Team.ENEMY:
			return unit.id
	return -1


func _allows(action: Tutorial.Action) -> bool:
	return Tutorial.allows(_step, action)


func _waiting_for_guide() -> bool:
	return not _step.is_empty()


func _event_seen(event: BattleEvents.Event) -> void:
	if event is BattleEvents.StatusApplied:
		_show_tip("first_status", _status_spotlight((event as BattleEvents.StatusApplied).unit_id))


func _refresh_extras() -> void:
	hud.show_qa_controls(_auto_available(), qa_battle and input_state != State.ENDED,
			input_state == State.IDLE or input_state == State.TARGETING)
	_refresh_tutorial()


## The player acts on their turn, the AI on every other (and on the player's too while Auto is on).
func _next_turn() -> void:
	if battle.state.current_unit().team == UnitState.Team.PLAYER and not auto_play:
		_enter_idle()
	else:
		_set_state(State.ENEMY_TURN)
		_run_enemy_action()


## The state of the battle about to start, from the encounter and the players; null (with an error) if they
## are invalid.
func _create_battle_state() -> BattleState:
	if encounter == null or encounter.map == null:
		push_error("Battle: no encounter or map set")
		return null
	var errors := encounter.get_validation_errors()
	if not errors.is_empty():
		push_error("Battle: invalid encounter: %s" % "; ".join(errors))
		return null
	var parsed := encounter.map.parse()
	var builds := encounter.builds()
	var enemies: Array[UnitData] = []
	for build in builds:
		enemies.append(build.unit)
	var new_seed := rng_seed if rng_seed != 0 else randi()
	battle_seed = new_seed
	return BattleState.create(parsed, players, enemies, new_seed, player_modifiers, builds, player_hp)


## The screen rectangle around a unit as drawn right now, feet to head (empty if it has no view).
func _unit_screen_rect(unit_id: int) -> Rect2:
	var view := units_view.find_view(unit_id)
	if view == null or camera_rig.camera == null:
		return Rect2()
	var feet := camera_rig.camera.unproject_position(view.global_position)
	var head := camera_rig.camera.unproject_position(view.global_position + Vector3.UP * view.world_height())
	var height := absf(feet.y - head.y)
	return Rect2(Vector2(feet.x - height * 0.4, minf(feet.y, head.y)), Vector2(height * 0.8, height))


func _on_tip_dismissed() -> void:
	if hints != null and not _tip_id.is_empty():
		hints.dismiss(_tip_id)
		_tip_id = ""
		tutorial_changed.emit()  # The Game root saves the settings.


## Marks the current tutorial step done when the player did what it waits for.
func _action_done(action: Tutorial.Action) -> void:
	if tutorial != null and not _step.is_empty() and _step["awaits"] == action:
		tutorial.complete(_step["id"])
		_step = {}
		hud.hide_tutorial()
		tutorial_changed.emit()


## Shows the first step not done, when the state is the one it is about; steps that can't apply
## (a hero who can't move) are skipped as done.
func _refresh_tutorial() -> void:
	_step = {}
	if tutorial == null or battle == null or battle.state.is_over():
		hud.hide_tutorial()
		return
	for guard in Tutorial.BATTLE_STEPS.size():
		var step := tutorial.next_step(Tutorial.BATTLE_STEPS)
		if step.is_empty() or not _tutorial_can_show(step):
			if not step.is_empty() and _tutorial_obsolete(step):
				tutorial.complete(step["id"])
				tutorial_changed.emit()
				continue
			hud.hide_tutorial()
			return
		_step = step
		hud.show_tutorial_step(Tutorial.text_of(step), _tutorial_rect(step["spot"]))
		return
	hud.hide_tutorial()


## The step's moment has come: the state it talks about.
func _tutorial_can_show(step: Dictionary) -> bool:
	match step["awaits"]:
		Tutorial.Action.READY: return input_state == State.PLACING
		Tutorial.Action.MOVE: return input_state == State.IDLE and _reach != null and not _reach.cells().is_empty()
		Tutorial.Action.SELECT_SPELL: return input_state == State.IDLE and _can_cast_any()
		Tutorial.Action.CAST: return input_state == State.TARGETING and not _targetable.is_empty()
		Tutorial.Action.END_TURN: return input_state == State.IDLE
	return false


## The step can never apply this turn (the hero can't move or cast): it counts as done.
func _tutorial_obsolete(step: Dictionary) -> bool:
	if input_state != State.IDLE:
		return false
	match step["awaits"]:
		Tutorial.Action.MOVE: return _reach != null and _reach.cells().is_empty()
		Tutorial.Action.SELECT_SPELL: return not _can_cast_any()
	return false


func _can_cast_any() -> bool:
	var unit := battle.state.current_unit()
	for slot in unit.data.spells.size():
		if BattleActions.CastSpell.can_afford(unit, slot):
			return true
	return false


func _skip_tutorial() -> void:
	if tutorial != null:
		tutorial.skip_all()
		_step = {}
		hud.hide_tutorial()
		tutorial_changed.emit()


## Screen rectangle of what a step lights.
func _tutorial_rect(spot: Tutorial.Spot) -> Rect2:
	match spot:
		Tutorial.Spot.READY_BUTTON, Tutorial.Spot.END_TURN_BUTTON: return hud.end_turn_rect()
		Tutorial.Spot.SPELL_BAR: return hud.spell_slots_rect()
		Tutorial.Spot.REACH: return _screen_rect_of(_reach.cells() if _reach != null else [] as Array[Vector2i])
		Tutorial.Spot.TARGETS: return _screen_rect_of(_targetable.keys() as Array[Vector2i] if not _targetable.is_empty() else [] as Array[Vector2i])
	return Rect2()


## The screen rectangle around the top faces of board cells.
func _screen_rect_of(cells: Array[Vector2i]) -> Rect2:
	var box := Rect2()
	var first := true
	for cell in cells:
		var center := board_view.cell_to_world(cell)
		for corner in [Vector2(-0.5, -0.5), Vector2(0.5, -0.5), Vector2(-0.5, 0.5), Vector2(0.5, 0.5)]:
			var point := camera_rig.camera.unproject_position(center + Vector3(corner.x, 0.0, corner.y) * BoardView.CELL_SIZE)
			box = Rect2(point, Vector2.ZERO) if first else box.expand(point)
			first = false
	return box


## The enemy's spells are not shown during its turn (as in multiplayer, where the bar is always the player's own).
func _spells_unit_id() -> int:
	var id := super._spells_unit_id()
	var info := _hud_model.infos.get(id) as UnitInfo
	return id if info != null and info.is_player else -1
