class_name EventPlayer
extends Node
## Plays battle events one after another: each event's animation is awaited before the
## next starts (sequential playback queue). Views only animate; the BattleState has
## already changed by the time events are played.

## Emitted after each event has played, for the HUD and controller to react.
signal event_played(event: BattleEvents.Event)

## Default effects (a hit with no damage type, a heal); damage types and spells carry theirs.
@export var fx: BattleFx

## How far above the cell's top a ground effect starts.
const GROUND_FX_HEIGHT := 0.3

## How long a spell's area stays highlighted before its effects play.
const AREA_FLASH := 0.25

var is_playing := false
## The spell whose effects are being played (set by its SpellCast, cleared by the next turn
## event or status tick), so its impact effect can replace the damage type's.
var _spell: SpellData
var _units: UnitsView
var _board: BoardView
## Bumped by stop(); a playback that sees it change after an await gives up.
var _generation := 0


func setup(units: UnitsView, board: BoardView) -> void:
	_units = units
	_board = board


## Returns when every event has played.
func play(events: Array[BattleEvents.Event]) -> void:
	if is_playing:
		push_error("EventPlayer: already playing")
		return
	is_playing = true
	_spell = null
	var generation := _generation
	for event in events:
		await _play_event(event)
		if generation != _generation:
			return  # stop() was called; it already reset the player.
		event_played.emit(event)
	is_playing = false


## A spell's effect on each cell of its area with no unit on it: casting at the ground still
## shows something. Cells with a unit get theirs from that unit's own events.
func _spawn_ground_fx(cast: BattleEvents.SpellCast) -> void:
	if fx == null:
		return
	var scene := fx.cell_effect_for(cast.spell)
	if scene == null:
		return
	for cell in cast.area:
		if _units.has_unit_at(cell):
			continue
		var effect := scene.instantiate() as Node3D
		effect.position = _board.cell_to_world(cell) + Vector3(0.0, GROUND_FX_HEIGHT, 0.0)
		_board.add_child(effect)


## Abandons the current playback, e.g. before rebuilding the views. A view freed mid-tween
## never finishes its await, so play() can't be relied on to return by itself.
func stop() -> void:
	_generation += 1
	is_playing = false
	if _board != null:
		_board.clear_highlight(BoardView.Highlight.AREA)


## One dispatch point: the event's subject_id() names the view, the type picks the
## animation. Events with no board animation (turns, battle end) just pass through; the
## HUD and controller react to them through event_played.
func _play_event(event: BattleEvents.Event) -> void:
	if event is BattleEvents.SpellCast:
		_spell = (event as BattleEvents.SpellCast).spell
	elif event is BattleEvents.TurnStarted or event is BattleEvents.TurnEnded or event is BattleEvents.StatusTicked:
		_spell = null
	var view := _units.find_view(event.subject_id())
	if view == null or not is_instance_valid(view):
		return
	if event is BattleEvents.UnitMoved:
		await view.play_move((event as BattleEvents.UnitMoved).path)
	elif event is BattleEvents.UnitPlaced:
		await view.play_place((event as BattleEvents.UnitPlaced).cell)
	elif event is BattleEvents.SpellCast:
		var cast := event as BattleEvents.SpellCast
		view.spawn_fx(cast.spell.cast_effect)
		_spawn_ground_fx(cast)
		_board.show_highlight(BoardView.Highlight.AREA, cast.area)
		await view.play_cast(cast.target, cast.spell)
		# A tween interval (not a SceneTreeTimer) so it pauses with the tree like the rest.
		var generation := _generation
		await create_tween().tween_interval(AREA_FLASH).finished
		if generation == _generation:  # After stop(), the AREA layer belongs to someone else.
			_board.clear_highlight(BoardView.Highlight.AREA)
	elif event is BattleEvents.DamageDealt:
		var hit := event as BattleEvents.DamageDealt
		if fx != null:  # Even a fully resisted hit: the spell landed.
			view.spawn_fx(fx.impact_for(hit.damage_type, _spell))
		await view.play_hit(hit.amount, hit.hp_after)
	elif event is BattleEvents.Healed:
		var heal := event as BattleEvents.Healed
		if fx != null:  # Even on a unit at full HP.
			view.spawn_fx(fx.heal)
		await view.play_heal(heal.amount, heal.hp_after)
	elif event is BattleEvents.StatusApplied:
		var applied := event as BattleEvents.StatusApplied
		if fx != null:
			view.spawn_fx(fx.status_applied, applied.status.color)
		await view.play_status_applied(applied.status, applied.turns_left)
	elif event is BattleEvents.StatusTicked:
		await view.play_status_ticked((event as BattleEvents.StatusTicked).status)
	elif event is BattleEvents.StatusExpired:
		await view.play_status_expired((event as BattleEvents.StatusExpired).status)
	elif event is BattleEvents.UnitDied:
		await view.play_death()
