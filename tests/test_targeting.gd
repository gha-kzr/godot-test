extends TestCase
## Unit 0 (first player spawn) is the caster in each layout.


func _spell(min_range: int, max_range: int, needs_los := true, height_bonus := false) -> SpellData:
	var spell := SpellData.new()
	spell.display_name = "Test"
	spell.min_range = min_range
	spell.max_range = max_range
	spell.needs_line_of_sight = needs_los
	spell.height_extends_range = height_bonus
	spell.area = AreaShape.new()
	return spell


func _area(kind: AreaShape.Kind, size: int) -> AreaShape:
	var area := AreaShape.new()
	area.kind = kind
	area.size = size
	return area


func _los(layout: String, from: Vector2i, to: Vector2i) -> bool:
	return Targeting.has_line_of_sight(BattleFixtures.state(layout), from, to)


# --- Line of sight ---

func test_open_ground_is_visible() -> void:
	assert_true(_los("0p 0 0 0 0e", Vector2i(0, 0), Vector2i(4, 0)), "straight")
	assert_true(_los("0p 0 0 0\n0 0 0 0\n0 0 0 0e", Vector2i(0, 0), Vector2i(3, 2)), "slanted")


func test_obstacle_blocks_and_hole_does_not() -> void:
	assert_false(_los("0p # 0e", Vector2i(0, 0), Vector2i(2, 0)), "obstacle")
	assert_true(_los("0p . 0e", Vector2i(0, 0), Vector2i(2, 0)), "hole")


func test_units_block_but_not_the_ends() -> void:
	assert_false(_los("0p 0p 0e", Vector2i(0, 0), Vector2i(2, 0)), "ally in between")
	assert_true(_los("0p 0e 0", Vector2i(0, 0), Vector2i(1, 0)), "occupied target cell")


func test_slanted_line_only_checks_the_cells_it_crosses() -> void:
	# From (0,0) to (4,1) the line crosses (1,0), (2,0), then (2,1), (3,1).
	var from := Vector2i(0, 0)
	var to := Vector2i(4, 1)
	assert_true(_los("0p 0 0 # 0\n0 # 0 0 0e", from, to), "obstacles just beside the line")
	assert_false(_los("0p 0 # 0 0\n0 0 0 0 0e", from, to), "obstacle on (2,0)")
	assert_false(_los("0p 0 0 0 0\n0 0 # 0 0e", from, to), "obstacle on (2,1)")


func test_vertical_and_steep_lines() -> void:
	var layout := "0p 0\n0 0\n0 0\n0 0e"
	assert_true(_los(layout, Vector2i(0, 0), Vector2i(0, 3)), "vertical, open")
	assert_false(_los("0p 0\n# 0\n0 0\n0 0e", Vector2i(0, 0), Vector2i(0, 3)), "vertical, blocked")
	# (0,0) -> (1,7) crosses an exact corner between (0,3)/(1,4)'s neighbours at y=4.
	var tall := "0p 0\n0 0\n0 0\n0 0\n0 0\n0 0\n0 0\n0 0e"
	assert_true(_los(tall, Vector2i(0, 0), Vector2i(1, 7)), "steep, open")


func test_corner_with_a_unit_or_raised_cell_on_one_side() -> void:
	assert_true(_los("0p 0p 0\n0 0 0\n0 0 0e", Vector2i(0, 0), Vector2i(2, 2)), "unit on one side")
	assert_true(_los("0p 1 0\n0 0 0\n0 0 0e", Vector2i(0, 0), Vector2i(2, 2)), "raised cell on one side")
	assert_false(_los("0p 0p 0\n2 0 0\n0 0 0e", Vector2i(0, 0), Vector2i(2, 2)), "unit and raised cell")


func test_one_level_bump_does_not_hide_units_on_the_same_level() -> void:
	assert_true(_los("0p 0 1 0e", Vector2i(0, 0), Vector2i(3, 0)), "on level 0")
	assert_true(_los("1p 1 2 1e", Vector2i(0, 0), Vector2i(3, 0)), "on level 1")


func test_two_level_wall_blocks_on_flat_ground() -> void:
	assert_false(_los("0p 0 2 0e", Vector2i(0, 0), Vector2i(3, 0)))


func test_ledges_hide_units_right_below_them_only_when_two_levels_high() -> void:
	assert_true(_los("1p 1 1 0e", Vector2i(0, 0), Vector2i(3, 0)), "one level: seen over the edge")
	assert_false(_los("2p 2 2 0e", Vector2i(0, 0), Vector2i(3, 0)), "two levels: hidden under the ledge")


func test_high_ground_sees_over_a_low_wall() -> void:
	assert_true(_los("2p 0 1 0e", Vector2i(0, 0), Vector2i(3, 0)))
	assert_true(_los("2p 2 0 0e", Vector2i(0, 0), Vector2i(3, 0)), "a wall as tall as the caster, close to it")


func test_higher_wall_still_blocks_high_ground() -> void:
	assert_false(_los("2p 0 3 0e", Vector2i(0, 0), Vector2i(3, 0)))


func test_exact_corner_blocks_only_if_both_sides_block() -> void:
	# The diagonal from (0,0) to (2,2) passes exactly between (1,0) and (0,1).
	assert_true(_los("0p # 0\n0 0 0\n0 0 0e", Vector2i(0, 0), Vector2i(2, 2)), "one side open")
	assert_false(_los("0p # 0\n# 0 0\n0 0 0e", Vector2i(0, 0), Vector2i(2, 2)), "both sides blocked")


func test_line_of_sight_to_self() -> void:
	assert_true(_los("0p 0e", Vector2i(0, 0), Vector2i(0, 0)))


# --- Range ---

func test_min_and_max_range() -> void:
	var state := BattleFixtures.state("0p 0 0 0 0 0e")
	var spell := _spell(2, 4)
	assert_false(Targeting.can_target(state, 0, spell, Vector2i(1, 0)), "inside min range")
	assert_true(Targeting.can_target(state, 0, spell, Vector2i(2, 0)), "min range")
	assert_true(Targeting.can_target(state, 0, spell, Vector2i(4, 0)), "max range")
	assert_false(Targeting.can_target(state, 0, spell, Vector2i(5, 0)), "beyond max range")


func test_high_ground_extends_range_only_when_the_spell_allows_it() -> void:
	var state := BattleFixtures.state("2p 0 0 0 0 0e")
	assert_true(Targeting.can_target(state, 0, _spell(1, 2, false, true), Vector2i(4, 0)), "2 + 2 levels")
	assert_false(Targeting.can_target(state, 0, _spell(1, 2, false, true), Vector2i(5, 0)), "one too far")
	assert_false(Targeting.can_target(state, 0, _spell(1, 2, false, false), Vector2i(3, 0)), "no bonus without the flag")


func test_range_bonus_is_capped() -> void:
	var state := BattleFixtures.state("3p 0 0e")
	assert_eq(Targeting.range_bonus(state, _spell(1, 1, false, true), Vector2i(0, 0), Vector2i(1, 0)), 2)


func test_no_bonus_when_lower_than_the_target() -> void:
	var state := BattleFixtures.state("0p 2 0e")
	assert_eq(Targeting.range_bonus(state, _spell(1, 1, false, true), Vector2i(0, 0), Vector2i(1, 0)), 0)


func test_line_of_sight_requirement() -> void:
	var state := BattleFixtures.state("0p # 0 0e")
	assert_false(Targeting.can_target(state, 0, _spell(1, 3), Vector2i(2, 0)), "needs sight")
	assert_true(Targeting.can_target(state, 0, _spell(1, 3, false), Vector2i(2, 0)), "doesn't need sight")


func test_targetable_cells_include_empty_cells_but_not_obstacles_or_holes() -> void:
	var state := BattleFixtures.state("0p 0 #\n0 . 0e")
	var cells := Targeting.targetable_cells(state, 0, _spell(1, 2, false))
	assert_true(Vector2i(1, 0) in cells, "empty cell")
	assert_true(Vector2i(0, 1) in cells, "adjacent")
	assert_false(Vector2i(2, 0) in cells, "obstacle")
	assert_false(Vector2i(1, 1) in cells, "hole")
	assert_false(Vector2i(0, 0) in cells, "own cell is inside min range")


# --- Areas ---

func test_area_shapes() -> void:
	var grid := BattleFixtures.state("0p 0 0 0 0\n0 0 0 0 0\n0 0 0 0 0\n0 0 0 0 0\n0 0 0 0 0e").grid
	var center := Vector2i(2, 2)
	var caster := Vector2i(0, 2)
	assert_eq(Targeting.area_cells(grid, _area(AreaShape.Kind.SINGLE, 0), caster, center), [center] as Array[Vector2i], "single")
	assert_eq(Targeting.area_cells(grid, _area(AreaShape.Kind.CROSS, 1), caster, center).size(), 5, "cross 1")
	assert_eq(Targeting.area_cells(grid, _area(AreaShape.Kind.CROSS, 2), caster, center).size(), 9, "cross 2")
	assert_eq(Targeting.area_cells(grid, _area(AreaShape.Kind.CIRCLE, 2), caster, center).size(), 13, "circle 2")
	assert_false(Vector2i(0, 0) in Targeting.area_cells(grid, _area(AreaShape.Kind.CIRCLE, 2), caster, center), "circle is a diamond")


func test_line_extends_away_from_the_caster() -> void:
	var grid := BattleFixtures.state("0p 0 0 0 0\n0 0 0 0 0e").grid
	var line := _area(AreaShape.Kind.LINE, 3)
	assert_eq(Targeting.area_cells(grid, line, Vector2i(0, 0), Vector2i(1, 0)),
			[Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0)] as Array[Vector2i], "3 cells to the right")
	assert_eq(Targeting.area_cells(grid, line, Vector2i(0, 0), Vector2i(3, 1)),
			[Vector2i(3, 1), Vector2i(4, 1)] as Array[Vector2i], "clipped at the edge")


func test_line_edge_cases() -> void:
	var grid := BattleFixtures.state("0p 0 0\n0 0 0\n0 0 0e").grid
	var line := _area(AreaShape.Kind.LINE, 3)
	assert_eq(Targeting.area_cells(grid, line, Vector2i(1, 1), Vector2i(1, 1)), [Vector2i(1, 1)] as Array[Vector2i], "aimed at the caster's cell")
	assert_eq(Targeting.area_cells(grid, line, Vector2i(0, 0), Vector2i(1, 1)),
			[Vector2i(1, 1), Vector2i(2, 1)] as Array[Vector2i], "diagonal tie goes along x")


func test_areas_are_clipped_to_the_grid() -> void:
	var grid := BattleFixtures.state("0p 0\n0 0e").grid
	var cells := Targeting.area_cells(grid, _area(AreaShape.Kind.CROSS, 1), Vector2i(1, 1), Vector2i(0, 0))
	assert_eq(cells.size(), 3, "corner keeps 3 of 5")


func test_blocked_cells_are_in_range_but_out_of_sight() -> void:
	var state := BattleFixtures.state("0p 0 # 0 0e")
	var spell := BattleFixtures.damage_spell(3, 1, 4, 5, AreaShape.Kind.SINGLE, 0, true)
	assert_eq(Targeting.targetable_cells(state, 0, spell), [Vector2i(1, 0)] as Array[Vector2i])
	assert_eq(Targeting.blocked_cells(state, 0, spell), [Vector2i(3, 0), Vector2i(4, 0)] as Array[Vector2i],
			"behind the obstacle; the obstacle itself is never a target")
	spell.needs_line_of_sight = false
	assert_eq(Targeting.blocked_cells(state, 0, spell), [] as Array[Vector2i], "no sight needed, nothing blocked")


# --- Obstacles block up to their top ---

func test_an_obstacle_is_a_two_level_cube_and_only_obstacles_have_height() -> void:
	var state := BattleFixtures.state("0p # . 0e")
	assert_eq(state.grid.obstacle_levels(Vector2i(1, 0)), Grid.OBSTACLE_LEVELS)
	assert_eq(Grid.OBSTACLE_LEVELS, 2, "a full cube: two half-cell levels")
	assert_eq(state.grid.obstacle_levels(Vector2i(0, 0)), 0, "a floor")
	assert_eq(state.grid.obstacle_levels(Vector2i(2, 0)), 0, "a hole")


func test_high_ground_sees_over_a_low_block_but_the_ground_does_not() -> void:
	assert_false(_los("0p # 0 0e", Vector2i(0, 0), Vector2i(3, 0)), "from the ground the block stops sight")
	assert_true(_los("2p # 0 0e", Vector2i(0, 0), Vector2i(3, 0)), "from two levels up sight clears its top")


func test_a_block_beside_the_target_hides_a_low_target_from_the_ground_only() -> void:
	assert_false(_los("0p 0 # 0e", Vector2i(0, 0), Vector2i(3, 0)), "ground to ground")
	assert_true(_los("3p 0 # 0e", Vector2i(0, 0), Vector2i(3, 0)), "from three levels up")


func test_can_target_follows_the_height_rule() -> void:
	var ground := BattleFixtures.state("0p # 0e")
	var high := BattleFixtures.state("2p # 0e")
	var spell := _spell(1, 4)
	assert_false(Targeting.can_target(ground, 0, spell, Vector2i(2, 0)), "blocked from the ground")
	assert_true(Targeting.can_target(high, 0, spell, Vector2i(2, 0)), "open from the high ground")


func test_a_block_on_a_plateau_rises_from_the_plateau() -> void:
	var state := BattleFixtures.state("2p 2# 0 0e")
	assert_eq(state.grid.height_at(Vector2i(1, 0)) + state.grid.obstacle_levels(Vector2i(1, 0)), 4, "top at 2 + 2")
	assert_false(_los("2p 2# 0 0e", Vector2i(0, 0), Vector2i(3, 0)), "a caster level with the plateau can't see over its block")
	assert_true(_los("5p 2# 0 0e", Vector2i(0, 0), Vector2i(3, 0)), "from well above the plateau it can")


func test_the_edge_of_the_world_is_opaque() -> void:
	var state := BattleFixtures.state("4p 0e")
	assert_true(Targeting._blocks(state, Vector2i(-1, 0), 99.0), "out of bounds blocks whatever the sight height")
