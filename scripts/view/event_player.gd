class_name EventPlayer
extends Node
## Plays battle events one after another: each event's animation is awaited before the
## next starts (sequential playback queue). Views only animate; the BattleState has
## already changed by the time events are played.

## A sound event to hear (an AudioSet.SFX_EVENTS name): the game connects it to the audio.
signal sound(event: StringName)

## A projectile left for `end` (world position), for tests and effects that follow it.
signal projectile_launched(end: Vector3)

## Emitted after each event has played, for the HUD and controller to react.
signal event_played(event: BattleEvents.Event)

## Default effects (a hit with no damage type, a heal); damage types and spells carry theirs.
@export var fx: BattleFx

## How far above the cell's top a ground effect starts.
const GROUND_FX_HEIGHT := 0.3

## A hit of at least this share of the target's max HP shakes the camera.
const BIG_HIT_SHARE := 0.25
## How high above its cell a falling projectile starts.
## A teleport's flash where the unit reappears.
const BLINK_TINT := Color(0.6, 0.8, 1.0)
const SKY_HEIGHT := 7.0
const SHAKE_MIN := 0.08
const SHAKE_MAX := 0.22
## How long a spell's area stays highlighted before its effects play.
const AREA_FLASH := 0.25

## Skips every animation: events only reach the listeners (the views are synced from the state
## by the controller afterwards). The "instant" battle speed.
var instant := false
var is_playing := false
## The spell whose effects are being played (set by its SpellCast, cleared by the next turn
## event or status tick), so its impact effect can replace the damage type's.
var _spell: SpellData
## A cast whose caster moves first (a charge): played when it lands.
var _cast_on_arrival: BattleEvents.SpellCast
var _units: UnitsView
var _board: BoardView
## Eases after a unit that walks off screen (optional).
var _camera: CameraRig
## Bumped by stop(); a playback that sees it change after an await gives up.
var _generation := 0


func setup(units: UnitsView, board: BoardView, camera: CameraRig = null) -> void:
	_units = units
	_board = board
	_camera = camera


## Returns when every event has played.
func play(events: Array[BattleEvents.Event]) -> void:
	if is_playing:
		push_error("EventPlayer: already playing")
		return
	is_playing = true
	_spell = null
	var generation := _generation
	var floated: Dictionary[int, int] = {}  # Instant: texts already floated per unit, to stack them.
	for event in events:
		if not instant:
			await _play_event(event)
			if generation != _generation:
				return  # stop() was called; it already reset the player.
		else:
			_track_spell(event)
			_float_feedback(event, floated)
		event_played.emit(event)
	is_playing = false


## Instant speed skips the animations but keeps what the player must read: damage and heal
## numbers and applied statuses float over their units at once, without waiting (several on
## one unit are stacked so they stay readable).
func _float_feedback(event: BattleEvents.Event, floated: Dictionary[int, int]) -> void:
	var text := ""
	var color := Color.WHITE
	if event is BattleEvents.DamageDealt:
		var hit := event as BattleEvents.DamageDealt
		if hit.amount > 0:
			text = "-%d" % hit.amount
			color = UnitView.DAMAGE_COLOR
	elif event is BattleEvents.Healed:
		var heal := event as BattleEvents.Healed
		if heal.amount > 0:
			text = "+%d" % heal.amount
			color = UnitView.HEAL_COLOR
	elif event is BattleEvents.StatusApplied:
		var applied := event as BattleEvents.StatusApplied
		text = applied.status.display_name  # The label translates it, as in normal playback.
		color = applied.status.color
	if text.is_empty():
		return
	var view := _units.find_view(event.subject_id())
	if view == null or not is_instance_valid(view):
		return
	var stack: int = floated.get(event.subject_id(), 0)
	floated[event.subject_id()] = stack + 1
	view.float_text(text, color, stack)


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
	_cast_on_arrival = null
	if _camera != null:
		_camera.stop_following()
	if _board != null:
		_board.clear_highlight(BoardView.Highlight.AREA)


## A big hit jolts the camera, harder the bigger it is next to the target's HP.
func _shake_for(view: UnitView, amount: int) -> void:
	if _camera == null or amount <= 0:
		return
	var share := float(amount) / maxf(view.max_hp(), 1)
	if share >= BIG_HIT_SHARE:
		_camera.shake(lerpf(SHAKE_MIN, SHAKE_MAX, clampf((share - BIG_HIT_SHARE) / 0.5, 0.0, 1.0)))


## The cast phase: the caster's animation and lunge, then the effects land. Default pacing:
## the lunge, then a short flash of the area. A spell with an `impact_delay` or a `projectile`
## sets the timing itself: the effects land `impact_delay` seconds after the cast starts (the
## lunge runs on in parallel), after the projectile's flight when there is one.
func _play_cast(view: UnitView, cast: BattleEvents.SpellCast) -> void:
	var spell := cast.spell
	var generation := _generation
	if spell.impact_delay < 0.0 and spell.projectile == null:
		await view.play_cast(cast.target, spell)
		# A tween interval (not a SceneTreeTimer) so it pauses with the tree like the rest.
		await create_tween().tween_interval(AREA_FLASH).finished
	else:
		view.play_cast(cast.target, spell)  # Not awaited: the timing is the spell's.
		var delay := spell.impact_delay if spell.impact_delay >= 0.0 else UnitView.CAST_DURATION * 0.5
		if delay > 0.0:
			await create_tween().tween_interval(delay).finished
		if generation == _generation and spell.projectile != null:
			await _fly_projectile(view, cast)
	if generation == _generation:  # After stop(), the AREA layer belongs to someone else.
		_board.clear_highlight(BoardView.Highlight.AREA)


## The spell's projectiles. Each flies from the caster's chest to the target cell, or falls from
## the sky onto it, then is gone; a volley sends several, `projectile_interval` apart, each at
## the next cell of the area. Returns when the last has landed, then the spell may shake the
## camera.
func _fly_projectile(view: UnitView, cast: BattleEvents.SpellCast) -> void:
	var spell := cast.spell
	var generation := _generation
	var count := maxi(spell.projectile_count, 1)
	var cells: Array[Vector2i] = [cast.target]
	if count > 1 and not cast.area.is_empty():
		cells = cast.area
	var total := 0.0
	for index in count:
		var cell := cells[index % cells.size()]
		var end := _board.cell_to_world(cell) + Vector3(0.0, UnitView.PROJECTILE_HEIGHT, 0.0)
		if count > 1:
			end += Vector3(randf_range(-0.2, 0.2), 0.0, randf_range(-0.2, 0.2))  # Not on the exact center.
		var start := end + Vector3(0.0, SKY_HEIGHT, 0.0) if spell.projectile_falls else view.chest_position()
		var flight := start.distance_to(end) / spell.projectile_speed
		var delay := index * spell.projectile_interval
		total = maxf(total, delay + flight)
		var launcher := create_tween()
		launcher.tween_interval(delay)
		launcher.tween_callback(_launch.bind(spell.projectile, start, end, flight))
	await create_tween().tween_interval(total).finished
	if generation == _generation and _camera != null and spell.impact_shake > 0.0:
		_camera.shake(spell.impact_shake, 0.45)


## One projectile in the air: it frees itself on arrival (or with the board).
func _launch(scene: PackedScene, start: Vector3, end: Vector3, flight: float) -> void:
	if _board == null or not is_instance_valid(_board):
		return
	projectile_launched.emit(end)
	var projectile := scene.instantiate() as Node3D
	if projectile == null:
		return
	_board.add_child(projectile)
	projectile.global_position = start
	if absf(end.x - start.x) + absf(end.z - start.z) < 0.001:  # Straight down: no "up" to look along.
		projectile.global_basis = Basis.looking_at(end - start, Vector3.RIGHT)
	elif not start.is_equal_approx(end):
		projectile.look_at(end)
	var tween := projectile.create_tween()  # Bound to the projectile: it ends with it.
	tween.tween_property(projectile, "global_position", end, flight)
	tween.tween_callback(projectile.queue_free)


## A walk. When some of it would leave the screen, the camera eases after the unit (allies and
## enemies alike) and settles on it at the end; a walk that stays in view leaves the camera
## alone, so a run of short enemy moves doesn't make it dart about.
func _play_move(view: UnitView, path: Array[Vector2i]) -> void:
	var points: Array[Vector3] = [view.position]
	for cell in path:
		points.append(_board.cell_to_world(cell))
	var follows := _camera != null and not _camera.is_on_screen(points)
	var generation := _generation
	if follows:
		_camera.follow(view)
	var step_sound := func() -> void: sound.emit(&"step")
	view.stepped.connect(step_sound)
	await view.play_move(path)
	if is_instance_valid(view):
		view.stepped.disconnect(step_sound)
	if follows and generation == _generation and is_instance_valid(view) and _camera.is_following():  # Not after a pan of the player's.
		_camera.focus_on(view.position)  # Ends the follow with a last glide onto the unit.


func _track_spell(event: BattleEvents.Event) -> void:
	if event is BattleEvents.SpellCast:
		_spell = (event as BattleEvents.SpellCast).spell
	elif event is BattleEvents.TurnStarted or event is BattleEvents.TurnEnded or event is BattleEvents.StatusTicked:
		_spell = null


## One dispatch point: the event's subject_id() names the view, the type picks the
## animation. Events with no board animation (turns, battle end) just pass through; the
## HUD and controller react to them through event_played.
func _play_event(event: BattleEvents.Event) -> void:
	if _cast_on_arrival != null and event is not BattleEvents.UnitDisplaced:
		# The caster didn't move after all (a charge from the next cell): swing now.
		var pending := _cast_on_arrival
		_cast_on_arrival = null
		var caster := _units.find_view(pending.caster_id)
		if caster != null and is_instance_valid(caster):
			await _play_cast(caster, pending)
	_track_spell(event)
	var view := _units.find_view(event.subject_id())
	if view == null or not is_instance_valid(view):
		return
	if event is BattleEvents.UnitMoved:
		await _play_move(view, (event as BattleEvents.UnitMoved).path)
	elif event is BattleEvents.UnitDisplaced:
		var displaced := event as BattleEvents.UnitDisplaced
		await view.play_displaced(displaced.path, displaced.kind)
		if fx != null and displaced.kind == MoveEffect.Kind.TELEPORT:
			view.spawn_fx(fx.status_applied, BLINK_TINT)  # A flash where it reappears.
		if _cast_on_arrival != null and _cast_on_arrival.caster_id == displaced.unit_id and is_instance_valid(view):
			var cast := _cast_on_arrival
			_cast_on_arrival = null
			await _play_cast(view, cast)
	elif event is BattleEvents.UnitPlaced:
		await view.play_place((event as BattleEvents.UnitPlaced).cell)
	elif event is BattleEvents.SpellCast:
		var cast := event as BattleEvents.SpellCast
		var generation_before := _generation
		sound.emit(cast.spell.cast_sound_event())
		view.spawn_fx(cast.spell.cast_effect)
		_board.show_highlight(BoardView.Highlight.AREA, cast.area)
		_cast_on_arrival = null
		if cast.spell.moves_caster_first():
			_cast_on_arrival = cast  # The swing comes after the dash.
		else:
			await _play_cast(view, cast)
		if generation_before == _generation:
			_spawn_ground_fx(cast)  # Where the effects land, when they land (after a projectile's flight).
	elif event is BattleEvents.DamageDealt:
		var hit := event as BattleEvents.DamageDealt
		if fx != null:  # Even a fully resisted hit: the spell landed.
			view.spawn_fx(fx.impact_for(hit.damage_type, _spell))
		if hit.amount > 0:
			sound.emit(&"hit")
		_shake_for(view, hit.amount)
		await view.play_hit(hit.amount, hit.hp_after)
	elif event is BattleEvents.Healed:
		var heal := event as BattleEvents.Healed
		sound.emit(&"heal")
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
		sound.emit(&"death")
		await view.play_death()
