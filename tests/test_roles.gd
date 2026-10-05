extends TestCase
## Enemy roles: data, battle units and the unit card's tag.

const HUD_SCENE := preload("res://scenes/battle/hud.tscn")


func test_the_shipped_enemies_have_roles() -> void:
	var expected := {"brute": EnemyData.Role.BRUISER, "ghoul": EnemyData.Role.BRUISER,
			"skeleton_archer": EnemyData.Role.RANGED, "ghost": EnemyData.Role.SKIRMISHER}
	for enemy_name: String in expected:
		var enemy := load("res://data/enemies/%s.tres" % enemy_name) as EnemyData
		assert_eq(enemy.role, expected[enemy_name], enemy_name)
	for file in ResourceLoader.list_directory("res://data/enemies"):
		var enemy := load("res://data/enemies/" + file) as EnemyData
		assert_ne(enemy.role, EnemyData.Role.NONE, "%s has a role" % file)


func test_the_role_reaches_the_battle_unit_and_its_card() -> void:
	var brute := (load("res://data/enemies/brute.tres") as EnemyData).build(3)
	assert_eq(brute.role, EnemyData.Role.BRUISER)
	var map := MapData.new()
	map.layout = "0p 0e"
	var state := BattleState.create(map.parse(), [BattleFixtures.unit("Hero", 200)] as Array[UnitData], [brute.unit] as Array[UnitData], 1, [], [brute])
	assert_eq(state.units[1].role, EnemyData.Role.BRUISER)
	assert_eq(state.units[0].role, EnemyData.Role.NONE, "heroes have none")
	assert_eq(state.clone().units[1].role, EnemyData.Role.BRUISER, "clones keep it")
	var hud := HUD_SCENE.instantiate() as Hud
	(Engine.get_main_loop() as SceneTree).root.add_child(hud)
	hud.show_inspected(UnitInfo.from_unit(state.units[1]))
	var tag := hud.get_node("%InspectCard").find_child("RoleLabel", true, false) as Label
	assert_true(tag.visible)
	assert_eq(tag.text, "Role: Bruiser")
	assert_true(tag.tooltip_text.contains("up close"), tag.tooltip_text)
	hud.show_inspected(UnitInfo.from_unit(state.units[0]))
	assert_false(tag.visible, "no tag on a hero")
	hud.free()


func test_the_new_enemies_follow_the_movement_limits() -> void:
	# Enemy movement spells stay weaker than the heroes': no teleport or jump, charges of 3 at
	# most, pushes and pulls of 2 at most, a cooldown of 2 or more.
	for file in ResourceLoader.list_directory("res://data/enemies"):
		var enemy := load("res://data/enemies/" + file) as EnemyData
		var spells := enemy.unit.spells.duplicate()
		spells.append_array(enemy.boss_spells)
		for spell: SpellData in spells:
			for effect in spell.effects:
				if effect is not MoveEffect:
					continue
				var move := effect as MoveEffect
				var label := "%s: %s" % [file, spell.display_name]
				assert_false(move.kind in [MoveEffect.Kind.TELEPORT, MoveEffect.Kind.JUMP], "%s: no teleport or jump" % label)
				if move.kind == MoveEffect.Kind.CHARGE:
					assert_true(spell.max_range <= 3, "%s: a short charge" % label)
				else:
					assert_true(move.distance <= 2, "%s: 2 cells at most" % label)
				assert_true(spell.cooldown >= 2, "%s: a cooldown of 2 or more" % label)


## A hero (unit 0) and the given enemies (built at level 3) on `layout`, at `unit_id`'s turn.
func _state(layout: String, enemies: Array, unit_id: int) -> BattleState:
	var builds: Array = []
	var units: Array[UnitData] = []
	for enemy_name: String in enemies:
		var build := (load("res://data/enemies/%s.tres" % enemy_name) as EnemyData).build(3)
		builds.append(build)
		units.append(build.unit)
	var map := MapData.new()
	map.layout = layout
	var state := BattleState.create(map.parse(), [BattleFixtures.unit("Hero", 50, 3, 6, 80)] as Array[UnitData], units, 1, [], builds)
	var battle := Battle.new(state)
	battle.start()
	while state.turn_order.current_unit_id() != unit_id:
		battle.perform(BattleActions.EndTurn.new(state.turn_order.current_unit_id()))
	return state


## The first spell the unit casts this turn (its moves played on the way), or "".
func _cast_name(state: BattleState, unit_id: int) -> String:
	var battle := Battle.new(state)
	for step in 4:
		var action := EnemyAI.choose_next(state, unit_id, state.units[unit_id].ai_profile)
		if action is BattleActions.CastSpell:
			return state.units[unit_id].data.spells[(action as BattleActions.CastSpell).spell_index].display_name
		if action is BattleActions.EndTurn:
			return ""
		battle.perform(action)
	return ""


func test_the_warg_pounces_on_a_hero_in_line() -> void:
	assert_eq(_cast_name(_state("0p 0 0 0e 0 0 0", ["warg"], 1), 1), "Pounce")


func test_the_yeti_grabs_a_hero_it_cannot_walk_to() -> void:
	# The hero stands across a hole: in Icy Grasp's range, not on foot.
	assert_eq(_cast_name(_state("0p . . 0e\n# # # 0", ["yeti"], 1), 1), "Icy Grasp")


func test_the_mushroom_sage_heals_a_hurt_ally() -> void:
	var state := _state("0p 0 0 0 0 0e 0e", ["orc_guard", "mushroom_sage"], 2)
	state.units[1].hp -= 25
	assert_eq(_cast_name(state, 2), "Spore Mend")
