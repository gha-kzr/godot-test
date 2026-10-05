class_name ModelWorkshop
extends Node3D
## The model workshop: refine a hand-built model without touching its recipe. The model stands on
## a tile in the battle's light; a tree lists its joints and parts, an inspector edits the selected
## one (move, turn, scale, color, glow, hide; a joint's pose at the clip's current time), and
## everything is kept in the model's tweaks file (see ModelTweaks), which a rebuild re-applies.
## The rules are in WorkshopSession; this is the screen.
##   godot scenes/tools/model_workshop.tscn -- model=knight
## Arguments after `--`: `model=<recipe name>` (default: the first), `clip=Idle`, `at=0.3` (seconds
## into the clip), `select=Rig/Hips/Head` (a node's path), `tab=1` (the Pose tab), `yaw=25`, `zoom=1`. Not translated: a developer tool.
## Mouse: drag to turn around the model, wheel to zoom. Keys: Ctrl / Cmd + Z undo, + Shift + Z or
## Y redo, + S save. The recipe is read again when its file is saved.

const PITCH_DEGREES := 28.0
const FOCUS := Vector3(0.0, 0.7, 0.0)
const POLL_SECONDS := 0.5
const HIGHLIGHT := Color(1.0, 0.82, 0.2, 0.45)

var session := WorkshopSession.new()

var _model_name := ""
var _yaw := 25.0
var _zoom := 1.0
var _camera: Camera3D
var _holder: Node3D
var _player: AnimationPlayer
var _clip := "Idle"
var _time := 0.0
var _playing := false
var _selected := ""  # A node's name path, "" for none.
var _highlight_material: StandardMaterial3D
var _highlighted: Array[MeshInstance3D] = []
var _recipe_stamp := 0
var _poll := 0.0
var _paths: PackedStringArray = []

var _model_picker: OptionButton
var _original_box: CheckBox
var _undo_button: Button
var _redo_button: Button
var _save_button: Button
var _status: Label
var _tree: Tree
var _items: Dictionary[String, TreeItem] = {}
var _orphan_box: VBoxContainer
var _orphan_list: ItemList
var _tabs: TabContainer
var _first_tab := 0
var _node_box: VBoxContainer
var _pose_box: VBoxContainer
var _override_list: ItemList
var _clip_picker: OptionButton
var _play_button: Button
var _time_slider: HSlider
var _time_label: Label


func _ready() -> void:
	var recipes := ModelBuilder.recipe_names()
	_model_name = recipes[0] if not recipes.is_empty() else ""
	_read_arguments()
	ModelStage.build_environment(self)
	ModelStage.add_tile(self, Vector3.ZERO)
	_holder = Node3D.new()
	add_child(_holder)
	_camera = Camera3D.new()
	_camera.fov = 35.0
	add_child(_camera)
	_highlight_material = StandardMaterial3D.new()
	_highlight_material.albedo_color = HIGHLIGHT
	_highlight_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_highlight_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_highlight_material.no_depth_test = true
	_build_ui(recipes)
	session.rebuilt.connect(_on_rebuilt)
	var wanted := _selected
	_open(_model_name)
	if _items.has(wanted):
		_items[wanted].select(0)  # Runs the tree's handler: highlight and inspector.
	_tabs.current_tab = _first_tab
	_place_camera()


func _read_arguments() -> void:
	for argument in OS.get_cmdline_user_args():
		var parts := argument.split("=", true, 1)
		if parts.size() < 2:
			continue
		match parts[0]:
			"model": _model_name = parts[1]
			"clip": _clip = parts[1]
			"at": _time = float(parts[1])
			"select": _selected = parts[1]
			"tab": _first_tab = int(parts[1])
			"yaw": _yaw = float(parts[1])
			"zoom": _zoom = float(parts[1])


func _open(model_name: String) -> void:
	_model_name = model_name
	if not session.open(model_name):
		_status.text = "The recipe '%s' doesn't load." % model_name
		return
	_recipe_stamp = FileAccess.get_modified_time(ModelBuilder.recipe_path(model_name))
	_model_picker.select(ModelBuilder.recipe_names().find(model_name))


func _process(delta: float) -> void:
	if _playing and _player != null:
		var length := _clip_length()
		_time = fmod(_time + delta, length) if length > 0.0 else 0.0
		_show_time()
	_poll += delta
	if _poll >= POLL_SECONDS:
		_poll = 0.0
		var stamp := FileAccess.get_modified_time(ModelBuilder.recipe_path(_model_name))
		if stamp != _recipe_stamp:
			_recipe_stamp = stamp
			if session.rebuild(true):
				_status.text = "Recipe reloaded."
			else:
				_status.text = "The recipe doesn't load (see the log)."


# --- Camera --------------------------------------------------------------------------------

func _place_camera() -> void:
	var pitch := deg_to_rad(PITCH_DEGREES)
	var turn := deg_to_rad(_yaw)
	var distance := 4.2 / _zoom
	_camera.position = FOCUS + Vector3(sin(turn) * cos(pitch), sin(pitch), cos(turn) * cos(pitch)) * distance
	_camera.look_at(FOCUS)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and (event.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
		_yaw -= (event as InputEventMouseMotion).relative.x * 0.5
		_place_camera()
	elif event is InputEventMouseButton and event.pressed:
		var button := (event as InputEventMouseButton).button_index
		if button == MOUSE_BUTTON_WHEEL_UP:
			_zoom = minf(_zoom * 1.1, 6.0)
			_place_camera()
		elif button == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom = maxf(_zoom / 1.1, 0.4)
			_place_camera()
	elif event is InputEventKey and event.pressed and not event.echo and (event.ctrl_pressed or event.meta_pressed):
		match (event as InputEventKey).keycode:
			KEY_Z:
				if event.shift_pressed:
					session.redo()
				else:
					session.undo()
				_refresh_pose_box()
				get_viewport().set_input_as_handled()
			KEY_Y:
				session.redo()
				_refresh_pose_box()
				get_viewport().set_input_as_handled()
			KEY_S:
				_save()
				get_viewport().set_input_as_handled()


# --- The model on stage --------------------------------------------------------------------

func _on_rebuilt() -> void:
	for child in _holder.get_children():
		_holder.remove_child(child)
	_holder.add_child(session.kit.root)
	_player = session.kit.root.get_node_or_null("AnimationPlayer") as AnimationPlayer
	_highlighted.clear()
	_fill_clip_picker()
	_show_time()
	var paths := session.node_paths()
	if paths != _paths:
		_paths = paths
		_fill_tree()
	_refresh_markers()
	_apply_highlight()
	_refresh_orphans()
	_refresh_buttons()


func _fill_clip_picker() -> void:
	var names: PackedStringArray = _player.get_animation_list() if _player != null else PackedStringArray()
	var wanted := _clip
	_clip_picker.clear()
	for clip_name in names:
		_clip_picker.add_item(clip_name)
	var index := names.find(wanted)
	if index < 0:
		index = names.find("Idle") if names.has("Idle") else 0
	if not names.is_empty():
		_clip_picker.select(index)
		_clip = names[index]
	_time_slider.max_value = _clip_length()
	_time = clampf(_time, 0.0, _clip_length())


func _clip_length() -> float:
	return _player.get_animation(_clip).length if _player != null and _player.has_animation(_clip) else 0.0


## Puts the model's pose at the current time of the clip.
func _show_time() -> void:
	if _player != null and _player.has_animation(_clip):
		_player.play(_clip, 0.0)
		_player.speed_scale = 0.0
		_player.seek(_time, true)
	_time_slider.set_value_no_signal(_time)
	_time_label.text = "%.2f / %.2f s" % [_time, _clip_length()]


func _apply_highlight() -> void:
	for part in _highlighted:
		if is_instance_valid(part):
			part.material_overlay = null
	_highlighted.clear()
	var node := session.kit.root.get_node_or_null(_selected) as Node3D if not _selected.is_empty() else null
	if node == null:
		return
	var parts: Array[Node] = node.find_children("*", "MeshInstance3D", true, false)
	if node is MeshInstance3D:
		parts.append(node)
	for part in parts:
		(part as MeshInstance3D).material_overlay = _highlight_material
		_highlighted.append(part as MeshInstance3D)


# --- UI ------------------------------------------------------------------------------------

func _build_ui(recipes: PackedStringArray) -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED  # A developer tool: English only.
	layer.add_child(root)
	# Top bar.
	var top := _panel(root, Control.PRESET_TOP_WIDE, Vector2(8, 8), Vector2(-8, 56))
	var top_row := HBoxContainer.new()
	top.add_child(top_row)
	_model_picker = OptionButton.new()
	for recipe in recipes:
		_model_picker.add_item(recipe)
	_model_picker.item_selected.connect(func(index: int) -> void: _open(recipes[index]))
	top_row.add_child(_model_picker)
	_original_box = CheckBox.new()
	_original_box.text = "Original (no tweaks)"
	_original_box.toggled.connect(func(on: bool) -> void: session.show_original = on)
	top_row.add_child(_original_box)
	_undo_button = _button(top_row, "Undo", func() -> void: session.undo(); _refresh_pose_box())
	_redo_button = _button(top_row, "Redo", func() -> void: session.redo(); _refresh_pose_box())
	_save_button = _button(top_row, "Save", _save)
	_status = Label.new()
	_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_status.clip_text = true
	top_row.add_child(_status)
	# Left: the tree and the orphans.
	var left := _panel(root, Control.PRESET_LEFT_WIDE, Vector2(8, 64), Vector2(300, -72))
	var left_rows := VBoxContainer.new()
	left.add_child(left_rows)
	_tree = Tree.new()
	_tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_tree.hide_root = true
	_tree.item_selected.connect(_on_tree_selected)
	left_rows.add_child(_tree)
	_orphan_box = VBoxContainer.new()
	left_rows.add_child(_orphan_box)
	var orphan_title := Label.new()
	orphan_title.text = "Tweaks without a node (pick one, select its new node, map it):"
	orphan_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_orphan_box.add_child(orphan_title)
	_orphan_list = ItemList.new()
	_orphan_list.custom_minimum_size = Vector2(0, 70)
	_orphan_box.add_child(_orphan_list)
	_button(_orphan_box, "Map to the selected node", _map_orphan)
	# Right: the inspector.
	var right := _panel(root, Control.PRESET_RIGHT_WIDE, Vector2(-350, 64), Vector2(-8, -72))
	_tabs = TabContainer.new()
	right.add_child(_tabs)
	_node_box = _tab("Node")
	_pose_box = _tab("Pose")
	# Bottom: the clip.
	var bottom := _panel(root, Control.PRESET_BOTTOM_WIDE, Vector2(308, -64), Vector2(-358, -8))
	var bottom_row := HBoxContainer.new()
	bottom.add_child(bottom_row)
	_clip_picker = OptionButton.new()
	_clip_picker.item_selected.connect(func(index: int) -> void:
		_clip = _clip_picker.get_item_text(index)
		_time = 0.0
		_time_slider.max_value = _clip_length()
		_show_time()
		_refresh_pose_box())
	bottom_row.add_child(_clip_picker)
	_play_button = _button(bottom_row, "Play", func() -> void:
		_playing = not _playing
		_play_button.text = "Pause" if _playing else "Play"
		_refresh_pose_box())
	_button(bottom_row, "< key", func() -> void: _step_key(-1))
	_time_slider = HSlider.new()
	_time_slider.step = 0.01
	_time_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_time_slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_time_slider.value_changed.connect(func(value: float) -> void:
		_playing = false
		_play_button.text = "Play"
		_time = value
		_show_time()
		_refresh_pose_box())
	bottom_row.add_child(_time_slider)
	_button(bottom_row, "key >", func() -> void: _step_key(1))
	_time_label = Label.new()
	_time_label.custom_minimum_size = Vector2(110, 0)
	bottom_row.add_child(_time_label)
	_refresh_node_box()
	_refresh_pose_box()


## A scrolling tab of the inspector; returns the box to fill.
func _tab(title: String) -> VBoxContainer:
	var scroll := ScrollContainer.new()
	scroll.name = title
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_tabs.add_child(scroll)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(box)
	return box


func _panel(parent: Control, preset: Control.LayoutPreset, top_left: Vector2, bottom_right: Vector2) -> PanelContainer:
	var panel := PanelContainer.new()
	parent.add_child(panel)
	panel.set_anchors_preset(preset)
	panel.offset_left = top_left.x
	panel.offset_top = top_left.y
	panel.offset_right = bottom_right.x
	panel.offset_bottom = bottom_right.y
	return panel


func _button(parent: Control, text: String, on_pressed: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(on_pressed)
	parent.add_child(button)
	return button


func _refresh_buttons() -> void:
	_undo_button.disabled = not session.can_undo()
	_redo_button.disabled = not session.can_redo()
	_save_button.text = "Save" + (" *" if session.dirty else "")
	_orphan_box.visible = not session.orphans().is_empty()


func _save() -> void:
	var error := session.save()
	_status.text = "Saved." if error == OK else "Save failed: %s" % error_string(error)
	_refresh_buttons()


# --- The tree ------------------------------------------------------------------------------

func _fill_tree() -> void:
	_tree.clear()
	_items.clear()
	var root := _tree.create_item()
	for path in _paths:
		var parent_path := path.get_base_dir()
		var parent_item: TreeItem = _items.get(parent_path, root)
		var item := _tree.create_item(parent_item)
		item.set_metadata(0, path)
		_items[path] = item
	_refresh_markers()
	if _items.has(_selected):
		_items[_selected].select(0)
	elif not _paths.is_empty():
		_selected = ""
		_refresh_node_box()
		_refresh_pose_box()


## The item texts: the node's name, a dot when it has a tweak, "(joint)" for a joint.
func _refresh_markers() -> void:
	var joint_nodes: Array = session.kit.joints.values()
	for path in _items:
		var item := _items[path]
		var tweak := session.node_tweak(path)
		var node := session.kit.root.get_node_or_null(path)
		var label := path.get_file()
		if node != null and node in joint_nodes:
			label += " (joint)"
		if tweak != null and not tweak.is_empty():
			label += " •"
		item.set_text(0, label)


func _on_tree_selected() -> void:
	var item := _tree.get_selected()
	_selected = item.get_metadata(0) if item != null else ""
	_apply_highlight()
	_refresh_node_box()
	_refresh_pose_box()


# --- The inspector: the selected node ------------------------------------------------------

func _clear(box: Control) -> void:
	for child in box.get_children():
		box.remove_child(child)
		child.queue_free()


func _label(parent: Control, text: String, bold := false) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if bold:
		label.add_theme_font_size_override("font_size", 18)
	parent.add_child(label)
	return label


## A labelled slider with a number box; `on_change(value)` after `session.remember()` (once per drag).
func _slider(parent: Control, text: String, low: float, high: float, step: float, value: float, on_change: Callable) -> void:
	var row := HBoxContainer.new()
	parent.add_child(row)
	var label := Label.new()
	label.text = text
	label.custom_minimum_size = Vector2(54, 0)
	row.add_child(label)
	var slider := HSlider.new()
	slider.min_value = low
	slider.max_value = high
	slider.step = step
	slider.set_value_no_signal(value)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(slider)
	var spin := SpinBox.new()
	spin.min_value = low
	spin.max_value = high
	spin.step = step
	spin.allow_greater = true
	spin.allow_lesser = true
	spin.custom_minimum_size = Vector2(86, 0)
	spin.set_value_no_signal(value)
	row.add_child(spin)
	var state := {"dragging": false}
	slider.drag_started.connect(func() -> void:
		state.dragging = true
		session.remember())
	slider.drag_ended.connect(func(_changed: bool) -> void: state.dragging = false)
	slider.value_changed.connect(func(new_value: float) -> void:
		spin.set_value_no_signal(new_value)
		if not state.dragging:
			session.remember()
		on_change.call(new_value))
	spin.value_changed.connect(func(new_value: float) -> void:
		slider.set_value_no_signal(new_value)
		session.remember()
		on_change.call(new_value))


## Three sliders for a Vector3 field of the selected node's tweak.
func _vector_rows(parent: Control, text: String, field: String, low: float, high: float, step: float, neutral: Vector3) -> void:
	if not text.is_empty():
		_label(parent, text)
	var tweak := session.node_tweak(_selected)
	var current: Vector3 = tweak.get(field) if tweak != null else neutral
	var path := _selected
	for axis in 3:
		_slider(parent, "XYZ"[axis], low, high, step, current[axis], func(value: float) -> void:
			var existing := session.node_tweak(path)
			var vector: Vector3 = existing.get(field) if existing != null else neutral
			vector[axis] = value
			session.set_node_field(path, field, vector, false))


func _refresh_node_box() -> void:
	_clear(_node_box)
	if _selected.is_empty() or session.kit == null:
		_label(_node_box, "Select a part or a joint in the tree.")
		return
	var node := session.kit.root.get_node_or_null(_selected) as Node3D
	if node == null:
		return
	var is_joint := node in session.kit.joints.values()
	_label(_node_box, "%s%s" % [_selected.get_file(), " (joint)" if is_joint else ""], true)
	_label(_node_box, _selected)
	_vector_rows(_node_box, "Move (m)", "position_offset", -0.4, 0.4, 0.005, Vector3.ZERO)
	_vector_rows(_node_box, "Turn (degrees)", "rotation_offset", -180.0, 180.0, 1.0, Vector3.ZERO)
	_label(_node_box, "Scale")
	var path := _selected
	var tweak := session.node_tweak(path)
	_slider(_node_box, "All", 0.2, 3.0, 0.01, tweak.scale_factor.x if tweak != null else 1.0, func(value: float) -> void:
		session.set_node_field(path, "scale_factor", Vector3.ONE * value, false))
	_vector_rows(_node_box, "", "scale_factor", 0.2, 3.0, 0.01, Vector3.ONE)
	if node is MeshInstance3D:
		_part_rows(node as MeshInstance3D)
	_button(_node_box, "Reset this node", func() -> void:
		session.reset_node(path)
		_refresh_node_box())


func _part_rows(part: MeshInstance3D) -> void:
	var path := _selected
	var look := session.kit.look_of(part)
	var tweak := session.node_tweak(path)
	_label(_node_box, "Color")
	var picker := ColorPickerButton.new()
	picker.color = look["color"]
	picker.custom_minimum_size = Vector2(0, 32)
	picker.edit_alpha = false
	picker.focus_mode = Control.FOCUS_NONE
	picker.color_changed.connect(func(color: Color) -> void:
		session.set_node_field(path, "color", color, false)
		session.set_node_field(path, "recolor", true, false))
	picker.pressed.connect(func() -> void: session.remember())
	_node_box.add_child(picker)
	var glow := CheckBox.new()
	glow.text = "Glow"
	glow.button_pressed = tweak != null and tweak.emissive >= 0.0 or (look["emissive"] as float) > 0.0
	_node_box.add_child(glow)
	var glow_box := VBoxContainer.new()
	_node_box.add_child(glow_box)
	_slider(glow_box, "Power", 0.0, 3.0, 0.05, look["emissive"], func(value: float) -> void:
		session.set_node_field(path, "emissive", value, false))
	glow.toggled.connect(func(on: bool) -> void:
		session.set_node_field(path, "emissive", look["emissive"] as float if on else 0.0)
		glow_box.visible = on)
	glow_box.visible = glow.button_pressed
	var hidden := CheckBox.new()
	hidden.text = "Hidden"
	hidden.button_pressed = tweak != null and tweak.hidden
	hidden.toggled.connect(func(on: bool) -> void: session.set_node_field(path, "hidden", on))
	_node_box.add_child(hidden)


# --- The inspector: the pose at the current time -------------------------------------------

## The joint name of the selected node, "" when it is not a joint.
func _selected_joint() -> String:
	if _selected.is_empty() or session.kit == null:
		return ""
	var node := session.kit.root.get_node_or_null(_selected)
	for joint_name in session.kit.joints:
		if session.kit.joints[joint_name] == node:
			return joint_name
	return ""


func _refresh_pose_box() -> void:
	if _pose_box == null:
		return
	_clear(_pose_box)
	_refresh_buttons()
	_label(_pose_box, "Pose overrides of %s" % _clip, true)
	_override_list = ItemList.new()
	_override_list.custom_minimum_size = Vector2(0, 80)
	for override in session.overrides_of(_clip):
		_override_list.add_item("%.2f s  %s %s" % [override.time, override.joint, "position" if override.is_position else "rotation"])
		_override_list.set_item_metadata(_override_list.item_count - 1, override)
	_override_list.item_selected.connect(_on_override_picked)
	_pose_box.add_child(_override_list)
	var joint_name := _selected_joint()
	if joint_name.is_empty():
		_label(_pose_box, "Select a joint (listed \"(joint)\") to set its pose at this time.")
		return
	_label(_pose_box, "%s at %.2f s" % [joint_name, _time])
	if _playing:
		_label(_pose_box, "Pause to edit the pose.")
		return
	var rest: Dictionary = session.rests[joint_name]
	var node: Node3D = session.kit.joints[joint_name]
	var rotation_now := ((node.rotation - (rest["rotation"] as Vector3)) * (180.0 / PI)).snapped(Vector3.ONE * 0.01)
	var position_now := (node.position - (rest["position"] as Vector3)).snapped(Vector3.ONE * 0.001)
	var clip := _clip
	var time := _time
	_pose_vector(joint_name, "Rotation (degrees)", false, rotation_now, -180.0, 180.0, 1.0, clip, time)
	_pose_vector(joint_name, "Position offset (m)", true, position_now, -0.5, 0.5, 0.005, clip, time)
	_button(_pose_box, "Remove the overrides of this joint here", func() -> void:
		session.remove_pose(clip, time, joint_name, false)
		session.remove_pose(clip, time, joint_name, true)
		_refresh_pose_box())


func _pose_vector(joint_name: String, text: String, is_position: bool, current: Vector3, low: float, high: float,
		step: float, clip: String, time: float) -> void:
	_label(_pose_box, text)
	var values := current
	for axis in 3:
		_slider(_pose_box, "XYZ"[axis], low, high, step, current[axis], func(value: float) -> void:
			values[axis] = value
			session.set_pose(clip, time, joint_name, is_position, values, false)
			_show_time())


func _on_override_picked(index: int) -> void:
	var override := _override_list.get_item_metadata(index) as PoseOverride
	_playing = false
	_play_button.text = "Play"
	_time = override.time
	_show_time()
	var path := _path_of_joint(override.joint)
	_tabs.current_tab = 1
	if _items.has(path):
		_items[path].select(0)
	else:
		_refresh_pose_box()


func _path_of_joint(joint_name: String) -> String:
	var node: Node = session.kit.joints.get(joint_name)
	return String(session.kit.root.get_path_to(node)) if node != null else ""


## Moves the time to the previous / next key of the clip (every track's key times).
func _step_key(direction: int) -> void:
	if _player == null or not _player.has_animation(_clip):
		return
	var animation := _player.get_animation(_clip)
	var times: Array[float] = []
	for track in animation.get_track_count():
		for key in animation.track_get_key_count(track):
			var key_time := animation.track_get_key_time(track, key)
			if not times.any(func(t: float) -> bool: return absf(t - key_time) < PoseOverride.SAME_TIME):
				times.append(key_time)
	times.sort()
	var target := _time
	if direction > 0:
		for key_time in times:
			if key_time > _time + PoseOverride.SAME_TIME:
				target = key_time
				break
	else:
		for key_time in times:
			if key_time < _time - PoseOverride.SAME_TIME:
				target = key_time
	_playing = false
	_play_button.text = "Play"
	_time = target
	_show_time()
	_refresh_pose_box()


# --- Orphans -------------------------------------------------------------------------------

func _refresh_orphans() -> void:
	_orphan_list.clear()
	for orphan in session.orphans():
		_orphan_list.add_item(orphan)


func _map_orphan() -> void:
	var picked := _orphan_list.get_selected_items()
	if picked.is_empty() or _selected.is_empty():
		_status.text = "Pick an orphan and select its new node first."
		return
	session.map_orphan(_orphan_list.get_item_text(picked[0]), _selected)
