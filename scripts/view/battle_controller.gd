class_name BattleController
extends Node3D
## Battle scene root: creates the battle, wires views, HUD and camera, and runs the turn
## loop. Player clicks and AI choices both become actions that go through the same path:
## Battle.perform() → EventPlayer.play() → views sync to the state → next turn.
##
## Input states (enum FSM): IDLE (player's turn, moving), TARGETING (a spell is aimed),
## ANIMATING (events playing), ENEMY_TURN (the AI is acting), ENDED (result shown).
## Signals up from the HUD and camera, calls down to them.
##
## Standalone (battle.tscn run on its own) it plays from its exports and the result
## screen offers "Play again". Run by the Game root, setup() injects the battle before it
## enters the tree, and the result screen's "Continue" emits battle_finished.

## The battle just ended (the result screen shows). The state is final: the caller applies
## and saves rewards now, so closing the game on the result screen loses nothing.
signal battle_ended(state: BattleState)
## A battle set up by setup() ended and the player chose to continue.
signal battle_finished(state: BattleState)

enum State { IDLE, TARGETING, ANIMATING, ENEMY_TURN, ENDED }

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
## False once setup() was called: the Game root owns what happens after the battle.
var standalone := true

var battle: Battle
## The seed of the current battle; set rng_seed to it to replay a battle.
var battle_seed := 0
var input_state := State.ENDED
var selected_spell := -1

var _hovered_cell := BoardView.NO_CELL
var _reach: Movement.Reach
var _targetable: Dictionary[Vector2i, bool] = {}
## Bumped by each new battle; coroutines of an abandoned battle stop after their awaits.
var _battle_generation := 0

@onready var camera_rig: CameraRig = $CameraRig
@onready var board_view: BoardView = $BoardView
@onready var units_view: UnitsView = $UnitsView
@onready var event_player: EventPlayer = $EventPlayer
@onready var hud: Hud = $Hud


## Injects a battle. Call before the controller enters the tree (its _ready starts it).
func setup(battle_encounter: Encounter, player_units: Array[UnitData], modifiers: Array, battle_rng_seed := 0) -> void:
	encounter = battle_encounter
	players = player_units
	player_modifiers = modifiers
	rng_seed = battle_rng_seed
	standalone = false


func _ready() -> void:
	hud.spell_selected.connect(select_spell)
	hud.end_turn_pressed.connect(end_turn)
	hud.view_toggle_pressed.connect(func() -> void: camera_rig.set_overhead(not camera_rig.overhead))
	hud.restart_pressed.connect(_on_result_action)
	hud.set_result_action_text("Play again" if standalone else "Continue")
	camera_rig.overhead_changed.connect(hud.set_overhead_view)
	event_player.event_played.connect(_on_event_played)
	start_battle()


## Builds a fresh battle from the encounter and the players, and starts it.
## Returns false (and changes nothing) if the encounter or teams are invalid.
func start_battle() -> bool:
	if encounter == null or encounter.map == null:
		push_error("Battle: no encounter or map set")
		return false
	var errors := encounter.get_validation_errors()
	if not errors.is_empty():
		push_error("Battle: invalid encounter: %s" % "; ".join(errors))
		return false
	var parsed := encounter.map.parse()
	var builds := encounter.builds()
	var enemies: Array[UnitData] = []
	for build in builds:
		enemies.append(build.unit)
	var new_seed := rng_seed if rng_seed != 0 else randi()
	var battle_state := BattleState.create(parsed, players, enemies, new_seed, player_modifiers, builds)
	if battle_state == null:
		return false  # BattleState.create reported why.
	event_player.stop()  # Abandon the previous battle's playback, if any.
	battle_seed = new_seed
	_battle_generation += 1
	battle = Battle.new(battle_state)
	selected_spell = -1
	board_view.build(battle_state.grid)
	units_view.build(battle_state, board_view)
	event_player.setup(units_view, board_view)
	camera_rig.focus(board_view.center())
	camera_rig.face_toward(_spawn_center(parsed.player_spawns) - board_view.center())
	hud.hide_result()
	_play(battle.start())
	return true


## Abandons the current battle (even mid-animation) and starts a new one.
func restart() -> void:
	start_battle()


func _on_result_action() -> void:
	if standalone:
		restart()
	else:
		battle_finished.emit(battle.state)


# --- Player commands (from the HUD and board clicks) ---

## Selects a spell to aim, or unselects it if it's already selected.
func select_spell(index: int) -> void:
	if input_state != State.IDLE and input_state != State.TARGETING:
		return
	var unit := battle.state.current_unit()
	if index == selected_spell or not BattleActions.CastSpell.can_afford(unit, index):
		_enter_idle()
		return
	selected_spell = index
	_set_state(State.TARGETING)


func cancel() -> void:
	if input_state == State.TARGETING:
		_enter_idle()


func end_turn() -> void:
	if input_state == State.IDLE or input_state == State.TARGETING:
		_perform(BattleActions.EndTurn.new(battle.state.current_unit().id))


## A click on a board cell (or on a unit standing there).
func click_cell(cell: Vector2i) -> void:
	var unit_id := battle.state.current_unit().id if battle != null else -1
	match input_state:
		State.IDLE:
			if _reach != null and _reach.can_reach(cell):
				_perform(BattleActions.Move.new(unit_id, cell))
		State.TARGETING:
			if _targetable.has(cell):
				_perform(BattleActions.CastSpell.new(unit_id, selected_spell, cell))


# --- Input ---

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"cancel"):
		cancel()
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var cell := board_view.pick_cell(camera_rig.camera, event.position)
		if cell != BoardView.NO_CELL:
			click_cell(cell)
			get_viewport().set_input_as_handled()


## Hover is re-picked every physics frame from the mouse position, so it also follows
## camera turns and zooms; highlights only change when the hovered cell does.
func _physics_process(_delta: float) -> void:
	if board_view.grid == null:
		return
	var cell := _hover_cell(get_viewport().gui_get_hovered_control(), get_viewport().get_mouse_position())
	if cell != _hovered_cell:
		_hovered_cell = cell
		_update_hover()


## The cell the mouse designates: none over the HUD, except over the inspect panel, where
## the hover sticks (so the panel stays up and its tooltips can be read).
func _hover_cell(hovered_control: Control, mouse_position: Vector2) -> Vector2i:
	if hovered_control != null:
		return _hovered_cell if hud.is_inspect_control(hovered_control) else BoardView.NO_CELL
	return board_view.pick_cell(camera_rig.camera, mouse_position)


# --- Turn loop ---

func _perform(action: BattleActions.Action) -> void:
	var result := battle.perform(action)
	if not result.ok():
		push_warning("Battle: %s" % result.error)  # A UI bug; the state is unchanged.
		return
	_play(result.events)


func _play(events: Array[BattleEvents.Event]) -> void:
	var generation := _battle_generation
	_set_state(State.ANIMATING)
	await event_player.play(events)
	if generation != _battle_generation:
		return  # This battle was abandoned while its events played.
	units_view.sync(battle.state)
	_begin_next()


## Decides what happens after a playback: result, player's input, or the AI's next action.
func _begin_next() -> void:
	var battle_state := battle.state
	_refresh_hud()
	units_view.set_active(battle_state.current_unit().id if not battle_state.is_over() else -1)
	if battle_state.is_over():
		_set_state(State.ENDED)
		# A mutual wipe (DRAW) is shown as a defeat (decision record).
		hud.show_result(battle_state.outcome() == BattleState.Outcome.PLAYER_WON, battle_seed)
		battle_ended.emit(battle_state)
		return
	if battle_state.current_unit().team == UnitState.Team.PLAYER:
		_enter_idle()
	else:
		_set_state(State.ENEMY_TURN)
		_run_enemy_action()


func _run_enemy_action() -> void:
	var generation := _battle_generation
	await create_tween().tween_interval(ENEMY_ACTION_DELAY).finished
	if generation != _battle_generation:
		return
	var unit_id := battle.state.current_unit().id
	var result := battle.perform(EnemyAI.choose_next(battle.state, unit_id, _ai_profile_for(battle.state.units[unit_id])))
	if not result.ok():
		push_error("Battle: AI chose an invalid action: %s" % result.error)
		result = battle.perform(BattleActions.EndTurn.new(unit_id))
	_play(result.events)


## The HUD is refreshed after a whole playback (in _begin_next), not per event: the
## battle state is already final while events play, so a per-event refresh would jump
## ahead of the animations. Unit views show HP live; an event-driven HUD is milestone 5.
## The unit's own profile (its preset), else the encounter's, else the fallback.
func _ai_profile_for(unit: UnitState) -> AIProfile:
	if unit.ai_profile != null:
		return unit.ai_profile
	return encounter.ai_profile if encounter.ai_profile != null else ai_profile


func _on_event_played(event: BattleEvents.Event) -> void:
	if event is BattleEvents.TurnStarted:
		var unit := battle.state.units[(event as BattleEvents.TurnStarted).unit_id]
		hud.show_banner("%s's turn" % unit.data.display_name)


# --- State and highlights ---

func _enter_idle() -> void:
	selected_spell = -1
	_set_state(State.IDLE)


func _set_state(new_state: State) -> void:
	input_state = new_state
	var player_turn := new_state == State.IDLE or new_state == State.TARGETING
	hud.set_player_controls_enabled(player_turn)
	hud.set_selected_spell(selected_spell if new_state == State.TARGETING else -1)
	board_view.clear_highlights()
	_reach = null
	_targetable.clear()
	var unit_id := battle.state.current_unit().id if battle != null and not battle.state.is_over() else -1
	match new_state:
		State.IDLE:
			_reach = Movement.reach(battle.state, unit_id)
			board_view.show_highlight(BoardView.Highlight.REACH, _reach.cells())
		State.TARGETING:
			var spell := battle.state.units[unit_id].data.spells[selected_spell]
			var cells := Targeting.targetable_cells(battle.state, unit_id, spell)
			for cell in cells:
				_targetable[cell] = true
			board_view.show_highlight(BoardView.Highlight.RANGE, cells)
			board_view.show_highlight(BoardView.Highlight.RANGE_BLOCKED,
					Targeting.blocked_cells(battle.state, unit_id, spell))
	_update_hover()


## Path to the hovered cell while moving, or the spell's area while aiming; in any state,
## the hovered unit (other than the one acting) in the HUD's inspect panel.
func _update_hover() -> void:
	_update_inspected()
	var cells: Array[Vector2i] = []
	match input_state:
		State.IDLE:
			if _reach != null and _reach.can_reach(_hovered_cell):
				cells = _reach.path_to(_hovered_cell)
			board_view.show_highlight(BoardView.Highlight.PATH, cells)
		State.TARGETING:
			if _targetable.has(_hovered_cell):
				var caster := battle.state.current_unit()
				var spell := caster.data.spells[selected_spell]
				cells = Targeting.area_cells(battle.state.grid, spell.area, caster.cell, _hovered_cell)
			board_view.show_highlight(BoardView.Highlight.AREA, cells)
		# Other states: _set_state already cleared the hover highlights, and the AREA layer
		# may be showing a cast's flash from the EventPlayer, which hover must not touch.


func _update_inspected() -> void:
	var hovered: UnitState = null
	if battle != null and _hovered_cell != BoardView.NO_CELL:
		hovered = battle.state.unit_at(_hovered_cell)
	if hovered == null or hovered == battle.state.current_unit():
		hud.hide_inspected()
	else:
		hud.show_inspected(Hud.UnitInfo.from_unit(hovered))


## Shows the current turn in the HUD. The HUD gets plain UnitInfo values, never state.
func _refresh_hud() -> void:
	var battle_state := battle.state
	var order: Array[Hud.UnitInfo] = []
	for id in battle_state.turn_order.upcoming():
		order.append(Hud.UnitInfo.from_unit(battle_state.units[id]))
	hud.show_turn_order(order, battle_state.turn_order.round_number)
	var current := battle_state.current_unit()
	if current != null:
		hud.show_unit(Hud.UnitInfo.from_unit(current))
		hud.show_spells(current.data.spells, current.ap)
	_update_inspected()


func _spawn_center(spawns: Array[Vector2i]) -> Vector3:
	var sum := Vector3.ZERO
	for cell in spawns:
		sum += board_view.cell_to_world(cell)
	return sum / maxi(spawns.size(), 1)
