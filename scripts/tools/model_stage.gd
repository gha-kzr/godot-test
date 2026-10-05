class_name ModelStage
extends Node3D
## A lit stage that lines up unit models on floor tiles, in the battle's light and camera angle,
## to compare models (an asset-pack one against a hand-built one) and check their animations.
## Arguments after `--`: `units=knight,warg` (names in data/units/, or `res://….tscn` model scenes), `anim=Idle` (a logical
## animation of UnitModel; a list, `Idle,Walk`, gives one to each unit in turn), `at=0.3` (seconds
## into it, a list likewise; the pose is frozen there), `yaw=0` (turns
## the camera around the line, degrees), `scale=1` (zoom), `gap=2.2` (cells between units),
## `focus=0.7` (the height the camera looks at), `fov=35` (lower for a close-up), `spin=1` (each unit turned a further 360 / count degrees: a turntable of one unit repeated).
## Render a still: `godot --write-movie /tmp/shot.png --fixed-fps 10 --quit-after 3
## scenes/tools/model_stage.tscn -- units=knight anim=Walk at=0.2`.

const UNITS_DIR := "res://data/units"
const PITCH_DEGREES := 40.0

var unit_names: PackedStringArray = ["knight"]
var animations: PackedStringArray = ["Idle"]
var ats: PackedFloat64Array = [0.0]
var yaw := 0.0
var zoom := 1.0
var gap := 2.2
var spin := false
var focus := 0.7
var fov := 35.0


func _ready() -> void:
	_read_arguments()
	_build_environment()
	var models: Array[UnitModel] = []
	for index in unit_names.size():
		var entry := unit_names[index]
		var data: UnitData
		if entry.begins_with("res://"):  # A model scene shown as it is (scale 1), no unit needed.
			data = UnitData.new()
			data.model_scene = load(entry) as PackedScene
		else:
			data = load("%s/%s.tres" % [UNITS_DIR, entry]) as UnitData
		if data == null or (entry.begins_with("res://") and data.model_scene == null):
			push_error("ModelStage: no unit '%s'" % entry)
			continue
		var x := (index - (unit_names.size() - 1) * 0.5) * gap
		_add_tile(Vector3(x, 0.0, 0.0))
		var model := UnitModel.new()
		add_child(model)
		model.position = Vector3(x, 0.0, 0.0)
		if spin:
			model.rotation.y = TAU * index / unit_names.size()
		if data.model_scene != null:
			model.setup(data.model_scene, data.model_scale)
			if data.held_item != null:
				model.hold(data.held_item, data.held_item_replaces, data.held_item_scale,
						data.held_item_rotation, data.held_item_bone, data.held_item_offset)
		models.append(model)
	_build_camera()
	await get_tree().process_frame
	for index in models.size():
		var model := models[index]
		model.play(StringName(animations[index % animations.size()]))
		for player in model.find_children("*", "AnimationPlayer", true, false):
			var animation_player := player as AnimationPlayer
			animation_player.play(animation_player.current_animation, 0.0)  # No blend: the still is the clip's own pose.
			animation_player.seek(ats[index % ats.size()], true)
			animation_player.speed_scale = 0.0


func _read_arguments() -> void:
	for argument in OS.get_cmdline_user_args():
		var parts := argument.split("=", true, 1)
		if parts.size() < 2:
			continue
		match parts[0]:
			"units": unit_names = parts[1].split(",")
			"anim": animations = parts[1].split(",")
			"at": ats = PackedFloat64Array(Array(parts[1].split(",")).map(func(text: String) -> float: return float(text)))
			"yaw": yaw = float(parts[1])
			"scale": zoom = float(parts[1])
			"gap": gap = float(parts[1])
			"spin": spin = parts[1] == "1"
			"focus": focus = float(parts[1])
			"fov": fov = float(parts[1])


func _build_environment() -> void:
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
	var light := DirectionalLight3D.new()
	light.transform = Transform3D(Basis(Vector3(0.866025, 0, -0.5), Vector3(-0.353553, 0.707107, -0.612372),
			Vector3(0.353553, 0.707107, 0.612372)), Vector3(0, 10, 0))
	light.light_energy = 1.1
	light.shadow_enabled = true
	add_child(light)


func _add_tile(position_: Vector3) -> void:
	var tile := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(1.0, 0.1, 1.0)
	tile.mesh = box
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.45, 0.46, 0.5)
	box.material = material
	tile.position = position_ + Vector3(0, -0.05, 0)
	add_child(tile)


func _build_camera() -> void:
	var camera := Camera3D.new()
	add_child(camera)
	var span := maxf(unit_names.size() * gap, 3.0) / zoom
	var distance := 3.0 + span * 0.9
	var pitch := deg_to_rad(PITCH_DEGREES)
	var turn := deg_to_rad(yaw)
	var target := Vector3(0, focus, 0)
	camera.position = target + Vector3(sin(turn) * cos(pitch), sin(pitch), cos(turn) * cos(pitch)) * distance
	camera.look_at(target)
	camera.fov = fov
