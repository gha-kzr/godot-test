@tool
class_name BalanceLab
extends RefCounted
## Runs AI-vs-AI battles of a party against an encounter on the rules layer alone (no
## nodes, safe on a worker thread) and tallies outcomes, rounds, damage and spell use.
## The party side is played by the AI too, with the encounter's profile.

const MAX_ACTIONS := 1000


## Shared with the thread running a lab: cancel it, and read how far it got.
class RunControl:
	var _mutex := Mutex.new()
	var _cancelled := false
	var _completed := 0

	func cancel() -> void:
		_mutex.lock()
		_cancelled = true
		_mutex.unlock()

	func is_cancelled() -> bool:
		_mutex.lock()
		var value := _cancelled
		_mutex.unlock()
		return value

	func completed() -> int:
		_mutex.lock()
		var value := _completed
		_mutex.unlock()
		return value

	func _count_battle() -> void:
		_mutex.lock()
		_completed += 1
		_mutex.unlock()


class Result:
	var battles := 0
	var player_wins := 0
	var enemy_wins := 0
	var draws := 0
	var unfinished := 0
	var total_rounds := 0
	var cancelled := false
	## Per unit ("Knight", "Brute Lv 5 · Elite", "Brute Lv 1 #2" when labels repeat):
	## totals over all battles.
	var damage_dealt: Dictionary[String, int] = {}
	var damage_taken: Dictionary[String, int] = {}
	## Damage from status ticks (poison…), not credited to a unit.
	var status_damage := 0
	var spell_uses: Dictionary[String, int] = {}

	func win_rate() -> float:
		return float(player_wins) / battles if battles > 0 else 0.0

	func summary() -> PackedStringArray:
		var lines := PackedStringArray()
		lines.append("%d battles%s: party wins %d (%d%%), enemies %d, draws %d, unfinished %d; %.1f rounds on average" % [
				battles, " (cancelled)" if cancelled else "", player_wins, roundi(win_rate() * 100), enemy_wins, draws,
				unfinished, float(total_rounds) / maxi(1, battles)])
		if battles == 0:
			return lines
		lines.append("Per battle, on average:")
		for label in damage_dealt.keys():
			lines.append("  %-22s dealt %5.1f  taken %5.1f" % [label, damage_dealt[label] / float(battles),
					damage_taken.get(label, 0) / float(battles)])
		if status_damage > 0:
			lines.append("  %-22s %5.1f" % ["status ticks", status_damage / float(battles)])
		var spells := spell_uses.keys()
		spells.sort_custom(func(a: String, b: String) -> bool: return spell_uses[a] > spell_uses[b])
		lines.append("Spells cast: " + ", ".join(spells.map(func(s: String) -> String: return "%s %d" % [s, spell_uses[s]])))
		return lines


## A party of heroes at given levels (and optional runes per hero), as battle input.
static func party(heroes: Array[HeroData], levels: Array[int], runes: Array = []) -> Array:
	var units: Array[UnitData] = []
	var modifiers: Array = []
	for i in heroes.size():
		var record := HeroRecord.new(heroes[i])
		record.level = levels[i] if i < levels.size() else 1
		if i < runes.size():
			for slot in mini(runes[i].size(), HeroRecord.RUNE_SLOTS):
				record.runes[slot] = runes[i][slot]
		units.append(record.battle_unit_data())
		modifiers.append(record.modifiers())
	return [units, modifiers]


## Runs up to `battles` battles; `control` (optional) cancels between battles and counts
## progress. Give a worker thread its own copies of the inputs (see snapshot()).
static func run(party_units: Array[UnitData], party_modifiers: Array, encounter: Encounter, battles: int,
		first_seed := 1, control: RunControl = null) -> Result:
	var result := Result.new()
	var parsed := encounter.map.parse()
	var default_profile := encounter.ai_profile if encounter.ai_profile != null else AIProfile.new()
	for i in battles:
		if control != null and control.is_cancelled():
			result.cancelled = true
			break
		var builds := encounter.builds()
		var enemies: Array[UnitData] = []
		for build in builds:
			enemies.append(build.unit)
		var state := BattleState.create(parsed, party_units, enemies, first_seed + i, party_modifiers, builds)
		if state == null:
			return result
		result.battles += 1
		var battle := Battle.new(state)
		_tally(result, state, battle.start(), -1)
		var actions := 0
		while not state.is_over() and actions < MAX_ACTIONS:
			var actor := state.turn_order.current_unit_id()
			var unit := state.units[actor]
			var profile := unit.ai_profile if unit.ai_profile != null else default_profile
			var outcome := battle.perform(EnemyAI.choose_next(state, actor, profile))
			if not outcome.ok():
				outcome = battle.perform(BattleActions.EndTurn.new(actor))
			_tally(result, state, outcome.events, actor)
			actions += 1
		result.total_rounds += state.turn_order.round_number
		match state.outcome():
			BattleState.Outcome.PLAYER_WON: result.player_wins += 1
			BattleState.Outcome.ENEMY_WON: result.enemy_wins += 1
			BattleState.Outcome.DRAW: result.draws += 1
			_: result.unfinished += 1
		if control != null:
			control._count_battle()
	return result


## Independent copies of a lab's inputs, so a worker thread never reads resources the
## Inspector may be editing: [units, modifiers, encounter].
static func snapshot(party_units: Array[UnitData], party_modifiers: Array, encounter: Encounter) -> Array:
	var units: Array[UnitData] = []
	for unit in party_units:
		units.append(unit.duplicate_deep(Resource.DEEP_DUPLICATE_ALL))
	var modifiers: Array = []
	for list: Array in party_modifiers:
		var copies: Array[StatModifier] = []
		for modifier: StatModifier in list:
			copies.append(modifier.duplicate_deep(Resource.DEEP_DUPLICATE_ALL))
		modifiers.append(copies)
	return [units, modifiers, encounter.duplicate_deep(Resource.DEEP_DUPLICATE_ALL)]


## A stable key per unit: its label, numbered when several units share it.
static func _keys(state: BattleState) -> Dictionary[int, String]:
	var counts: Dictionary[String, int] = {}
	for unit in state.units:
		counts[unit.label] = counts.get(unit.label, 0) + 1
	var seen: Dictionary[String, int] = {}
	var keys: Dictionary[int, String] = {}
	for unit in state.units:
		if counts[unit.label] == 1:
			keys[unit.id] = unit.label
		else:
			seen[unit.label] = seen.get(unit.label, 0) + 1
			keys[unit.id] = "%s #%d" % [unit.label, seen[unit.label]]
	return keys


## Damage of an action goes to its actor until the next turn starts; damage after a
## TurnStarted comes from status ticks.
static func _tally(result: Result, state: BattleState, events: Array[BattleEvents.Event], actor: int) -> void:
	var credited := actor
	var keys := _keys(state)
	for unit in state.units:
		if not result.damage_dealt.has(keys[unit.id]):
			result.damage_dealt[keys[unit.id]] = 0
	for event in events:
		if event is BattleEvents.TurnStarted:
			credited = -1
		elif event is BattleEvents.SpellCast:
			var spell_name := (event as BattleEvents.SpellCast).spell.display_name
			result.spell_uses[spell_name] = result.spell_uses.get(spell_name, 0) + 1
		elif event is BattleEvents.DamageDealt:
			var hit := event as BattleEvents.DamageDealt
			var target := keys[hit.unit_id]
			result.damage_taken[target] = result.damage_taken.get(target, 0) + hit.amount
			if credited >= 0:
				var dealer := keys[credited]
				result.damage_dealt[dealer] = result.damage_dealt.get(dealer, 0) + hit.amount
			else:
				result.status_damage += hit.amount
