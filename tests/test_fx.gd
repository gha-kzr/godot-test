extends TestCase
## Hit, heal and cast effects: data-driven scenes chosen from the event stream.

const FIRE := preload("res://data/damage_types/fire.tres")
const FX := preload("res://data/fx/battle_fx.tres")


func _scene(tag: String) -> PackedScene:
	var root := Node3D.new()
	root.name = tag
	var scene := PackedScene.new()
	scene.pack(root)
	root.free()
	return scene


func test_a_damage_event_carries_its_type() -> void:
	var state := BattleFixtures.state("0p 0e")
	var fire := DamageEffect.new()
	fire.damage_type = FIRE
	fire.min_amount = 3
	fire.max_amount = 3
	var event := fire.apply(state, 0, 1)[0] as BattleEvents.DamageDealt
	assert_eq(event.damage_type, FIRE)
	var plain := DamageEffect.new()
	assert_true((plain.apply(state, 0, 1)[0] as BattleEvents.DamageDealt).damage_type == null, "untyped damage has no type")


func test_the_spells_effect_beats_the_damage_types_which_beats_the_default() -> void:
	var fx := BattleFx.new()
	var generic := _scene("Generic")
	var typed := _scene("Typed")
	var special := _scene("Special")
	fx.default_impact = generic
	var type := DamageType.new()
	var spell := SpellData.new()
	assert_eq(fx.impact_for(null, null), generic, "nothing set: the default")
	assert_eq(fx.impact_for(type, spell), generic, "a type without an effect: the default")
	type.impact_effect = typed
	assert_eq(fx.impact_for(type, spell), typed, "the damage type's own")
	spell.impact_effect = special
	assert_eq(fx.impact_for(type, spell), special, "a spell overrides both")
	assert_eq(fx.impact_for(null, spell), special)


func test_the_shipped_damage_types_and_heal_have_effects() -> void:
	for type_name in ["physical", "fire", "poison"]:
		var type := load("res://data/damage_types/%s.tres" % type_name) as DamageType
		assert_true(type.impact_effect != null, "%s has an impact effect" % type_name)
		var effect := type.impact_effect.instantiate()
		assert_true(effect is Fx and not effect.find_children("*", "CPUParticles3D", true, false).is_empty(), "%s is a particle burst" % type_name)
		effect.free()
	assert_true(FX.default_impact != null and FX.heal != null)


func test_an_effect_starts_its_particles_and_frees_itself() -> void:
	Engine.time_scale = 20.0
	var effect := FIRE.impact_effect.instantiate() as Fx
	var particles := effect.find_children("*", "CPUParticles3D", true, false)[0] as CPUParticles3D
	assert_false(particles.emitting, "waiting to be placed")
	(Engine.get_main_loop() as SceneTree).root.add_child(effect)
	assert_true(particles.emitting, "bursting once placed")
	assert_true(particles.one_shot)
	var ref: WeakRef = weakref(effect)
	for i in 600:
		if ref.get_ref() == null:
			break
		await (Engine.get_main_loop() as SceneTree).process_frame
	assert_true(ref.get_ref() == null, "gone after its duration")


func _fx_children(view: UnitView) -> int:
	return view.get_children().filter(func(c: Node) -> bool: return c is Fx).size()


func _stage() -> Dictionary:
	var state := BattleFixtures.state("0p 0e")
	var battle := Battle.new(state)
	battle.start()
	var root := Node3D.new()
	var board := BoardView.new()
	var units := UnitsView.new()
	var player := EventPlayer.new()
	root.add_child(board)
	root.add_child(units)
	root.add_child(player)
	(Engine.get_main_loop() as SceneTree).root.add_child(root)
	board.build(state.grid)
	units.build(state, board)
	player.setup(units, board)
	player.fx = FX
	return {"root": root, "units": units, "player": player}


func test_a_spawned_effect_sits_at_the_units_chest_and_scales_with_it() -> void:
	var stage := _stage()
	var view := (stage.units as UnitsView).view(1)
	view.spawn_fx(FIRE.impact_effect)
	var effect := view.get_children().filter(func(c: Node) -> bool: return c is Fx)[0] as Node3D
	assert_true(is_equal_approx(effect.position.y, UnitView.PLACEHOLDER_HEIGHT * 0.6), "chest height")
	view.spawn_fx(null)  # Nothing happens, no error.
	assert_eq(_fx_children(view), 1)
	(stage.root as Node).free()


func test_events_spawn_the_matching_effects_on_their_target() -> void:
	Engine.time_scale = 20.0
	var stage := _stage()
	var units := stage.units as UnitsView
	var hit := BattleEvents.DamageDealt.new(1, 4, 16, FIRE)
	await (stage.player as EventPlayer).play([hit] as Array[BattleEvents.Event])
	assert_eq(_fx_children(units.view(1)), 1, "a fire hit shows an effect on its target")
	assert_eq(_fx_children(units.view(0)), 0, "and not elsewhere")
	var heal := BattleEvents.Healed.new(0, 3, 20)
	await (stage.player as EventPlayer).play([heal] as Array[BattleEvents.Event])
	assert_eq(_fx_children(units.view(0)), 1, "a heal shows its effect")
	(stage.root as Node).free()


func test_a_fully_resisted_hit_and_a_heal_at_full_hp_still_show_their_effects() -> void:
	Engine.time_scale = 20.0
	var stage := _stage()
	var units := stage.units as UnitsView
	await (stage.player as EventPlayer).play([BattleEvents.DamageDealt.new(1, 0, 20, FIRE)] as Array[BattleEvents.Event])
	assert_eq(_fx_children(units.view(1)), 1, "the spell landed, even if it did nothing")
	await (stage.player as EventPlayer).play([BattleEvents.Healed.new(0, 0, 20)] as Array[BattleEvents.Event])
	assert_eq(_fx_children(units.view(0)), 1, "a heal on a unit at full HP still shows")
	(stage.root as Node).free()


func test_without_an_fx_resource_nothing_is_spawned_and_nothing_fails() -> void:
	Engine.time_scale = 20.0
	var stage := _stage()
	var units := stage.units as UnitsView
	(stage.player as EventPlayer).fx = null
	var cast := BattleEvents.SpellCast.new(0, BattleFixtures.damage_spell(), Vector2i(1, 0), [Vector2i(1, 0)] as Array[Vector2i], 3)
	await (stage.player as EventPlayer).play([cast, BattleEvents.DamageDealt.new(1, 4, 16, FIRE)] as Array[BattleEvents.Event])
	assert_eq(_fx_children(units.view(1)), 0)
	assert_eq((stage.root as Node).find_children("*", "Fx", true, false).size(), 0, "and no ground effect")
	(stage.root as Node).free()


func _ground_fx(stage: Dictionary) -> Array[Node]:
	var board := ((stage.root as Node).get_child(0)) as BoardView
	return board.get_children().filter(func(c: Node) -> bool: return c is Fx)


func test_casting_at_an_empty_cell_shows_a_ground_effect_there_only() -> void:
	Engine.time_scale = 20.0
	var stage := _stage()  # "0p 0e": the hero at (0, 0), the enemy at (1, 0).
	var spell := BattleFixtures.damage_spell()
	(spell.effects[0] as DamageEffect).damage_type = FIRE
	var empty := BattleEvents.SpellCast.new(0, spell, Vector2i(0, 0), [Vector2i(0, 0), Vector2i(1, 0)] as Array[Vector2i], 3)
	await (stage.player as EventPlayer).play([empty] as Array[BattleEvents.Event])
	assert_eq(_ground_fx(stage).size(), 0, "both cells of the area hold a unit: each gets its own effect from its events")
	var board := (stage.root as Node).get_child(0) as BoardView
	var ground := BattleEvents.SpellCast.new(0, spell, Vector2i(5, 0), [Vector2i(5, 0)] as Array[Vector2i], 3)
	# (5, 0) is outside this 2-cell map: use a map with free cells instead.
	(stage.root as Node).free()
	var wide := _wide_stage()
	var cast := BattleEvents.SpellCast.new(0, spell, Vector2i(2, 0), [Vector2i(2, 0), Vector2i(3, 0)] as Array[Vector2i], 3)
	await (wide.player as EventPlayer).play([cast] as Array[BattleEvents.Event])
	var effects := _ground_fx(wide)
	assert_eq(effects.size(), 1, "the empty cell (2, 0) shows one; the enemy's cell (3, 0) is left to its own events")
	var expected := ((wide.root as Node).get_child(0) as BoardView).cell_to_world(Vector2i(2, 0)) + Vector3(0.0, EventPlayer.GROUND_FX_HEIGHT, 0.0)
	assert_true((effects[0] as Node3D).position.is_equal_approx(expected), "at that cell")
	(wide.root as Node).free()


func _wide_stage() -> Dictionary:
	var state := BattleFixtures.state("0p 0 0 0e")
	var battle := Battle.new(state)
	battle.start()
	var root := Node3D.new()
	var board := BoardView.new()
	var units := UnitsView.new()
	var player := EventPlayer.new()
	root.add_child(board)
	root.add_child(units)
	root.add_child(player)
	(Engine.get_main_loop() as SceneTree).root.add_child(root)
	board.build(state.grid)
	units.build(state, board)
	player.setup(units, board)
	player.fx = FX
	return {"root": root, "units": units, "player": player}


func test_the_ground_effect_follows_the_spell_kind() -> void:
	var generic := _scene("Generic")
	var heal := _scene("Heal")
	var fire_fx := _scene("FireFx")
	var fx := BattleFx.new()
	fx.default_impact = generic
	fx.heal = heal
	var fire := DamageType.new()
	fire.impact_effect = fire_fx
	var damage := DamageEffect.new()
	var typed := DamageEffect.new()
	typed.damage_type = fire
	var mend := HealEffect.new()
	var spell := SpellData.new()
	spell.effects = [damage] as Array[EffectData]
	assert_eq(fx.cell_effect_for(spell), generic, "untyped damage: the default")
	spell.effects = [typed] as Array[EffectData]
	assert_eq(fx.cell_effect_for(spell), fire_fx, "typed damage: its effect")
	spell.effects = [mend] as Array[EffectData]
	assert_eq(fx.cell_effect_for(spell), heal, "a heal: the heal effect")
	spell.effects = [] as Array[EffectData]
	assert_eq(fx.cell_effect_for(spell), generic, "anything else: the default")
	spell.impact_effect = _scene("Own")
	assert_eq(fx.cell_effect_for(spell), spell.impact_effect, "a spell's own wins")


func test_a_status_shows_a_burst_tinted_with_its_color() -> void:
	Engine.time_scale = 20.0
	var stage := _stage()
	var units := stage.units as UnitsView
	var status := BattleFixtures.status("Poison", 2, 1)
	status.color = Color(0.3, 0.9, 0.2)
	await (stage.player as EventPlayer).play([BattleEvents.StatusApplied.new(1, status, 2)] as Array[BattleEvents.Event])
	var effects := units.view(1).get_children().filter(func(c: Node) -> bool: return c is Fx)
	assert_eq(effects.size(), 1)
	var particles := (effects[0] as Node).find_children("*", "CPUParticles3D", true, false)[0] as CPUParticles3D
	assert_eq(particles.color, status.color, "tinted with the status's color")
	(stage.root as Node).free()
func test_a_spells_own_effects_win_and_end_with_the_turn() -> void:
	Engine.time_scale = 20.0
	var stage := _stage()
	var units := stage.units as UnitsView
	var spell := BattleFixtures.damage_spell()
	var cast_scene := _scene("CastFx")
	var impact_scene := _scene("ImpactFx")
	spell.cast_effect = cast_scene
	spell.impact_effect = impact_scene
	var cast := BattleEvents.SpellCast.new(0, spell, Vector2i(1, 0), [Vector2i(1, 0)] as Array[Vector2i], 3)
	var hit := BattleEvents.DamageDealt.new(1, 4, 16, FIRE)
	# A status tick later in the same playback (after a turn event) uses the damage type's effect again.
	var turn := BattleEvents.TurnStarted.new(1, 2, 6, 3)
	var tick_hit := BattleEvents.DamageDealt.new(1, 2, 14, FIRE)
	await (stage.player as EventPlayer).play([cast, hit, turn, tick_hit] as Array[BattleEvents.Event])
	assert_eq(units.view(0).get_children().filter(func(c: Node) -> bool: return c.name == &"CastFx").size(), 1, "the cast effect on the caster")
	assert_eq(units.view(1).get_children().filter(func(c: Node) -> bool: return c.name == &"ImpactFx").size(), 1, "the spell's impact instead of fire's")
	assert_eq(_fx_children(units.view(1)), 1, "the tick after the turn event got fire's own effect: the spell no longer overrides")
	(stage.root as Node).free()


func test_every_shipped_effect_lives_as_long_as_its_particles() -> void:
	for file in DirAccess.get_files_at("res://scenes/fx"):
		if not file.ends_with(".tscn"):
			continue
		var effect := (load("res://scenes/fx/%s" % file) as PackedScene).instantiate() as Fx
		for particles in effect.find_children("*", "CPUParticles3D", true, false):
			assert_true(effect.duration >= (particles as CPUParticles3D).lifetime, "%s: duration %f covers the particles' %f" % [file, effect.duration, (particles as CPUParticles3D).lifetime])
		effect.free()
