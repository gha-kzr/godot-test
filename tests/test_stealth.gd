extends TestCase
## Stealth (the Rogue's Vanish): a hidden unit can't be picked as a target by the other team, the AI doesn't aim at
## it, it shows again when someone stands next to it, attacks, or is hurt, and its first strike hits harder.
## Also the cleanse effect (the Priestess's Purify).

const STEALTH := "res://data/pvp/statuses/stealth.tres"


## A rogue (unit 0, side A) and a knight (unit 1, side B) on an open map, far apart; the rogue is hidden.
func _duel(hidden := true) -> BattleState:
	var map := PvpMap.generate(7, load("res://data/maps/typologies/open_field.tres") as MapTypology, 12)
	var side_a: Array[Dictionary] = [{"hero": 4, "name": "Rogue"}]
	var side_b: Array[Dictionary] = [{"hero": 0, "name": "Knight"}]
	var state := PvpBattle.create(map, side_a, side_b, 5)
	state.units[0].cell = Vector2i(2, 2)
	state.units[1].cell = Vector2i(8, 8)
	if hidden:
		state.units[0].add_status(load(STEALTH) as StatusData, 0)
	return state


func _knight_spell(name_text: String) -> int:
	var unit := PvpHeroes.build(0)["unit"] as UnitData
	for index in unit.spells.size():
		if unit.spells[index].display_name == name_text:
			return index
	return -1


func test_a_hidden_unit_is_hidden_from_the_other_team_only_and_not_when_someone_is_next_to_it() -> void:
	var state := _duel()
	assert_true(state.is_hidden_from(state.units[0], UnitState.Team.ENEMY))
	assert_false(state.is_hidden_from(state.units[0], UnitState.Team.PLAYER), "its own team sees it")
	state.units[1].cell = Vector2i(2, 3)
	assert_false(state.is_hidden_from(state.units[0], UnitState.Team.ENEMY), "an enemy standing next to it sees it")
	state.units[1].cell = Vector2i(2, 4)
	assert_true(state.is_hidden_from(state.units[0], UnitState.Team.ENEMY), "two cells away: still hidden")


func test_a_spell_that_needs_an_enemy_cannot_pick_a_hidden_one() -> void:
	var state := _duel()
	state.units[1].cell = Vector2i(2, 5)
	var picky := SpellData.new()
	picky.display_name = "Picky"
	picky.min_range = 1
	picky.max_range = 6
	picky.needs_line_of_sight = false
	picky.target_unit = SpellData.TargetUnit.ENEMY
	picky.area = AreaShape.new()
	var hit := DamageEffect.new()
	hit.min_amount = 1
	hit.max_amount = 1
	picky.effects.assign([hit])
	assert_false(Targeting.can_target(state, 1, picky, Vector2i(2, 2)), "hidden")
	state.units[0].break_stealth()
	assert_true(Targeting.can_target(state, 1, picky, Vector2i(2, 2)), "visible again")


func test_attacking_or_being_hurt_ends_stealth_but_vanishing_and_moving_do_not() -> void:
	var state := _duel()
	var battle := Battle.new(state)
	var rogue := state.units[0]
	var unit := PvpHeroes.build(4)["unit"] as UnitData
	var vanish := unit.spells[2]
	assert_false(vanish.is_offensive(), "vanishing is not an attack")
	assert_true(unit.spells[1].is_offensive(), "Ambush is")
	# Hurt by something: no longer hidden.
	var poke := DamageEffect.new()
	poke.min_amount = 5
	poke.max_amount = 5
	var events := poke.apply(state, 1, 0)
	assert_false(rogue.is_stealthed())
	assert_true(events.any(func(e: BattleEvents.Event) -> bool: return e is BattleEvents.StatusExpired), "the screen is told")
	# Attacks give the caster away.
	rogue.add_status(load(STEALTH) as StatusData, 0)
	state.units[1].cell = Vector2i(2, 3)
	battle.start()
	var current := state.current_unit()
	if current.id != 0:
		battle.perform(BattleActions.EndTurn.new(current.id))
	var result := battle.perform(BattleActions.CastSpell.new(0, 1, Vector2i(2, 3)))
	assert_true(result.ok(), result.error)
	assert_false(rogue.is_stealthed(), "the ambush revealed her")


func test_the_first_strike_from_stealth_hits_harder() -> void:
	var state := _duel()
	state.use_average_rolls = true
	var ambush := (PvpHeroes.build(4)["unit"] as UnitData).spells[1].effects[0] as DamageEffect
	var hidden_damage := ambush.scaled(state, 0, 1, ambush.average_roll())
	state.units[0].break_stealth()
	var plain_damage := ambush.scaled(state, 0, 1, ambush.average_roll())
	assert_true(hidden_damage > plain_damage * 1.7 and hidden_damage < plain_damage * 1.9, "+80%% (%f vs %f)" % [hidden_damage, plain_damage])


func test_the_ai_does_not_aim_at_a_hidden_unit_and_does_when_it_shows() -> void:
	var state := _duel()
	state.units[1].cell = Vector2i(2, 3)  # Next to it: seen.
	var battle := Battle.new(state)
	battle.start()
	var knight_id := 1
	while state.current_unit().id != knight_id:
		battle.perform(BattleActions.EndTurn.new(state.current_unit().id))
	assert_true(EnemyAI.choose_next(state, knight_id) is BattleActions.CastSpell, "it sees her next to it and hits her")
	state.units[1].cell = Vector2i(2, 7)  # Far: hidden.
	var action := EnemyAI.choose_next(state, knight_id)
	var attacking := action is BattleActions.CastSpell and state.units[knight_id].data.spells[(action as BattleActions.CastSpell).spell_index].is_offensive()
	assert_false(attacking, "no attack on a target it can't see")


func test_a_cleanse_removes_harmful_statuses_and_keeps_the_helpful_ones() -> void:
	var state := _duel(false)
	var target := state.units[1]
	target.add_status(load("res://data/pvp/statuses/plague.tres") as StatusData, 0)
	target.add_status(load("res://data/pvp/statuses/blessed.tres") as StatusData, 0)
	var cleanse := CleanseEffect.new()
	var events := cleanse.apply(state, 0, 1)
	assert_eq(target.statuses.size(), 1)
	assert_true(target.statuses[0].data.is_positive)
	assert_eq(events.size(), 1)
	var dispel := CleanseEffect.new()
	dispel.remove = CleanseEffect.Remove.HELPFUL
	dispel.apply(state, 0, 1)
	assert_eq(target.statuses.size(), 0)
