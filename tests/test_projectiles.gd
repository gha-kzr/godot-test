extends TestCase
## Sky-falling projectiles, volleys of several, a heavy landing's shake, and ground effects
## that wait for the spell to land.

const RIG_SCENE := preload("res://scenes/battle/camera_rig.tscn")
const TIME_SCALE := 10.0


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
		player.fx = load("res://data/fx/battle_fx.tres") as BattleFx
		for node: Node in [board, units, player, rig]:
			root.add_child(node)
		(Engine.get_main_loop() as SceneTree).root.add_child(root)
		board.build(battle.state.grid)
		units.build(battle.state, board)
		player.setup(units, board, rig)


func _tree() -> SceneTree:
	return Engine.get_main_loop() as SceneTree


func _scene(node_name: String) -> PackedScene:
	var node := Node3D.new()
	node.name = node_name
	node.set_meta(&"marker", node_name)  # Several copies get odd names in the tree; the meta stays.
	var packed := PackedScene.new()
	packed.pack(node)
	node.free()
	return packed


func _stage(spell: SpellData) -> Stage:
	Engine.time_scale = TIME_SCALE
	var hero := BattleFixtures.unit("P0", 200, 3, 6, 20)
	hero.spells = [spell] as Array[SpellData]
	var stage := Stage.new(Battle.new(BattleFixtures.state_with("0p 0 0 0e", [hero], [BattleFixtures.unit("E0", 100, 3, 6, 400)])))
	stage.battle.start()
	return stage


## Plays the cast and watches the board: every "Bolt" seen (first position, in order) and
## the "Boom" ground effects when the hit lands.
func _watch(stage: Stage) -> Dictionary:
	var result := stage.battle.perform(BattleActions.CastSpell.new(0, 0, Vector2i(3, 0)))
	var seen: Dictionary = {}
	var last: Dictionary = {}
	var destinations: Array[Vector3] = []
	stage.player.projectile_launched.connect(func(end: Vector3) -> void: destinations.append(end))
	var first_positions: Array[Vector3] = []
	var booms_when_hit := [-1]
	var started := Time.get_ticks_msec()
	var landed := [-1.0]
	stage.player.event_played.connect(func(event: BattleEvents.Event) -> void:
		if event is BattleEvents.DamageDealt and landed[0] < 0.0:
			landed[0] = (Time.get_ticks_msec() - started) / 1000.0 * TIME_SCALE
			booms_when_hit[0] = _count(stage.board, "Boom"))
	stage.player.play(result.events)
	for i in 1500:
		for node in stage.board.get_children():
			if node.get_meta(&"marker", "") == "Bolt" and not seen.has(node.get_instance_id()):
				seen[node.get_instance_id()] = true
				first_positions.append((node as Node3D).global_position)
			if node.get_meta(&"marker", "") == "Bolt":
				last[node.get_instance_id()] = (node as Node3D).global_position
		if not stage.player.is_playing and i > 3:
			break
		await _tree().process_frame
	return {"bolts": seen.size(), "last": destinations, "first": first_positions, "landed": landed[0], "booms_at_hit": booms_when_hit[0],
			"left_over": _count(stage.board, "Bolt")}


func _count(parent: Node, marker: String) -> int:
	return parent.get_children().filter(func(c: Node) -> bool: return c.get_meta(&"marker", "") == marker).size()


func _done(stage: Stage) -> void:
	stage.root.free()
	Engine.time_scale = 1.0


func test_a_falling_projectile_starts_high_above_the_target_cell_and_lands_on_it() -> void:
	var spell := BattleFixtures.damage_spell(2, 1, 5, 3)
	spell.projectile = _scene("Bolt")
	spell.projectile_falls = true
	spell.projectile_speed = 7.0  # Seven units of sky: a second of fall.
	spell.impact_delay = 0.1
	var stage := _stage(spell)
	var target := stage.board.cell_to_world(Vector2i(3, 0))
	var watched: Dictionary = await _watch(stage)
	assert_eq(watched["bolts"], 1)
	var start: Vector3 = watched["first"][0]
	assert_true(start.y > target.y + 3.0, "it begins in the sky: %s" % start)
	assert_true(absf(start.x - target.x) < 0.5 and absf(start.z - target.z) < 0.5, "above the target: %s vs %s" % [start, target])
	assert_true(watched["landed"] >= 0.9, "the effects wait for the fall: %f" % watched["landed"])
	assert_eq(watched["left_over"], 0, "and the projectile is gone")
	_done(stage)


func test_a_volley_sends_several_projectiles_one_after_the_other_and_lands_after_the_last() -> void:
	var spell := BattleFixtures.damage_spell(2, 1, 5, 3, AreaShape.Kind.CIRCLE, 1)
	spell.projectile = _scene("Bolt")
	spell.projectile_count = 5
	spell.projectile_interval = 0.2
	spell.projectile_speed = 8.0
	spell.impact_delay = 0.0
	var stage := _stage(spell)
	var watched: Dictionary = await _watch(stage)
	assert_eq(watched["bolts"], 5, "five projectiles in the air one after another")
	var headings := {}
	for position: Vector3 in watched["last"]:
		headings[Vector2i(roundi(position.x), roundi(position.z))] = true  # Jitter is under 0.2: the cell stays the same.
	assert_true(headings.size() >= 2, "they spread over the cells of the area (two here: the board is one row), not all at one point: %s" % [headings.keys()])
	assert_true(watched["landed"] >= 0.8, "the effects wait for the last one (4 x 0.2 s apart): %f" % watched["landed"])
	assert_eq(watched["left_over"], 0)
	_done(stage)


func test_a_heavy_landing_shakes_the_camera_when_the_effects_land() -> void:
	var spell := BattleFixtures.damage_spell(2, 1, 5, 3)
	spell.projectile = _scene("Bolt")
	spell.projectile_falls = true
	spell.projectile_speed = 14.0
	spell.impact_delay = 0.0
	spell.impact_shake = 0.2
	var stage := _stage(spell)
	assert_eq(stage.rig._shake_strength, 0.0)
	await _watch(stage)
	assert_eq(stage.rig._shake_strength, 0.2, "the spell's own shake")
	_done(stage)


func test_ground_effects_appear_where_the_effects_land_not_when_the_cast_starts() -> void:
	var spell := BattleFixtures.damage_spell(2, 1, 5, 3, AreaShape.Kind.CIRCLE, 1)
	spell.impact_effect = _scene("Boom")
	spell.impact_delay = 0.8
	var stage := _stage(spell)
	var watched: Dictionary = await _watch(stage)
	assert_eq(watched["booms_at_hit"], 1, "the one empty cell next to the target (the board is a single row) blows up as the hit lands")
	var early := _stage(spell)
	var result := early.battle.perform(BattleActions.CastSpell.new(0, 0, Vector2i(3, 0)))
	early.player.play(result.events)
	await _tree().process_frame
	assert_eq(_count(early.board, "Boom"), 0, "nothing at the start of the cast")
	for i in 1500:
		if not early.player.is_playing and i > 3:
			break
		await _tree().process_frame
	_done(early)
	_done(stage)


func test_the_shipped_fireball_falls_and_the_volley_is_many_arrows() -> void:
	var fireball := load("res://data/spells/fireball.tres") as SpellData
	assert_true(fireball.projectile_falls and fireball.projectile != null and fireball.impact_shake > 0.0, "a big falling fireball")
	var volley := load("res://data/spells/volley.tres") as SpellData
	assert_true(volley.projectile_count >= 5 and volley.projectile != null, "a volley of several arrows")
	assert_eq(fireball.get_validation_errors().size() + volley.get_validation_errors().size(), 0)
