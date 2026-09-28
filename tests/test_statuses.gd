extends TestCase
## Statuses on units: modifiers read on demand, apply / refresh / replace, immediate AP and
## MP shifts, damage taken, cloning.

const MP := StatModifier.Stat.MP
const AP := StatModifier.Stat.AP
const TAKEN := StatModifier.Stat.DAMAGE_TAKEN_PERCENT


func _state() -> BattleState:
	return BattleFixtures.state("0p 0e")  # Units with 6 AP, 3 MP, 20 HP.


func _haste(amount := 2) -> StatusData:
	return BattleFixtures.status("Haste", 2, 0, [BattleFixtures.modifier(MP, amount)] as Array[StatModifier], true)


func test_modifiers_change_maxima_while_active_only() -> void:
	var unit := _state().units[0]
	unit.add_status(_haste(), 1)
	assert_eq(unit.max_mp(), 5)
	assert_eq(unit.max_ap(), 6, "other stats untouched")
	unit.statuses.clear()
	assert_eq(unit.max_mp(), 3, "nothing to undo on removal")
	assert_eq(unit.data.mp, 3, "the template never changes")


func test_refill_uses_the_modified_maxima() -> void:
	var unit := _state().units[0]
	unit.add_status(BattleFixtures.status("Slow", 2, 0, [BattleFixtures.modifier(AP, -2)] as Array[StatModifier]), 1)
	unit.start_turn()
	assert_eq(unit.ap, 4)
	assert_eq(unit.mp, 3)


func test_ap_and_mp_shift_immediately_when_a_status_lands() -> void:
	var unit := _state().units[0]
	unit.mp = 1
	unit.add_status(_haste(), 0)
	assert_eq(unit.mp, 3, "+2 MP right away")
	unit.add_status(BattleFixtures.status("Cripple", 2, 0, [BattleFixtures.modifier(MP, -5)] as Array[StatModifier]), 1)
	assert_eq(unit.mp, 0, "never below 0")
	assert_eq(unit.max_mp(), 0, "max never below 0 either")


func test_reapplying_refreshes_and_replaces_without_shifting_twice() -> void:
	var unit := _state().units[0]
	var haste := _haste()
	unit.add_status(haste, 0)
	unit.statuses[0].turns_left = 1
	unit.add_status(haste, 1)
	assert_eq(unit.statuses.size(), 1, "one instance")
	assert_eq(unit.statuses[0].turns_left, 2, "duration refreshed")
	assert_eq(unit.statuses[0].caster_id, 1, "new caster")
	assert_eq(unit.mp, 5, "+2 once, not twice")


func test_replacing_keeps_the_tick_order() -> void:
	var unit := _state().units[0]
	var poison := BattleFixtures.status("Poison", 2, 3)
	var burn := BattleFixtures.status("Burn", 2, 2)
	unit.add_status(poison, 1)
	unit.add_status(burn, 1)
	unit.add_status(poison, 1)
	assert_eq(unit.statuses[0].data, poison, "refreshed in place")
	assert_eq(unit.statuses[1].data, burn)


func test_damage_taken_modifiers_add_up_and_never_go_negative() -> void:
	var unit := _state().units[0]
	unit.add_status(BattleFixtures.status("Vulnerable", 2, 0, [BattleFixtures.modifier(TAKEN, 25)] as Array[StatModifier]), 1)
	assert_eq(unit.damage_taken_percent(), 125)
	unit.add_status(BattleFixtures.status("Protected", 2, 0, [BattleFixtures.modifier(TAKEN, -25)] as Array[StatModifier]), 1)
	assert_eq(unit.damage_taken_percent(), 100, "they cancel out")
	unit.add_status(BattleFixtures.status("Immune", 2, 0, [BattleFixtures.modifier(TAKEN, -300)] as Array[StatModifier]), 1)
	assert_eq(unit.damage_taken_percent(), 0)


func test_damage_is_scaled_by_damage_taken_and_capped_at_hp() -> void:
	var state := _state()
	var target := state.units[1]
	var hit := BattleFixtures.damage_spell(3, 1, 1, 10).effects[0]
	target.add_status(BattleFixtures.status("Vulnerable", 2, 0, [BattleFixtures.modifier(TAKEN, 25)] as Array[StatModifier]), 0)
	var events := hit.apply(state, 0, 1)
	assert_eq((events[0] as BattleEvents.DamageDealt).amount, 13, "10 x 125% = 12.5, rounded")
	target.statuses.clear()
	target.add_status(BattleFixtures.status("Guard", 2, 0, [BattleFixtures.modifier(TAKEN, -30)] as Array[StatModifier]), 1)
	events = hit.apply(state, 0, 1)
	assert_eq((events[0] as BattleEvents.DamageDealt).amount, 7)
	target.hp = 3
	target.statuses.clear()
	events = hit.apply(state, 0, 1)
	assert_eq((events[0] as BattleEvents.DamageDealt).amount, 3, "capped at the remaining HP")


func test_heals_ignore_damage_taken() -> void:
	var state := _state()
	var unit := state.units[0]
	unit.hp = 10
	unit.add_status(BattleFixtures.status("Vulnerable", 2, 0, [BattleFixtures.modifier(TAKEN, 50)] as Array[StatModifier]), 1)
	var heal := BattleFixtures.status("Regen", 2, -4).tick_effects[0]
	heal.apply(state, 0, 0)
	assert_eq(unit.hp, 14)


func test_apply_status_effect_puts_the_status_on_and_reports_it() -> void:
	var state := _state()
	var poison := BattleFixtures.status("Poison", 3, 2)
	var events := BattleFixtures.apply_status(poison).apply(state, 0, 1)
	assert_eq(events.size(), 1)
	var applied := events[0] as BattleEvents.StatusApplied
	assert_eq([applied.unit_id, applied.status, applied.turns_left], [1, poison, 3])
	assert_eq(state.units[1].find_status(poison).caster_id, 0)


func test_clones_copy_statuses_independently() -> void:
	var state := _state()
	state.units[0].add_status(_haste(), 1)
	var copy := state.clone()
	assert_eq(copy.units[0].statuses.size(), 1)
	assert_eq(copy.units[0].max_mp(), 5)
	copy.units[0].statuses[0].turns_left = 0
	copy.units[0].add_status(BattleFixtures.status("Poison", 2, 1), 1)
	assert_eq(state.units[0].statuses[0].turns_left, 2, "original untouched")
	assert_eq(state.units[0].statuses.size(), 1)
