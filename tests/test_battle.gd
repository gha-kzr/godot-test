extends TestCase
## Default setup: P0 (acts first) and E0, both with one 3-AP melee spell dealing 5.

const Move := BattleActions.Move
const CastSpell := BattleActions.CastSpell
const EndTurn := BattleActions.EndTurn
const RecoilEffect := preload("res://tests/recoil_effect.gd")


func _fighter(unit_name: String, initiative: int, spells: Array[SpellData] = [], max_hp := 20) -> UnitData:
	var data := BattleFixtures.unit(unit_name, initiative, 3, 6, max_hp)
	data.spells = spells if not spells.is_empty() else ([BattleFixtures.damage_spell()] as Array[SpellData])
	return data


func _battle(layout := "0p 0 0 0e", players: Array[UnitData] = [], enemies: Array[UnitData] = []) -> Battle:
	if players.is_empty():
		players = [_fighter("P0", 200)]
	if enemies.is_empty():
		enemies = [_fighter("E0", 100)]
	var battle := Battle.new(BattleFixtures.state_with(layout, players, enemies))
	battle.start()
	return battle


func _types(events: Array[BattleEvents.Event]) -> Array[String]:
	var names: Array[String] = []
	for event in events:
		names.append(_event_name(event))
	return names


func _event_name(event: BattleEvents.Event) -> String:
	if event is BattleEvents.TurnStarted: return "TurnStarted"
	if event is BattleEvents.TurnEnded: return "TurnEnded"
	if event is BattleEvents.UnitMoved: return "UnitMoved"
	if event is BattleEvents.SpellCast: return "SpellCast"
	if event is BattleEvents.DamageDealt: return "DamageDealt"
	if event is BattleEvents.Healed: return "Healed"
	if event is BattleEvents.UnitDied: return "UnitDied"
	if event is BattleEvents.BattleEnded: return "BattleEnded"
	return "?"


# --- Turn flow ---

func test_start_begins_the_first_units_turn() -> void:
	var battle := Battle.new(BattleFixtures.state_with("0p 0e", [_fighter("P0", 200)], [_fighter("E0", 100)]))
	var events := battle.start()
	assert_eq(_types(events), ["TurnStarted"] as Array[String])
	assert_eq((events[0] as BattleEvents.TurnStarted).unit_id, 0)
	assert_eq((events[0] as BattleEvents.TurnStarted).round_number, 1)


func test_end_turn_passes_to_the_next_unit_and_refills_it() -> void:
	var battle := _battle()
	battle.state.units[1].ap = 0
	var result := battle.perform(EndTurn.new(0))
	assert_true(result.ok(), result.error)
	assert_eq(_types(result.events), ["TurnEnded", "TurnStarted"] as Array[String])
	assert_eq((result.events[1] as BattleEvents.TurnStarted).unit_id, 1)
	assert_eq(battle.state.units[1].ap, 6, "AP refilled")


func test_rounds_advance_after_everyone_acted() -> void:
	var battle := _battle()
	battle.perform(EndTurn.new(0))
	var result := battle.perform(EndTurn.new(1))
	assert_eq((result.events[1] as BattleEvents.TurnStarted).round_number, 2)


# --- Validation ---

func test_invalid_actions_are_rejected_without_changing_state() -> void:
	var battle := _battle("0p 0 0 0 0e")
	var cases := {
		"not your turn": EndTurn.new(1),
		"unknown unit": EndTurn.new(9),
		"unreachable": Move.new(0, Vector2i(4, 0)),
		"out of range": CastSpell.new(0, 0, Vector2i(4, 0)),
		"no such spell": CastSpell.new(0, 5, Vector2i(1, 0)),
	}
	for label in cases:
		var result := battle.perform(cases[label])
		assert_false(result.ok(), label)
		assert_true(result.events.is_empty(), "%s: no events" % label)
	var unit := battle.state.units[0]
	assert_eq([unit.cell, unit.ap, unit.mp, battle.state.units[1].hp], [Vector2i(0, 0), 6, 3, 20], "state untouched")


func test_not_enough_ap() -> void:
	var battle := _battle("0p 0e")
	battle.state.units[0].ap = 2
	var result := battle.perform(CastSpell.new(0, 0, Vector2i(1, 0)))
	assert_true("needs 3 AP" in result.error, result.error)


# --- Movement ---

func test_move_spends_mp_and_reports_the_path() -> void:
	var battle := _battle("0p 0 0 0 0e")
	var result := battle.perform(Move.new(0, Vector2i(2, 0)))
	assert_true(result.ok(), result.error)
	var moved := result.events[0] as BattleEvents.UnitMoved
	assert_eq(moved.path, [Vector2i(1, 0), Vector2i(2, 0)] as Array[Vector2i])
	assert_eq(moved.mp_spent, 2)
	assert_eq(battle.state.units[0].cell, Vector2i(2, 0))
	assert_eq(battle.state.units[0].mp, 1)
	assert_true(battle.perform(Move.new(0, Vector2i(0, 0))).ok(), "repositioning: back to the start, refunded")
	assert_eq(battle.state.units[0].mp, 3)


# --- Spells ---

func test_spell_spends_ap_and_damages() -> void:
	var battle := _battle("0p 0e")
	var result := battle.perform(CastSpell.new(0, 0, Vector2i(1, 0)))
	assert_true(result.ok(), result.error)
	assert_eq(_types(result.events), ["SpellCast", "DamageDealt"] as Array[String])
	assert_eq((result.events[1] as BattleEvents.DamageDealt).hp_after, 15)
	assert_eq(battle.state.units[0].ap, 3)
	assert_eq(battle.state.units[1].hp, 15)


func test_area_spell_hits_every_unit_in_it_allies_included() -> void:
	var blast := BattleFixtures.damage_spell(3, 1, 3, 5, AreaShape.Kind.CROSS, 1)
	var players: Array[UnitData] = [_fighter("P0", 200, [blast]), _fighter("P1", 150)]
	var enemies: Array[UnitData] = [_fighter("E0", 100), _fighter("E1", 90)]
	# Target (2,0): hits P1 at (1,0), E0 at (3,0), E1 at (2,1). P0 at (0,0) is outside.
	var battle := _battle("0p 0p 0 0e\n0 0 0e 0", players, enemies)
	battle.state.friendly_fire = true
	var result := battle.perform(CastSpell.new(0, 0, Vector2i(2, 0)))
	assert_true(result.ok(), result.error)
	var hit: Array[int] = []
	for event in result.events:
		if event is BattleEvents.DamageDealt:
			hit.append((event as BattleEvents.DamageDealt).unit_id)
	hit.sort()
	assert_eq(hit, [1, 2, 3] as Array[int])
	assert_eq(battle.state.units[0].hp, 20, "caster outside the area")


func test_heal_is_capped_at_max_hp() -> void:
	var heal := BattleFixtures.damage_spell(2, 0, 1)
	var effect := HealEffect.new()
	effect.min_amount = 10
	effect.max_amount = 10
	heal.effects = [effect] as Array[EffectData]
	var battle := _battle("0p 0e", [_fighter("P0", 200, [heal])])
	battle.state.units[0].hp = 16
	var result := battle.perform(CastSpell.new(0, 0, Vector2i(0, 0)))
	assert_true(result.ok(), result.error)
	assert_eq((result.events[1] as BattleEvents.Healed).amount, 4)
	assert_eq(battle.state.units[0].hp, 20)


func test_damage_rolls_are_seeded() -> void:
	var ranged := BattleFixtures.damage_spell(1, 1, 1)
	(ranged.effects[0] as DamageEffect).min_amount = 1
	(ranged.effects[0] as DamageEffect).max_amount = 100
	var rolls: Array = []
	for attempt in 2:
		var players: Array[UnitData] = [_fighter("P0", 200, [ranged])]
		var enemies: Array[UnitData] = [_fighter("E0", 100, [], 999)]
		var battle := Battle.new(BattleFixtures.state_with("0p 0e", players, enemies, 7))
		battle.start()
		var amounts: Array[int] = []
		for i in 3:
			amounts.append((battle.perform(CastSpell.new(0, 0, Vector2i(1, 0))).events[1] as BattleEvents.DamageDealt).amount)
		rolls.append(amounts)
	assert_eq(rolls[0], rolls[1], "same seed and actions, same rolls")
	assert_ne(rolls[0][0], rolls[0][1], "rolls vary (the RNG is really used)")


# --- Deaths and victory ---

func test_killing_the_last_enemy_ends_the_battle() -> void:
	var battle := _battle("0p 0e", [], [_fighter("E0", 100, [], 5)])
	var result := battle.perform(CastSpell.new(0, 0, Vector2i(1, 0)))
	assert_eq(_types(result.events), ["SpellCast", "DamageDealt", "UnitDied", "BattleEnded"] as Array[String])
	assert_eq((result.events[3] as BattleEvents.BattleEnded).outcome, BattleState.Outcome.PLAYER_WON)
	assert_true(battle.state.is_over())
	assert_true("battle is over" in battle.perform(EndTurn.new(0)).error)


func test_dead_units_leave_the_turn_order() -> void:
	var players: Array[UnitData] = [_fighter("P0", 200)]
	var enemies: Array[UnitData] = [_fighter("E0", 100, [], 5), _fighter("E1", 90)]
	var battle := _battle("0p 0e 0 0e", players, enemies)
	battle.perform(CastSpell.new(0, 0, Vector2i(1, 0)))
	assert_false(battle.state.is_over())
	var result := battle.perform(EndTurn.new(0))
	assert_eq((result.events[1] as BattleEvents.TurnStarted).unit_id, 2, "E0 skipped")


func test_caster_killed_by_its_own_spell_ends_its_turn() -> void:
	var nova := BattleFixtures.damage_spell(3, 0, 0, 50, AreaShape.Kind.CIRCLE, 1)
	var players: Array[UnitData] = [_fighter("P0", 200, [nova]), _fighter("P1", 150)]
	var enemies: Array[UnitData] = [_fighter("E0", 100)]
	var battle := _battle("0p 0 0p 0e", players, enemies)
	battle.state.friendly_fire = true
	var result := battle.perform(CastSpell.new(0, 0, Vector2i(0, 0)))
	assert_true(result.ok(), result.error)
	assert_eq(_types(result.events), ["SpellCast", "DamageDealt", "UnitDied", "TurnStarted"] as Array[String])
	assert_eq((result.events[3] as BattleEvents.TurnStarted).unit_id, 1, "P1's turn")


func test_mutual_wipe_is_a_draw() -> void:
	var nova := BattleFixtures.damage_spell(3, 0, 0, 50, AreaShape.Kind.CIRCLE, 1)
	var battle := _battle("0p 0e", [_fighter("P0", 200, [nova])])
	battle.state.friendly_fire = true
	var result := battle.perform(CastSpell.new(0, 0, Vector2i(0, 0)))
	assert_true(result.ok(), result.error)
	assert_eq(_types(result.events), ["SpellCast", "DamageDealt", "DamageDealt", "UnitDied", "UnitDied", "BattleEnded"] as Array[String])
	assert_eq((result.events[5] as BattleEvents.BattleEnded).outcome, BattleState.Outcome.DRAW)
	assert_true(battle.state.is_over())


func test_death_outside_the_area_is_detected() -> void:
	var backfire := BattleFixtures.damage_spell(3, 1, 1, 1)
	var recoil := RecoilEffect.new()
	recoil.amount = 50
	backfire.effects.append(recoil)
	var players: Array[UnitData] = [_fighter("P0", 200, [backfire]), _fighter("P1", 150)]
	var battle := _battle("0p 0e 0p", players)
	var result := battle.perform(CastSpell.new(0, 0, Vector2i(1, 0)))
	assert_true(result.ok(), result.error)
	assert_true("UnitDied" in _types(result.events), "caster death reported")
	assert_false(0 in battle.state.turn_order.upcoming(), "caster left the turn order")
	assert_eq(battle.state.current_unit().id, 1, "next unit plays")


func test_a_lethal_first_effect_skips_the_rest() -> void:
	var double := BattleFixtures.damage_spell(3, 1, 1, 50)
	double.effects.append(BattleFixtures.damage_spell().effects[0])
	var enemies: Array[UnitData] = [_fighter("E0", 100), _fighter("E1", 90)]
	var battle := _battle("0p 0e 0 0e", [_fighter("P0", 200, [double])], enemies)
	var result := battle.perform(CastSpell.new(0, 0, Vector2i(1, 0)))
	assert_eq(_types(result.events), ["SpellCast", "DamageDealt", "UnitDied"] as Array[String])


func test_start_is_guarded() -> void:
	var battle := _battle()
	battle.state.units[0].ap = 1
	expect_error("already started")
	assert_eq(battle.start().size(), 0)
	assert_eq(battle.state.units[0].ap, 1, "AP not refilled")


func test_dead_units_cannot_act() -> void:
	# A second player unit keeps the battle going.
	var battle := _battle("0p 0p 0e", [_fighter("P0", 200), _fighter("P1", 150)])
	battle.state.units[0].hp = 0
	assert_true("is dead" in battle.perform(EndTurn.new(0)).error)


# --- Simulation ---

func test_performing_on_a_clone_leaves_the_real_battle_untouched() -> void:
	var battle := _battle("0p 0e")
	var simulation := Battle.new(battle.state.clone())
	var action := CastSpell.new(0, 0, Vector2i(1, 0))
	assert_true(simulation.perform(action).ok())
	assert_eq(battle.state.units[1].hp, 20, "real battle untouched")
	assert_eq(battle.state.units[0].ap, 6)
	assert_true(battle.perform(action).ok(), "the same action object then applies to the real battle")
	assert_eq(battle.state.units[1].hp, 15)


func test_qa_set_hp_reports_damage_heal_deaths_and_the_next_turn() -> void:
	var battle := Battle.new(BattleFixtures.state_with("0p 0p 0e", [_fighter("P0", 200), _fighter("P1", 150)], [_fighter("E0", 100)]))
	battle.start()
	var hurt := battle.qa_set_hp(2, 5)
	assert_true(hurt[0] is BattleEvents.DamageDealt and (hurt[0] as BattleEvents.DamageDealt).amount == 15)
	var healed := battle.qa_set_hp(2, 99)
	assert_true(healed[0] is BattleEvents.Healed, "clamped to the max")
	assert_eq(battle.state.units[2].hp, 20)
	var killed := battle.qa_set_hp(0, 0)  # The acting hero falls: the next unit's turn starts.
	assert_true(killed[1] is BattleEvents.UnitDied)
	assert_true(killed.any(func(e: BattleEvents.Event) -> bool: return e is BattleEvents.TurnStarted))
	assert_eq(battle.state.current_unit().id, 1)
	var won := battle.qa_set_hp(2, 0)
	assert_true(won.back() is BattleEvents.BattleEnded)
	assert_true(battle.qa_set_hp(1, 0).is_empty(), "nothing once the battle is over")
