extends TestCase


func _map(layout: String) -> MapData:
	var map := MapData.new()
	map.display_name = "test"
	map.layout = layout
	return map


func test_parses_size_heights_and_types() -> void:
	var result := _map("0p 1  2\n#  .  3e").parse()
	assert_true(result.errors.is_empty(), str(result.errors))
	var grid := result.grid
	assert_eq(grid.size, Vector2i(3, 2), "size")
	assert_eq(grid.height_at(Vector2i(1, 0)), 1, "height")
	assert_eq(grid.height_at(Vector2i(2, 1)), 3, "height with spawn suffix")
	assert_eq(grid.type_at(Vector2i(0, 1)), Grid.CellType.OBSTACLE, "obstacle")
	assert_eq(grid.type_at(Vector2i(1, 1)), Grid.CellType.HOLE, "hole")
	assert_eq(grid.type_at(Vector2i(0, 0)), Grid.CellType.FLOOR, "floor")


func test_multi_digit_heights() -> void:
	var result := _map("12p 0e").parse()
	assert_eq(result.grid.height_at(Vector2i(0, 0)), 12)


func test_spawns_in_reading_order() -> void:
	var result := _map("0p 0e 0p\n0e 0  0p").parse()
	assert_eq(result.player_spawns, [Vector2i(0, 0), Vector2i(2, 0), Vector2i(2, 1)] as Array[Vector2i], "player")
	assert_eq(result.enemy_spawns, [Vector2i(1, 0), Vector2i(0, 1)] as Array[Vector2i], "enemy")


func test_tolerates_blank_lines_tabs_and_extra_spaces() -> void:
	var result := _map("\n  0p\t0\n\n0   0e  \n").parse()
	assert_true(result.errors.is_empty(), str(result.errors))
	assert_eq(result.grid.size, Vector2i(2, 2))


func test_tolerates_windows_line_endings() -> void:
	var result := _map("0p 0\r\n0 0e\r\n").parse()
	assert_true(result.errors.is_empty(), str(result.errors))
	assert_eq(result.grid.size, Vector2i(2, 2))


func test_validation_errors_match_parse_errors() -> void:
	assert_eq(_map("0p 0").get_validation_errors().size(), 1, "missing enemy spawn")
	assert_eq(_map("0p 0e").get_validation_errors().size(), 0)


func test_rejects_ragged_rows() -> void:
	var result := _map("0p 0 0\n0e 0").parse()
	assert_null_grid_with_error(result, "row 2 has 2 cells")


func test_rejects_invalid_tokens() -> void:
	assert_null_grid_with_error(_map("0p x\n0e 0").parse(), "invalid cell 'x'")
	assert_null_grid_with_error(_map("0p -1\n0e 0").parse(), "invalid cell '-1'")
	assert_null_grid_with_error(_map("0p 2q\n0e 0").parse(), "invalid cell '2q'")


func test_rejects_empty_layout() -> void:
	assert_null_grid_with_error(_map(" \n ").parse(), "layout is empty")


func test_requires_a_spawn_per_team() -> void:
	assert_null_grid_with_error(_map("0p 0").parse(), "no enemy spawn")
	assert_null_grid_with_error(_map("0 0e").parse(), "no player spawn")


func test_grid_neighbors_stay_in_bounds() -> void:
	var grid := _map("0p 0\n0 0e").parse().grid
	assert_eq(grid.neighbors(Vector2i(0, 0)).size(), 2, "corner")
	assert_true(Vector2i(1, 0) in grid.neighbors(Vector2i(0, 0)))
	assert_true(Vector2i(0, 1) in grid.neighbors(Vector2i(0, 0)))


func test_grid_walkability() -> void:
	var grid := _map("0p # .\n0 0 0e").parse().grid
	assert_true(grid.is_walkable(Vector2i(0, 0)), "floor")
	assert_false(grid.is_walkable(Vector2i(1, 0)), "obstacle")
	assert_false(grid.is_walkable(Vector2i(2, 0)), "hole")
	assert_false(grid.is_walkable(Vector2i(5, 5)), "out of bounds")


func assert_null_grid_with_error(result: MapData.ParseResult, expected_fragment: String) -> void:
	assert_true(result.grid == null, "no grid when invalid")
	assert_true(Array(result.errors).any(func(e: String) -> bool: return expected_fragment in e),
			"errors %s should mention '%s'" % [result.errors, expected_fragment])
