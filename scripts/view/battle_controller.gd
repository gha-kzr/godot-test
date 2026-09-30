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

## PLACING: before the first turn, heroes are rearranged in the start zone until Ready.
enum State { PLACING, IDLE, TARGETING, ANIMATING, ENEMY_TURN, ENDED }

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
## Starting HP per player (-1: full), from a run.
var player_hp: Array = []
## Stalemate safety net (0: off); see Battle.sudden_death_round.
var sudden_death_round := 0
var sudden_death_percent := 10
## Shown before the round number in the HUD (e.g. "Floor 3").
var battle_title := ""
## The heroes' levels, parallel to `players` (shown in the HUD cards); empty: not shown.
var player_levels: Array = []
var _sudden_death_announced := false

var battle: Battle
## The seed of the current battle; set rng_seed to it to replay a battle.
var battle_seed := 0
var input_state := State.ENDED
var selected_spell := -1

var _hovered_cell := BoardView.NO_CELL
var _reach: Movement.Reach
var _targetable: Dictionary[Vector2i, bool] = {}
## The hero selected for placement (a unit id), or -1.
var _placing_hero := -1
## The unit whose card is pinned (a unit id), or -1; only the card's ✕ or Esc unpins.
var _pinned_unit := -1
## What the HUD displays, following the played events (see HudModel).
var _hud_model: HudModel
## The unit whose turn-order chip the mouse is over, or -1: its cell counts as hovered.
var _chip_unit := -1
## Bumped by each new battle; coroutines of an abandoned battle stop after their awaits.
var _battle_generation := 0

@onready var camera_rig: CameraRig = $CameraRig
@onready var board_view: BoardView = $BoardView
@onready var units_view: UnitsView = $UnitsView
@onready var event_player: EventPlayer = $EventPlayer
@onready var hud: Hud = $Hud


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


func _ready() -> void:
	hud.spell_selected.connect(select_spell)
	hud.end_turn_pressed.connect(end_turn)
	hud.view_toggle_pressed.connect(func() -> void: camera_rig.set_overhead(not camera_rig.overhead))
	hud.restart_pressed.connect(_on_result_action)
	hud.card_closed.connect(unpin)
	hud.chip_hovered.connect(_on_chip_hovered)
	hud.chip_unhovered.connect(_on_chip_unhovered)
	hud.chip_pressed.connect(_on_chip_pressed)
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
	var battle_state := BattleState.create(parsed, players, enemies, new_seed, player_modifiers, builds, player_hp)
	if battle_state == null:
		return false  # BattleState.create reported why.
	event_player.stop()  # Abandon the previous battle's playback, if any.
	battle_seed = new_seed
	_battle_generation += 1
	battle = Battle.new(battle_state)
	battle.sudden_death_round = sudden_death_round
	battle.sudden_death_percent = sudden_death_percent
	_sudden_death_announced = false
	selected_spell = -1
	board_view.build(battle_state.grid)
	units_view.build(battle_state, board_view)
	event_player.setup(units_view, board_view)
	camera_rig.focus(board_view.center())
	camera_rig.face_toward(_spawn_center(parsed.player_spawns) - board_view.center())
	hud.hide_result()
	_placing_hero = -1
	_pinned_unit = -1
	_chip_unit = -1
	_refresh_hud()
	_set_state(State.PLACING)
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


## Esc / right click: closes the order overlay, else stops aiming, else deselects the hero
## being placed, else unpins the card.
func cancel() -> void:
	if hud.close_order_overlay():
		return
	if input_state == State.TARGETING:
		_enter_idle()
	elif input_state == State.PLACING and _placing_hero != -1:
		_placing_hero = -1
		_set_state(State.PLACING)
	else:
		unpin()


## Pins a unit's card on the right; it stays until unpinned, even when the mouse leaves.
func pin(unit_id: int) -> void:
	if unit_id == _pinned_unit:
		return
	_pinned_unit = unit_id
	_update_inspected()


func unpin() -> void:
	if _pinned_unit != -1:
		_pinned_unit = -1
		_update_inspected()


## Ends the turn, or ends placement and starts the fight.
func end_turn() -> void:
	if input_state == State.PLACING:
		_placing_hero = -1
		_play(battle.start())
	elif input_state == State.IDLE or input_state == State.TARGETING:
		_perform(BattleActions.EndTurn.new(battle.state.current_unit().id))


## A click on a board cell (or on a unit standing there).
func click_cell(cell: Vector2i) -> void:
	var unit_id := battle.state.current_unit().id if battle != null else -1
	var clicked := battle.state.unit_at(cell) if battle != null else null
	var selecting_hero := input_state == State.PLACING and clicked != null and clicked.team == UnitState.Team.PLAYER
	if clicked != null and clicked.id != _active_card_unit_id() and not selecting_hero:
		pin(clicked.id)  # The click still acts below (a cast on a target cell, a placement).
	match input_state:
		State.PLACING:
			# Select a hero, then a zone cell (a hero there swaps); the selected hero again deselects.
			var unit := battle.state.unit_at(cell)
			if _placing_hero == -1:
				if unit != null and unit.team == UnitState.Team.PLAYER:
					_placing_hero = unit.id
					_refresh_hud()
					_set_state(State.PLACING)
			elif unit != null and unit.id == _placing_hero:
				cancel()
			elif cell in battle.state.zone:
				var hero := _placing_hero
				_placing_hero = -1
				_perform(BattleActions.Place.new(hero, cell))
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
	if _chip_unit != -1 and battle != null:
		return battle.state.units[_chip_unit].cell
	if hovered_control != null:
		return _hovered_cell if hud.is_inspect_control(hovered_control) else BoardView.NO_CELL
	return board_view.pick_cell(camera_rig.camera, mouse_position)


func _on_chip_hovered(unit_id: int) -> void:
	_chip_unit = unit_id if battle != null and unit_id >= 0 and unit_id < battle.state.units.size() else -1


func _on_chip_unhovered() -> void:
	_chip_unit = -1


## Clicking a turn-order chip moves the camera to its unit.
func _on_chip_pressed(unit_id: int) -> void:
	if battle != null and unit_id >= 0 and unit_id < battle.state.units.size():
		camera_rig.focus(board_view.cell_to_world(battle.state.units[unit_id].cell))


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
	if not battle_state.started:
		_set_state(State.PLACING)
		return
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


## The unit's own profile (its preset), else the encounter's, else the fallback.
func _ai_profile_for(unit: UnitState) -> AIProfile:
	if unit.ai_profile != null:
		return unit.ai_profile
	return encounter.ai_profile if encounter.ai_profile != null else ai_profile


func _on_event_played(event: BattleEvents.Event) -> void:
	_hud_model.apply(event)
	_show_turn()
	if event is BattleEvents.TurnStarted and battle.is_sudden_death() and not _sudden_death_announced:
		_sudden_death_announced = true
		hud.show_banner("Sudden death: the party loses %d%% HP every turn" % sudden_death_percent)
		return
	if event is BattleEvents.TurnStarted:
		var unit := battle.state.units[(event as BattleEvents.TurnStarted).unit_id]
		hud.show_banner("%s's turn" % unit.data.display_name)


# --- State and highlights ---

func _enter_idle() -> void:
	selected_spell = -1
	_set_state(State.IDLE)


func _set_state(new_state: State) -> void:
	input_state = new_state
	var player_turn := new_state == State.IDLE or new_state == State.TARGETING or new_state == State.PLACING
	hud.set_player_controls_enabled(player_turn)
	hud.set_placing(new_state == State.PLACING)
	hud.set_selected_spell(selected_spell if new_state == State.TARGETING else -1)
	board_view.clear_highlights()
	units_view.clear_previews()
	_reach = null
	_targetable.clear()
	var unit_id := battle.state.current_unit().id if battle != null and not battle.state.is_over() else -1
	match new_state:
		State.PLACING:
			units_view.set_active(_placing_hero)
			board_view.show_highlight(BoardView.Highlight.ZONE, battle.state.zone)
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
	hud.set_prompt(_prompt_text())
	hud.set_end_turn_pulse(new_state == State.IDLE and _nothing_left_to_do())
	_update_hover()


## The guidance line for the current step.
func _prompt_text() -> String:
	match input_state:
		State.PLACING:
			if _placing_hero == -1:
				return "Place your heroes: click one, then a teal cell. Ready (Space) to fight"
			return "Click a teal cell to place %s (Esc to deselect)" % battle.state.units[_placing_hero].label
		State.IDLE:
			if _nothing_left_to_do():
				return "Nothing left to do: end your turn (Space)"
			return "Move to a blue cell or pick a spell (1-%d)" % maxi(1, battle.state.current_unit().data.spells.size())
		State.TARGETING:
			return "Choose a target for %s (orange cells). Esc to cancel" % \
					battle.state.current_unit().data.spells[selected_spell].display_name
		State.ENEMY_TURN:
			return "%s is acting..." % battle.state.current_unit().label
	return ""


## The acting hero can neither move nor afford any spell.
func _nothing_left_to_do() -> bool:
	if _reach != null and not _reach.cells().is_empty():
		return false
	var unit := battle.state.current_unit()
	for slot in unit.data.spells.size():
		if BattleActions.CastSpell.can_afford(unit, slot):
			return false
	return true


## Path to the hovered cell while moving, or the spell's area while aiming; in any state,
## the hovered unit (other than the one acting) in the HUD's inspect panel.
func _update_hover() -> void:
	_update_inspected()
	var cells: Array[Vector2i] = []
	match input_state:
		State.PLACING:
			if _placing_hero != -1:
				cells.append(battle.state.units[_placing_hero].cell)
				if _hovered_cell in battle.state.zone:
					cells.append(_hovered_cell)
			board_view.show_highlight(BoardView.Highlight.PATH, cells)
		State.IDLE:
			board_view.clear_path_cost()
			if _reach != null and _reach.can_reach(_hovered_cell):
				cells = _reach.path_to(_hovered_cell)
				board_view.show_path_cost(_hovered_cell, _reach.cost_to(_hovered_cell),
						Movement.climbing_steps(battle.state.grid, _reach.origin, cells))
			board_view.show_highlight(BoardView.Highlight.PATH, cells)
		State.TARGETING:
			if _targetable.has(_hovered_cell):
				var caster := battle.state.current_unit()
				var spell := caster.data.spells[selected_spell]
				cells = Targeting.area_cells(battle.state.grid, spell.area, caster.cell, _hovered_cell)
				units_view.show_previews(DamagePreview.for_cast(battle.state, caster.id, selected_spell, _hovered_cell))
			else:
				units_view.clear_previews()
			board_view.show_highlight(BoardView.Highlight.AREA, cells)
		# Other states: _set_state already cleared the hover highlights, and the AREA layer
		# may be showing a cast's flash from the EventPlayer, which hover must not touch.
	if _chip_unit != -1 and input_state in [State.PLACING, State.IDLE, State.TARGETING]:
		board_view.show_highlight(BoardView.Highlight.PATH, [battle.state.units[_chip_unit].cell] as Array[Vector2i])


## The right-hand card: the hovered unit, else the pinned one (with its ✕). The unit on
## the active card is never repeated there.
func _update_inspected() -> void:
	var shown: UnitInfo = null
	var pinned := false
	if battle != null and _pinned_unit != -1 and _hud_model.infos[_pinned_unit].hp <= 0:
		_pinned_unit = -1  # A fallen unit's card goes away.
	if battle != null:
		var active_id := _active_card_unit_id()
		if _hovered_cell != BoardView.NO_CELL:
			var hovered := battle.state.unit_at(_hovered_cell)
			if hovered != null and hovered.id != active_id:
				shown = _hud_model.infos[hovered.id]
		if shown == null and _pinned_unit != -1 and _pinned_unit != active_id:
			shown = _hud_model.infos[_pinned_unit]
		pinned = shown != null and shown.unit_id == _pinned_unit
	if shown == null:
		hud.hide_inspected()
	else:
		hud.show_inspected(shown, pinned)


## The unit shown on the active card: the acting one, or (placing) the selected hero, else the first.
func _active_card_unit_id() -> int:
	if battle.state.started:
		return _hud_model.current_id
	return _placing_hero if _placing_hero != -1 else battle.state.units[0].id


## Re-syncs the HUD from the battle state: the source of truth, after a playback (or a
## new battle, or a placement) while the events in between only updated the model.
func _refresh_hud() -> void:
	_hud_model = HudModel.from_state(battle.state, player_levels)
	_show_turn()
	var active := _hud_model.infos.get(_active_card_unit_id()) as UnitInfo
	if active != null:
		hud.show_spells(active.spells, active.ap)


## Shows the model's turn in the HUD: order, active card, AP for the spell bar, inspect
## card. The HUD gets plain UnitInfo values, never state.
func _show_turn() -> void:
	hud.show_turn_order(_hud_model.upcoming(), _hud_model.round_number, battle_title)
	var active := _hud_model.infos.get(_active_card_unit_id()) as UnitInfo
	if active != null:
		hud.show_unit(active)
		hud.set_spell_ap(active.ap)
	_update_inspected()


func _spawn_center(spawns: Array[Vector2i]) -> Vector3:
	var sum := Vector3.ZERO
	for cell in spawns:
		sum += board_view.cell_to_world(cell)
	return sum / maxi(spawns.size(), 1)
