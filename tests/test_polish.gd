extends TestCase
## Feedback polish: the camera shakes on a big hit, statuses show a looping aura on their carrier.

const RIG_SCENE := preload("res://scenes/battle/camera_rig.tscn")


class Stage:
	var root := Node3D.new()
	var board := BoardView.new()
	var units := UnitsView.new()
	var player := EventPlayer.new()
	var rig: CameraRig
	var battle: Battle

	func _init(battle_to_show: Battle) -> void:
		battle = battle_to_show
		rig = RIG_SCENE.instantiate() as CameraRig
		root.add_child(board)
		root.add_child(units)
		root.add_child(player)
		root.add_child(rig)
		(Engine.get_main_loop() as SceneTree).root.add_child(root)
		board.build(battle.state.grid)
		units.build(battle.state, board)
		player.setup(units, board, rig)


func _tree() -> SceneTree:
	return Engine.get_main_loop() as SceneTree


func _stage() -> Stage:
	var hero := BattleFixtures.unit("P0", 200, 3, 6, 40)
	var enemy := BattleFixtures.unit("E0", 100, 3, 6, 40)
	var battle := Battle.new(BattleFixtures.state_with("0p 0 0 0e", [hero], [enemy]))
	battle.start()
	return Stage.new(battle)


func _aura_scene() -> PackedScene:
	var root := Node3D.new()
	root.name = "Aura"
	var particles := CPUParticles3D.new()
	root.add_child(particles)
	particles.owner = root
	var scene := PackedScene.new()
	scene.pack(root)
	root.free()
	return scene


func test_the_camera_shakes_then_settles_back_where_it_was() -> void:
	Engine.time_scale = 10.0
	var rig := RIG_SCENE.instantiate() as CameraRig
	_tree().root.add_child(rig)
	var rest := rig.camera.v_offset
	rig.shake(0.2, 0.3)
	assert_true(rig.is_shaking())
	var moved := false
	for i in 300:
		await _tree().process_frame
		moved = moved or rig.camera.h_offset != 0.0
		if not rig.is_shaking():
			break
	assert_true(moved, "the picture was jolted")
	await _tree().process_frame
	assert_eq([rig.camera.h_offset, rig.camera.v_offset], [0.0, rest], "and rests on its own offset again")
	assert_eq(rig.position, Vector3.ZERO, "the focus point never moved")
	rig.free()
	Engine.time_scale = 1.0


func test_a_weaker_shake_does_not_cut_a_stronger_one_short() -> void:
	var rig := RIG_SCENE.instantiate() as CameraRig
	_tree().root.add_child(rig)
	rig.shake(0.3, 1.0)
	rig.shake(0.05, 0.1)
	assert_eq(rig._shake_strength, 0.3, "still the strong one")
	rig.shake(0.5, 0.2)
	assert_eq(rig._shake_strength, 0.5, "a stronger one replaces it")
	rig.free()


func test_only_a_big_hit_shakes_the_camera() -> void:
	Engine.time_scale = 10.0
	var stage := _stage()
	var small := BattleEvents.DamageDealt.new(1, 4, 36)  # 4 of 40 HP.
	stage.player.play([small] as Array[BattleEvents.Event])
	for i in 60:
		await _tree().process_frame
	assert_eq(stage.rig._shake_strength, 0.0, "a scratch never starts a shake")
	var big := BattleEvents.DamageDealt.new(1, 20, 20)  # Half of 40 HP.
	stage.player.play([big] as Array[BattleEvents.Event])
	await _tree().process_frame
	assert_true(stage.rig.is_shaking(), "a hit for half the HP is")
	var strength := stage.rig._shake_strength
	for i in 200:
		if not stage.player.is_playing and not stage.rig.is_shaking():
			break
		await _tree().process_frame
	var huge := BattleEvents.DamageDealt.new(1, 40, 0)
	stage.player.play([huge] as Array[BattleEvents.Event])
	await _tree().process_frame
	assert_true(stage.rig._shake_strength > strength, "the bigger the hit, the harder the shake")
	for i in 200:  # Let the playback finish before the nodes go.
		if not stage.player.is_playing:
			break
		await _tree().process_frame
	stage.root.free()
	Engine.time_scale = 1.0


func test_a_status_with_an_aura_shows_it_while_it_lasts() -> void:
	Engine.time_scale = 10.0
	var stage := _stage()
	var status := (load("res://data/statuses/poison.tres") as StatusData).duplicate() as StatusData
	status.aura_effect = _aura_scene()
	var plain := (load("res://data/statuses/guarded.tres") as StatusData).duplicate() as StatusData
	plain.aura_effect = null
	var view := stage.units.view(1)
	await view.play_status_applied(plain, 2)
	assert_eq(view.aura_count(), 0, "no aura without a scene")
	await view.play_status_applied(status, 3)
	assert_eq(view.aura_count(), 1, "the aura shows")
	await view.play_status_applied(status, 3)
	assert_eq(view.aura_count(), 1, "refreshing the status doesn't stack it")
	await view.play_status_expired(status)
	assert_eq(view.aura_count(), 0, "gone when the status ends")
	stage.root.free()
	Engine.time_scale = 1.0


func test_a_sync_after_playback_keeps_the_aura_of_a_status_still_carried() -> void:
	Engine.time_scale = 10.0
	var stage := _stage()
	var status := (load("res://data/statuses/poison.tres") as StatusData).duplicate() as StatusData
	status.aura_effect = _aura_scene()
	var view := stage.units.view(1)
	await view.play_status_applied(status, 3)
	var aura: Node = view._auras[status]
	var unit := stage.battle.state.units[1]
	var carried := StatusInstance.new(status, 0, 2)
	unit.statuses.append(carried)
	view.sync(unit)
	assert_true(is_instance_valid(aura) and not aura.is_queued_for_deletion(), "the same aura keeps playing")
	assert_eq(view.aura_count(), 1)
	unit.statuses.clear()
	view.sync(unit)
	assert_eq(view.aura_count(), 0, "gone once the status is")
	stage.root.free()
	Engine.time_scale = 1.0
