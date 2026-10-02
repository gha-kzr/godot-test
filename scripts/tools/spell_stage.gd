class_name SpellStage
extends Node3D
## A stage to see one spell cast, over and over, while it is edited: pick a spell, a caster and a
## target, and it plays the real cast through the battle rules and the real EventPlayer (the
## same code as a battle, so what you see is what ships). It reloads the spell and the effect
## files when they change on disk, so the loop is: edit in the editor (Inspector: animation cut,
## impact delay, projectile; the particle scenes), Ctrl+S, look at the running stage, which
## replays by itself. Run it with the Design panel's "Spell stage" button, or open
## scenes/tools/spell_stage.tscn and press F6 (turn off "Embed Game" to get a real window, or
## keep it to see the stage in the editor's Game tab).
## Arguments after `--`: `spell=res://data/spells/fireball.tres`.

signal played
signal reloaded

const SPELLS_DIR := "res://data/spells"
const UNITS_DIR := "res://data/units"
const FX := preload("res://data/fx/battle_fx.tres")
const THEME := preload("res://data/board/stone.tres")
const CAMERA_RIG := preload("res://scenes/battle/camera_rig.tscn")
## The editor's Design panel writes the spell open in the Inspector here.
const SELECTION_PATH := "user://spell_stage.cfg"
## Seconds between two looks at the files for a change.
const WATCH_INTERVAL := 0.5
## Seconds the stage waits after a cast before it loops.
const LOOP_PAUSE := 0.8
const ROWS := 5
const CASTER_CELL := Vector2i(1, 2)
## A dummy and a caster that don't fall over while a spell is being timed.
const STAGE_HP := 9999

var spell_path := ""
var caster_data: UnitData
var target_data: UnitData
var at_self := false
var loop := true
var speed := 1.0

var spell: SpellData
var battle: Battle
var board_view: BoardView
var units_view: UnitsView
var event_player: EventPlayer
var camera_rig: CameraRig
## How many playbacks finished.
var play_count := 0
## Seconds the last cast took, from its first event to its last.
var last_duration := 0.0

var _generation := 0
## Game seconds since the stage started (the process delta is already scaled by the speed).
var _clock := 0.0
var _signature := ""
var _watch_time := 0.0
var _spell_options: OptionButton
var _caster_options: OptionButton
var _target_options: OptionButton
var _info: Label
var _unit_paths: Array[String] = []


## The battle a stage plays: a flat board, `caster` (a player, at the left) with `spell` as its
## only spell, and `target` (an enemy) `distance` cells away, both with plenty of HP. Returns
## null when the spell can't be set up.
static func build_state(spell_data: SpellData, caster: UnitData, target: UnitData, self_cast := false) -> BattleState:
	if spell_data == null or caster == null or target == null:
		return null
	var distance := 1 if self_cast else clampi(spell_data.max_range, maxi(spell_data.min_range, 1), 6)
	var columns := CASTER_CELL.x + distance + 3
	var rows: Array[String] = []
	for y in ROWS:
		var tokens: Array[String] = []
		for x in columns:
			var token := "0"
			if Vector2i(x, y) == CASTER_CELL:
				token = "0p"
			elif Vector2i(x, y) == CASTER_CELL + Vector2i(distance, 0):
				token = "0e"
			tokens.append(token)
		rows.append(" ".join(tokens))
	var map := MapData.new()
	map.layout = "\n".join(rows)
	var hero := caster.duplicate() as UnitData
	hero.spells = [spell_data] as Array[SpellData]
	hero.ap = maxi(hero.ap, spell_data.ap_cost)
	hero.max_hp = STAGE_HP
	var dummy := target.duplicate() as UnitData
	dummy.max_hp = STAGE_HP
	return BattleState.create(map.parse(), [hero] as Array[UnitData], [dummy] as Array[UnitData], 1)


## The cell the cast aims at on a board built by build_state().
static func target_cell(spell_data: SpellData, self_cast: bool) -> Vector2i:
	if self_cast:
		return CASTER_CELL
	return CASTER_CELL + Vector2i(clampi(spell_data.max_range, maxi(spell_data.min_range, 1), 6), 0)


## Whether a spell is naturally cast on its caster: it can only target its own cell (a swirl
## around the caster), or it can and does no damage (a heal or a buff).
static func casts_on_self(spell_data: SpellData) -> bool:
	return spell_data.min_range == 0 and (spell_data.max_range == 0
			or not spell_data.effects.any(func(effect: EffectData) -> bool: return effect is DamageEffect))


func _ready() -> void:
	_build_world()
	_build_ui()
	var args := _arguments()
	spell_path = args.get("spell", _selected_in_editor())
	if spell_path.is_empty() or not ResourceLoader.exists(spell_path):
		spell_path = "%s/fireball.tres" % SPELLS_DIR
	caster_data = load("%s/knight.tres" % UNITS_DIR) as UnitData
	target_data = load("%s/brute.tres" % UNITS_DIR) as UnitData
	_select_in_options(_spell_options, spell_path)
	_select_in_options(_caster_options, "%s/knight.tres" % UNITS_DIR)
	_select_in_options(_target_options, "%s/brute.tres" % UNITS_DIR)
	reload()


func _exit_tree() -> void:
	Engine.time_scale = 1.0


func _process(delta: float) -> void:
	_clock += delta
	_watch_time += delta / maxf(Engine.time_scale, 0.01)  # Wall-clock seconds, whatever the speed.
	if _watch_time < WATCH_INTERVAL:
		return
	_watch_time = 0.0
	var now := _files_signature()
	if now != _signature:
		reload()


## Loads the spell again from disk (and the effect files it points to) and replays it.
func reload() -> void:
	spell = ResourceLoader.load(spell_path, "SpellData", ResourceLoader.CACHE_MODE_REPLACE_DEEP) as SpellData
	if spell == null:
		_info.text = "Can't load %s" % spell_path
		return
	at_self = casts_on_self(spell)
	_signature = _files_signature()
	reloaded.emit()
	replay()


## Plays the cast from the start (a playback in progress is abandoned).
func replay() -> void:
	_generation += 1
	var generation := _generation
	Engine.time_scale = speed
	event_player.stop()
	while generation == _generation:
		await _play_once(generation)
		if generation != _generation or not loop:
			break
		var tween := create_tween()
		tween.tween_interval(LOOP_PAUSE)
		await tween.finished
	if generation == _generation:
		Engine.time_scale = 1.0


func _play_once(generation: int) -> void:
	var state := build_state(spell, caster_data, target_data, at_self)
	if state == null:
		_info.text = "Can't set up %s" % spell_path
		return
	battle = Battle.new(state)
	battle.start()
	board_view.build(state.grid)
	units_view.build(state, board_view)
	event_player.setup(units_view, board_view, camera_rig)
	camera_rig.set_bounds(Rect2(Vector2.ZERO, Vector2(state.grid.size - Vector2i.ONE) * BoardView.CELL_SIZE))
	camera_rig.focus(board_view.center())
	var result := battle.perform(BattleActions.CastSpell.new(0, 0, target_cell(spell, at_self)))
	if not result.ok():
		_info.text = "The cast failed: %s" % result.error
		return
	var started := _clock
	await event_player.play(result.events)
	if generation != _generation:
		return
	last_duration = _clock - started
	units_view.sync(state)
	play_count += 1
	_info.text = _describe()
	played.emit()


func _describe() -> String:
	var lines: Array[String] = ["%s: cast took %.2f s" % [spell.display_name, last_duration]]
	lines.append("animation: %s%s, %.2f to %s s, speed %.2f" % [
			spell.cast_animation if not spell.cast_animation.is_empty() else "(by range)",
			" from " + spell.animation_scene.resource_path.get_file() if spell.animation_scene != null else "",
			spell.animation_start, "%.2f" % spell.animation_end if spell.animation_end > 0.0 else "end", spell.animation_speed])
	lines.append("impact delay: %s%s" % ["default" if spell.impact_delay < 0.0 else "%.2f s" % spell.impact_delay,
			", projectile at %.1f u/s" % spell.projectile_speed if spell.projectile != null else ""])
	return "\n".join(lines)


## What the spell loads from: its file and the effect and animation files it points to, as the
## modification times; a changed one means "reload".
func _files_signature() -> String:
	var paths: Array[String] = [spell_path, FX.resource_path]
	if spell != null:
		for resource: Resource in [spell.cast_effect, spell.impact_effect, spell.projectile, spell.animation_scene]:
			if resource != null:
				paths.append(resource.resource_path)
		for effect in spell.effects:
			if effect is DamageEffect and (effect as DamageEffect).damage_type != null:
				paths.append((effect as DamageEffect).damage_type.resource_path)
				if (effect as DamageEffect).damage_type.impact_effect != null:
					paths.append((effect as DamageEffect).damage_type.impact_effect.resource_path)
	var signature := ""
	for path in paths:
		signature += "%s:%d;" % [path, FileAccess.get_modified_time(path) if FileAccess.file_exists(path) else 0]
	return signature


func _build_world() -> void:
	camera_rig = CAMERA_RIG.instantiate() as CameraRig
	add_child(camera_rig)
	board_view = BoardView.new()
	board_view.board_theme = THEME
	add_child(board_view)
	units_view = UnitsView.new()
	add_child(units_view)
	event_player = EventPlayer.new()
	event_player.fx = FX
	add_child(event_player)
	var light := DirectionalLight3D.new()
	light.transform = Transform3D(Basis(Vector3(0.866025, 0, -0.5), Vector3(-0.353553, 0.707107, -0.612372), Vector3(0.353553, 0.707107, 0.612372)), Vector3(0, 10, 0))
	light.light_energy = 1.1
	light.shadow_enabled = true
	add_child(light)
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.1, 0.11, 0.14)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.75, 0.78, 0.85)
	environment.ambient_light_energy = 0.6
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var world := WorldEnvironment.new()
	world.environment = environment
	add_child(world)


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var panel := PanelContainer.new()
	panel.position = Vector2(12, 12)
	panel.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED  # A developer tool: English.
	layer.add_child(panel)
	var column := VBoxContainer.new()
	panel.add_child(column)
	_spell_options = _option_row(column, "Spell", SPELLS_DIR, func(path: String) -> void:
		spell_path = path
		reload())
	_caster_options = _unit_row(column, "Caster", func(unit: UnitData) -> void:
		caster_data = unit
		replay())
	_target_options = _unit_row(column, "Target", func(unit: UnitData) -> void:
		target_data = unit
		replay())
	var speed_row := HBoxContainer.new()
	column.add_child(speed_row)
	var speed_label := Label.new()
	speed_label.text = "Speed"
	speed_row.add_child(speed_label)
	var slider := HSlider.new()
	slider.min_value = 0.1
	slider.max_value = 2.0
	slider.step = 0.05
	slider.value = speed
	slider.custom_minimum_size = Vector2(160, 0)
	slider.value_changed.connect(func(value: float) -> void:
		speed = value
		Engine.time_scale = value)
	speed_row.add_child(slider)
	var loop_box := CheckButton.new()
	loop_box.text = "Loop"
	loop_box.button_pressed = loop
	loop_box.toggled.connect(func(pressed: bool) -> void: loop = pressed)
	speed_row.add_child(loop_box)
	var replay_button := Button.new()
	replay_button.text = "Replay"
	replay_button.pressed.connect(replay)
	speed_row.add_child(replay_button)
	_info = Label.new()
	column.add_child(_info)


func _option_row(parent: Control, label_text: String, dir: String, on_selected: Callable) -> OptionButton:
	var row := HBoxContainer.new()
	parent.add_child(row)
	var label := Label.new()
	label.text = label_text
	label.custom_minimum_size = Vector2(60, 0)
	row.add_child(label)
	var options := OptionButton.new()
	for file in DirAccess.get_files_at(dir):
		if file.get_extension() == "tres":
			options.add_item(file.get_basename().capitalize())
			options.set_item_metadata(options.item_count - 1, dir.path_join(file))
	options.item_selected.connect(func(index: int) -> void: on_selected.call(options.get_item_metadata(index)))
	row.add_child(options)
	return options


func _unit_row(parent: Control, label_text: String, on_selected: Callable) -> OptionButton:
	return _option_row(parent, label_text, UNITS_DIR, func(path: String) -> void: on_selected.call(load(path) as UnitData))


func _select_in_options(options: OptionButton, path: String) -> void:
	for index in options.item_count:
		if options.get_item_metadata(index) == path:
			options.select(index)


func _arguments() -> Dictionary:
	var result := {}
	for argument in OS.get_cmdline_user_args():
		var parts := argument.split("=", true, 1)
		if parts.size() == 2:
			result[parts[0]] = parts[1]
	return result


func _selected_in_editor() -> String:
	var config := ConfigFile.new()
	if config.load(SELECTION_PATH) != OK:
		return ""
	return str(config.get_value("stage", "spell", ""))
