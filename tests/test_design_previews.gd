extends TestCase
## The editor previews' maths (the Inspector panels only draw these).


func test_spell_grid_shows_range_and_area_around_the_caster() -> void:
	var fireball := load("res://data/spells/fireball.tres") as SpellData  # Range 3-5, circle 1.
	var grid := SpellPreview.grid(fireball)
	assert_eq(grid.size, 15, "reach 5 + area 1 + margin, both sides")
	assert_eq(grid.caster, Vector2i(7, 7))
	assert_false(grid.caster + Vector2i(2, 0) in grid.in_range, "under the minimum range")
	assert_true(grid.caster + Vector2i(3, 0) in grid.in_range)
	assert_true(grid.caster + Vector2i(3, 2) in grid.in_range, "Manhattan 5")
	assert_false(grid.caster + Vector2i(3, 3) in grid.in_range, "Manhattan 6")
	assert_eq(grid.target, grid.caster + Vector2i(5, 0))
	assert_eq(grid.area.size(), 5, "a circle of 1 around the target")


func test_expected_amounts_follow_power_scaling_and_resistance() -> void:
	var spell := BattleFixtures.damage_spell(3, 1, 1, 10)
	spell.effects[0].damage_type = load("res://data/damage_types/fire.tres")
	assert_eq(SpellPreview.expected_amount(spell, 0, 0), 10.0)
	assert_eq(SpellPreview.expected_amount(spell, 50, 0), 15.0)
	assert_eq(SpellPreview.expected_amount(spell, 50, 20), 12.0)
	assert_eq(SpellPreview.expected_amount(spell, 0, 90), 5.0, "resistance capped at 50%")
	spell.effects[0].power_scaling = 0
	assert_eq(SpellPreview.expected_amount(spell, 50, 0), 10.0)
	var mend := load("res://data/spells/mend.tres") as SpellData
	assert_true(SpellPreview.expected_amount(mend, 0, 0) < 0.0, "heals are negative")


func test_spell_summary_lines() -> void:
	var lines := SpellPreview.summary(load("res://data/spells/poison_arrow.tres") as SpellData)
	var text := "\n".join(lines)
	assert_true(text.begins_with("Poison Arrow — 3 AP, range 2-6, line of sight"), text)
	assert_true(text.contains("Per AP: 0.8 damage"), text)
	assert_true(text.contains("Status: Poison for 3 turns (2 poison damage per turn), 6.0 damage in total"), text)


func test_enemy_rows_cover_levels_and_presets() -> void:
	var brute := load("res://data/enemies/brute.tres") as EnemyData
	var rows := EnemyPreview.rows(brute)
	assert_eq(rows.size(), EnemyPreview.LEVELS.size() * 3, "levels x normal / elite / boss")
	var first := rows[0]
	assert_eq([first.preset_name, first.level, first.hp, first.power, first.xp], ["Normal", 1, 42, 0, 15])
	assert_eq(first.resistances, "Physical +20%")
	var elite_5: EnemyPreview.Row = rows.filter(func(r: EnemyPreview.Row) -> bool: return r.preset_name == "Elite" and r.level == 5)[0]
	assert_eq([elite_5.hp, elite_5.power, elite_5.xp], [87, 28, 70], "(42 + 16) x 1.5; 8 + 20; (15 + 20) x 2")


func test_enemy_summary_lists_loot_odds() -> void:
	var text := "\n".join(EnemyPreview.summary(load("res://data/enemies/archer.tres") as EnemyData))
	assert_true(text.contains("Archer — +3 HP and +4 Power per level"), text)
	assert_true(text.contains("Rune of Focus"), text)
	assert_true(text.contains("per roll"), text)


func test_plugin_scripts_load() -> void:
	for path in ["res://addons/design_tools/plugin.gd", "res://addons/design_tools/design_inspector.gd",
			"res://addons/design_tools/previews/preview_panel.gd", "res://addons/design_tools/previews/area_grid_view.gd"]:
		var script := load(path) as GDScript
		assert_true(script != null and script.can_instantiate(), path)
		assert_true(script.is_tool(), "%s is @tool" % path)
