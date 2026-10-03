@tool
class_name EnemyAI
extends RefCounted
## Greedy utility AI for the unit whose turn it is. Call choose_next() repeatedly and
## perform each action until it returns EndTurn.
##
## Each call rates every (position in reach × spell × target) by simulating the cast on
## a clone with average rolls and scoring the HP and status changes with an AIProfile's weights,
## then returns the first step of the best plan:
## a Move to that position, or the cast itself. With nothing worth casting, it walks
## toward the nearest opponent. Team-agnostic: opponents are the units of the other team.
## It decides once per move segment: after a move it never repositions before casting (no
## rethinking, and the turn always ends), but it can move again after a cast.

## Distance of cells from which no opponent can be reached.
const FAR_AWAY := 1 << 30


class Plan:
	var cell: Vector2i
	var mp_cost: int
	var spell_index: int
	var target: Vector2i
	var score: float


## `profile` defaults to AIProfile's default weights.
static func choose_next(state: BattleState, unit_id: int, profile: AIProfile = null) -> BattleActions.Action:
	if state.is_over() or state.turn_order.current_unit_id() != unit_id:
		push_error("EnemyAI: it is not unit %d's turn" % unit_id)
		return BattleActions.EndTurn.new(unit_id)
	if profile == null:
		profile = AIProfile.new()

	var reach := Movement.reach(state, unit_id)
	var plan := _best_cast(state, unit_id, reach, profile)
	if plan != null:
		if plan.cell != state.units[unit_id].cell:
			return BattleActions.Move.new(unit_id, plan.cell)
		return BattleActions.CastSpell.new(unit_id, plan.spell_index, plan.target)

	var destination := _approach(state, unit_id, reach)
	if destination != state.units[unit_id].cell:
		return BattleActions.Move.new(unit_id, destination)
	return BattleActions.EndTurn.new(unit_id)


## Best cast with a positive score from any cell in reach, or null. Ties go to the plan
## needing the least MP, then to the first one found.
static func _best_cast(state: BattleState, unit_id: int, reach: Movement.Reach, profile: AIProfile) -> Plan:
	var unit := state.units[unit_id]
	var positions: Array[Vector2i] = [unit.cell]
	if not unit.moved:
		positions.append_array(reach.cells())
	# Damage and heals use the average roll, so the AI decides on what usually happens.
	# Any other randomness gets dice seeded apart from the real RNG, so the AI never
	# sees a future roll.
	var dice_seed := hash([state.turn_order.round_number, unit_id])

	var best: Plan = null
	for cell in positions:
		# Standing on `cell` is set directly: it comes from `reach`, so the move is legal.
		var moved := state.clone()
		moved.use_average_rolls = true
		moved.units[unit_id].cell = cell
		moved.units[unit_id].mp = reach.origin_budget - reach.cost_to(cell)
		for spell_index in unit.data.spells.size():
			var spell := unit.data.spells[spell_index]
			# A free spell could be cast forever; skipping it guarantees the turn ends.
			if spell.ap_cost <= 0 or not BattleActions.CastSpell.can_afford(unit, spell_index):
				continue
			for target in Targeting.targetable_cells(moved, unit_id, spell):
				if not _area_hits_a_unit(moved, spell, cell, target):
					continue
				var simulated := moved.clone()
				simulated.rng.seed = dice_seed
				var result := Battle.new(simulated).perform(BattleActions.CastSpell.new(unit_id, spell_index, target))
				if not result.ok():
					push_error("EnemyAI: simulated cast rejected: %s" % result.error)
					continue
				var score := _score(state, simulated, unit.team, profile)
				var cost := reach.cost_to(cell)
				if score > 0.0 and (best == null or score > best.score
						or (is_equal_approx(score, best.score) and cost < best.mp_cost)):
					best = Plan.new()
					best.cell = cell
					best.mp_cost = cost
					best.spell_index = spell_index
					best.target = target
					best.score = score
	return best


static func _area_hits_a_unit(state: BattleState, spell: SpellData, caster_cell: Vector2i, target: Vector2i) -> bool:
	for cell in Targeting.area_cells(state.grid, spell.area, caster_cell, target):
		if state.is_occupied(cell):
			return true
	return false


## Value of the HP and status changes between two states, from `team`'s point of view.
static func _score(before: BattleState, after: BattleState, team: UnitState.Team, profile: AIProfile) -> float:
	return _hp_score(before, after, team, profile) + _status_score(before, after, team, profile)


static func _hp_score(before: BattleState, after: BattleState, team: UnitState.Team, profile: AIProfile) -> float:
	var score := 0.0
	for unit in before.units:
		if not unit.is_alive():
			continue
		var lost := float(unit.hp - after.units[unit.id].hp)  # Negative when healed.
		var killed := not after.units[unit.id].is_alive()
		if unit.team != team:
			score += lost + (profile.kill_bonus if killed else 0.0)
		elif lost < 0.0:
			score += -lost * profile.heal_weight
		else:
			score -= (lost + (profile.kill_bonus if killed else 0.0)) * profile.friendly_fire_weight
	return score


## Change in the expected value of every surviving unit's statuses. Comparing totals
## means a refresh only scores what it adds, and a downgrade scores negative.
static func _status_score(before: BattleState, after: BattleState, team: UnitState.Team, profile: AIProfile) -> float:
	var score := 0.0
	for unit in after.units:
		if not unit.is_alive():
			continue  # A kill is valued by the HP score; its statuses no longer matter.
		var gained := _statuses_benefit(after, unit, profile) - _statuses_benefit(before, before.units[unit.id], profile)
		if is_zero_approx(gained):
			continue
		if unit.team != team:
			score -= gained  # Helping an opponent is bad, hurting one is good.
		elif gained > 0.0:
			score += gained
		else:
			score += gained * profile.friendly_fire_weight
	return score * profile.status_weight


## Expected worth of a unit's statuses to the unit itself, in HP, over their remaining
## turns (positive helps it, negative hurts it).
static func _statuses_benefit(state: BattleState, unit: UnitState, profile: AIProfile) -> float:
	var total := 0.0
	var hp_left := float(unit.hp)
	var hp_missing := float(unit.max_hp() - unit.hp)
	for status in unit.statuses:
		# During its carrier's turn, the turn in progress has already ticked.
		var turns := float(status.turns_left - (1 if status.counting else 0))
		if turns <= 0.0:
			continue
		for effect in status.data.tick_effects:
			if effect is DamageEffect:
				var damage := effect as DamageEffect
				var per_tick := damage.scaled(state, status.caster_id, unit.id, damage.average_roll())
				var dealt := minf(per_tick * turns, hp_left)
				hp_left -= dealt
				total -= dealt
			elif effect is HealEffect:
				var heal := effect as HealEffect
				var healed := minf(heal.scaled(state, status.caster_id, heal.average_roll()) * turns, hp_missing)
				hp_missing -= healed
				total += healed
			else:
				push_warning("EnemyAI: can't value tick effect %s; counted as 0" % effect.get_script().get_global_name())
		for modifier in status.data.modifiers:
			match modifier.stat:
				StatModifier.Stat.AP:
					total += modifier.amount * turns * profile.ap_value
				StatModifier.Stat.MP:
					total += modifier.amount * turns * profile.mp_value
				StatModifier.Stat.DAMAGE_TAKEN_PERCENT:
					total -= modifier.amount / 100.0 * turns * profile.incoming_damage_per_turn
				_:
					push_warning("EnemyAI: can't value stat %s; counted as 0" % StatModifier.Stat.keys()[modifier.stat])
	return total


## The cell in reach closest (in walking cost) to an opponent, or the unit's own cell
## if no cell in reach gets closer.
static func _approach(state: BattleState, unit_id: int, reach: Movement.Reach) -> Vector2i:
	var unit := state.units[unit_id]
	if unit.moved:
		return unit.cell  # Already moved this segment: no second thoughts.
	var opponents: Array[Vector2i] = []
	for other in state.units:
		if other.is_alive() and other.team != unit.team:
			opponents.append(other.cell)
	var distances := Movement.distances_to(state.grid, opponents)

	var best := unit.cell
	var best_distance: int = distances.get(unit.cell, FAR_AWAY)
	for cell in reach.cells():
		var distance: int = distances.get(cell, FAR_AWAY)
		if distance < best_distance or (distance == best_distance and best != unit.cell
				and reach.cost_to(cell) < reach.cost_to(best)):
			best = cell
			best_distance = distance
	return best
