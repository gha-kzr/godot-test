extends TestCase
## The spell stage: the battle it sets up, its replay and its reload when a file changes.

const SCENE := preload("res://scenes/tools/spell_stage.tscn")
const COPY := "user://test_spell_stage/copy.tres"


func _tree() -> SceneTree:
	return Engine.get_main_loop() as SceneTree


func after_each_clean() -> void:
	DirAccess.remove_absolute(COPY)
	DirAccess.remove_absolute(COPY.get_base_dir())
	Engine.time_scale = 1.0


func _unit(unit_name: String) -> UnitData:
	return load("res://data/units/%s.tres" % unit_name) as UnitData


func test_the_stage_sets_up_a_caster_and_a_dummy_at_the_spells_range() -> void:
	var spell := load("res://data/spells/fireball.tres") as SpellData
	var state := SpellStage.build_state(spell, _unit("mage"), _unit("brute"))
	assert_true(state != null, "a battle")
	assert_eq(state.units.size(), 2)
	assert_eq(state.units[0].cell, SpellStage.CASTER_CELL)
	assert_eq(state.units[1].cell, SpellStage.target_cell(spell, false), "the dummy is where the cast aims")
	assert_eq(Targeting.distance(state.units[0].cell, state.units[1].cell), clampi(spell.max_range, 1, 6))
	assert_eq(state.units[0].data.spells, [spell] as Array[SpellData], "the spell is the caster's only one")
	assert_true(state.units[0].data.ap >= spell.ap_cost, "it can afford the spell")
	assert_eq(state.units[1].max_hp(), SpellStage.STAGE_HP, "the dummy doesn't fall over")
	assert_true(_unit("brute").max_hp != SpellStage.STAGE_HP, "the shared unit data is untouched")


func test_the_cast_goes_through_the_real_rules() -> void:
	for spell_name in ["fireball", "slash", "mend", "whirlwind", "volley"]:
		var spell := load("res://data/spells/%s.tres" % spell_name) as SpellData
		var self_cast := SpellStage.casts_on_self(spell)
		var state := SpellStage.build_state(spell, _unit("knight"), _unit("brute"), self_cast)
		var battle := Battle.new(state)
		battle.start()
		var result := battle.perform(BattleActions.CastSpell.new(0, 0, SpellStage.target_cell(spell, self_cast)))
		assert_true(result.ok(), "%s can be cast on the stage: %s" % [spell_name, result.error])
		assert_true(result.events.any(func(event: BattleEvents.Event) -> bool: return event is BattleEvents.SpellCast), spell_name)
		if spell_name != "mend":
			assert_true(result.events.any(func(event: BattleEvents.Event) -> bool: return event is BattleEvents.DamageDealt and event.unit_id == 1),
					"%s reaches the dummy" % spell_name)


func test_heals_and_buffs_are_cast_on_the_caster_and_attacks_on_the_dummy() -> void:
	assert_true(SpellStage.casts_on_self(load("res://data/spells/mend.tres")), "mend")
	assert_false(SpellStage.casts_on_self(load("res://data/spells/fireball.tres")), "fireball")
	assert_false(SpellStage.casts_on_self(load("res://data/spells/slash.tres")), "slash")
	assert_true(SpellStage.casts_on_self(load("res://data/spells/whirlwind.tres")), "whirlwind: it only targets its own cell")


func test_the_stage_plays_a_spell_and_loops_it() -> void:
	Engine.time_scale = 10.0
	var stage := SCENE.instantiate() as SpellStage
	stage.spell_path = "res://data/spells/fireball.tres"
	_tree().root.add_child(stage)
	for i in 900:
		if stage.play_count >= 2:
			break
		await _tree().process_frame
	assert_true(stage.play_count >= 2, "it played, then looped: %d" % stage.play_count)
	assert_true(stage.last_duration > 0.3, "the cast took game time: %f" % stage.last_duration)
	stage.free()


func test_the_stage_reloads_a_spell_whose_file_changed() -> void:
	Engine.time_scale = 10.0
	DirAccess.make_dir_recursive_absolute(COPY.get_base_dir())
	var original := load("res://data/spells/firebolt.tres") as SpellData
	var spell := original.duplicate() as SpellData
	spell.impact_delay = 0.0
	assert_eq(ResourceSaver.save(spell, COPY), OK)
	var stage := SCENE.instantiate() as SpellStage
	_tree().root.add_child(stage)
	stage.spell_path = COPY
	stage.reload()
	assert_eq(stage.spell.impact_delay, 0.0, "loaded from the file")
	stage.loop = false
	spell.impact_delay = 0.9
	await _tree().create_timer(1.1 / Engine.time_scale).timeout  # The file's time stamp moves on by a second.
	assert_eq(ResourceSaver.save(spell, COPY), OK)
	for i in 600:
		if is_equal_approx(stage.spell.impact_delay, 0.9):
			break
		await _tree().process_frame
	assert_eq(stage.spell.impact_delay, 0.9, "the saved change was picked up by itself")
	stage.free()


func test_a_teleport_lands_on_the_free_cell_next_to_the_dummy() -> void:
	var blink := load("res://data/spells/blink.tres") as SpellData
	var state := SpellStage.build_state(blink, load("res://data/units/mage.tres"), load("res://data/units/brute.tres"))
	var battle := Battle.new(state)
	battle.start()
	var result := battle.perform(BattleActions.CastSpell.new(0, 0, SpellStage.target_cell(blink, false)))
	assert_true(result.ok(), result.error)
	assert_eq(state.units[0].cell, SpellStage.target_cell(blink, false))
