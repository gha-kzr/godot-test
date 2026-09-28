class_name EventPlayer
extends Node
## Plays battle events one after another: each event's animation is awaited before the
## next starts (sequential playback queue). Views only animate; the BattleState has
## already changed by the time events are played.

## Emitted after each event has played, for the HUD and controller to react.
signal event_played(event: BattleEvents.Event)

## How long a spell's area stays highlighted before its effects play.
const AREA_FLASH := 0.25

var is_playing := false
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
	var generation := _generation
	for event in events:
		await _play_event(event)
		if generation != _generation:
			return  # stop() was called; it already reset the player.
		event_played.emit(event)
	is_playing = false


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
	var view := _units.find_view(event.subject_id())
	if view == null or not is_instance_valid(view):
		return
	if event is BattleEvents.UnitMoved:
		await view.play_move((event as BattleEvents.UnitMoved).path)
	elif event is BattleEvents.SpellCast:
		var cast := event as BattleEvents.SpellCast
		_board.show_highlight(BoardView.Highlight.AREA, cast.area)
		await view.play_cast(cast.target)
		# A tween interval (not a SceneTreeTimer) so it pauses with the tree like the rest.
		var generation := _generation
		await create_tween().tween_interval(AREA_FLASH).finished
		if generation == _generation:  # After stop(), the AREA layer belongs to someone else.
			_board.clear_highlight(BoardView.Highlight.AREA)
	elif event is BattleEvents.DamageDealt:
		var hit := event as BattleEvents.DamageDealt
		await view.play_hit(hit.amount, hit.hp_after)
	elif event is BattleEvents.Healed:
		var heal := event as BattleEvents.Healed
		await view.play_heal(heal.amount, heal.hp_after)
	elif event is BattleEvents.StatusApplied:
		var applied := event as BattleEvents.StatusApplied
		await view.play_status_applied(applied.status, applied.turns_left)
	elif event is BattleEvents.StatusTicked:
		await view.play_status_ticked((event as BattleEvents.StatusTicked).status)
	elif event is BattleEvents.StatusExpired:
		await view.play_status_expired((event as BattleEvents.StatusExpired).status)
	elif event is BattleEvents.UnitDied:
		await view.play_death()
