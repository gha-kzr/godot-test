extends TestCase

const BATTLE_SCENE := preload("res://scenes/battle/battle.tscn")


func _tree() -> SceneTree:
	return Engine.get_main_loop() as SceneTree


## Regression for a playtest report: the second of two quick casts must show its effects too.
func test_two_quick_casts_each_show_their_effects() -> void:
	Engine.time_scale = 10.0
	var fire := load("res://data/damage_types/fire.tres") as DamageType
	var caster := BattleFixtures.unit("P0", 200, 3, 10, 40)
	var bolt := BattleFixtures.damage_spell(2, 1, 3, 3)
	(bolt.effects[0] as DamageEffect).damage_type = fire
	caster.spells = [bolt] as Array[SpellData]
	caster.model_scene = load("res://assets/models/knight.tscn")
	caster.model_scale = 1.0
	var target := BattleFixtures.unit("E0", 100, 3, 6, 80)
	target.model_scene = load("res://assets/models/orc_guard.tscn")
	target.model_scale = 1.0
	var controller := BATTLE_SCENE.instantiate() as BattleController
	controller.rng_seed = 7
	controller.encounter = BattleFixtures.encounter("0p 0 0e 0", [target])
	controller.players = [caster] as Array[UnitData]
	_tree().root.add_child(controller)
	controller.end_turn()
	for i in 600:
		if controller.input_state == BattleController.State.IDLE:
			break
		await _tree().process_frame
	var seen := []
	controller.event_player.event_played.connect(func(event: BattleEvents.Event) -> void:
		if event is BattleEvents.SpellCast:
			var hero := controller.units_view.view(0)
			seen.append(["cast", (hero.model().find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer).current_animation])
		elif event is BattleEvents.DamageDealt:
			var victim := controller.units_view.view(1)
			seen.append(["hit", victim.get_children().filter(func(c: Node) -> bool: return c is Fx).size(),
					(victim.model().find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer).current_animation]))
	# Cast, then cast again as soon as the controller allows it.
	controller.select_spell(0)
	controller.click_cell(Vector2i(2, 0))
	for i in 600:
		if controller.input_state == BattleController.State.IDLE and seen.size() >= 2:
			break
		await _tree().process_frame
	controller.select_spell(0)
	controller.click_cell(Vector2i(2, 0))
	for i in 600:
		if controller.input_state == BattleController.State.IDLE and seen.size() >= 4:
			break
		await _tree().process_frame
	assert_true(seen.size() >= 4, "two casts happened: %s" % [seen])
	assert_eq([seen[1][1], seen[3][1]], [1, 1], "a fire effect on the target of each cast: %s" % [seen])
