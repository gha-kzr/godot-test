extends TestCase
## Mouse picking on the slice map through a real camera: cell tops, unit bodies, and the
## normal vs. overhead views. Colliders need a physics frame before rays can hit them.

const SLICE_MAP := "res://data/maps/slice.tres"
const PLAYERS := ["res://data/units/knight.tres", "res://data/units/mage.tres"]
const ENEMIES := ["res://data/units/brute.tres", "res://data/units/skeleton_archer.tres"]


class Stage:
	var root := Node3D.new()
	var board := BoardView.new()
	var units := UnitsView.new()
	var rig: CameraRig
	var state: BattleState

	func _init(with_units: bool) -> void:
		var tree := Engine.get_main_loop() as SceneTree
		var map := load(SLICE_MAP) as MapData
		var players: Array[UnitData] = []
		var enemies: Array[UnitData] = []
		if with_units:
			for path: String in PLAYERS:
				players.append(load(path))
			for path: String in ENEMIES:
				enemies.append(load(path))
		else:  # BattleState needs a unit per team; park them where the test won't click.
			players.append(BattleFixtures.unit("P"))
			enemies.append(BattleFixtures.unit("E"))
		state = BattleState.create(map.parse(), players, enemies, 1)
		rig = (load("res://scenes/battle/camera_rig.tscn") as PackedScene).instantiate()
		root.add_child(rig)
		root.add_child(board)
		root.add_child(units)
		tree.root.add_child(root)
		board.build(state.grid)
		if with_units:
			units.build(state, board)
		rig.focus(board.center())

	func ready_for_picking() -> void:
		var tree := Engine.get_main_loop() as SceneTree
		await tree.physics_frame
		await tree.physics_frame

	func pick_at(world_point: Vector3) -> Vector2i:
		return board.pick_cell(rig.camera, rig.camera.unproject_position(world_point))

	func cell_top(cell: Vector2i) -> Vector3:
		return board.to_global(board.cell_to_world(cell))


## Floor cells whose top center picks another cell, for each of the 4 camera turns.
## Returns "cell -> picked" strings.
func _mispicks(stage: Stage) -> Array[String]:
	var mispicks: Array[String] = []
	var grid := stage.state.grid
	for turn in 4:
		for y in grid.size.y:
			for x in grid.size.x:
				var cell := Vector2i(x, y)
				if not grid.is_walkable(cell):
					continue
				var picked := stage.pick_at(stage.cell_top(cell))
				if picked != cell:
					mispicks.append("turn %d: %s -> %s" % [turn, cell, picked])
		stage.rig.rotate_steps(1, false)
	return mispicks


func test_cell_centers_are_only_hidden_by_obstacles_or_two_level_walls() -> void:
	var stage := Stage.new(false)
	await stage.ready_for_picking()
	var grid := stage.state.grid
	for turn in 4:
		for y in grid.size.y:
			for x in grid.size.x:
				var cell := Vector2i(x, y)
				if not grid.is_walkable(cell):
					continue
				var picked := stage.pick_at(stage.cell_top(cell))
				if picked == cell:
					continue
				var hidden_ok := picked != BoardView.NO_CELL and (grid.type_at(picked) == Grid.CellType.OBSTACLE
						or grid.height_at(picked) - grid.height_at(cell) >= 2)
				assert_true(hidden_ok, "turn %d: %s picked %s, hidden by a one-level step?" % [turn, cell, picked])
		stage.rig.rotate_steps(1, false)


func test_overhead_view_picks_every_cell_center() -> void:
	var stage := Stage.new(false)
	stage.rig.set_overhead(true, false)
	await stage.ready_for_picking()
	assert_eq(_mispicks(stage), [] as Array[String])


func test_clicking_a_unit_body_picks_its_cell() -> void:
	var stage := Stage.new(true)
	await stage.ready_for_picking()
	for unit in stage.state.units:
		var head := stage.cell_top(unit.cell) + Vector3.UP * 0.9
		assert_eq(stage.pick_at(head), unit.cell, "%s's head" % unit.data.display_name)


func test_dead_units_cannot_be_clicked() -> void:
	var stage := Stage.new(true)
	var knight := stage.state.units[0]
	var head := stage.cell_top(knight.cell) + Vector3.UP * 0.9
	Engine.time_scale = 20.0
	await stage.units.view(0).play_death()
	await stage.ready_for_picking()
	assert_eq(stage.units.view(0).picked_cell(), BoardView.NO_CELL)
	assert_ne(stage.pick_at(head), knight.cell, "the click goes through to the board")


func test_unit_pick_collider_follows_its_moves() -> void:
	var stage := Stage.new(true)
	var knight := stage.state.units[0]
	Engine.time_scale = 20.0
	await stage.units.view(0).play_move([knight.cell + Vector2i.UP] as Array[Vector2i])
	assert_eq(stage.units.view(0).picked_cell(), knight.cell + Vector2i.UP)
