class_name UnitInfo
extends RefCounted
## What the HUD shows about a unit. Plain data, built by the controller from the battle
## state: HUD components never read or change the state.

var unit_id := -1
var display_name := ""
var color := Color.WHITE
var is_player := true
## Heroes' level (0: not shown; enemies carry theirs in their name).
var level := 0
var hp := 0
var max_hp := 0
var ap := 0
var max_ap := 0
var mp := 0
var max_mp := 0
## Maxima without modifiers, to show buffs and debuffs.
var base_ap := 0
var base_mp := 0
var statuses: Array[StatusInfo] = []
var spells: Array[SpellData] = []
## Per spell slot: turns before it can be cast again (0: ready).
var cooldowns: Array[int] = []
## Card combat (CardRules): the hand as spells in hand order (the bar shows these), as spell slots (what an action
## names), and the piles' sizes. AP are plays then.
var card_mode := false
var hand_spells: Array[SpellData] = []
var hand_slots: Array[int] = []
var deck_size := 0
var draw_count := 0
var discard_count := 0
var power := 0
var role := EnemyData.Role.NONE
var initiative := 0
## Percent added to the damage the unit takes (0: normal; a Guard's -30, a Mark's +20).
var damage_taken := 0
## A hero's XP towards its next level, for menus (xp_max 0: not shown, as in battle).
var xp_value := 0
var xp_max := 0
## XP just gained (the bar's lighter segment) and the text under it; "" hides the text.
var xp_gain := 0
var xp_text := ""
## Damage type name → resistance %, every damage type of the game, in display order.
var resistances: Dictionary[String, int] = {}
## PvP units have no Power and no resistance to talk about (classes are fixed): their lines are not shown.
var hide_power_and_resistances := false


static func from_unit(unit: UnitState, hero_level := 0, pvp := false) -> UnitInfo:
	var info := UnitInfo.new()
	info.hide_power_and_resistances = pvp
	info.unit_id = unit.id
	info.display_name = unit.label
	info.color = unit.data.color
	info.is_player = unit.team == UnitState.Team.PLAYER
	info.level = hero_level
	info.hp = unit.hp
	info.max_hp = unit.max_hp()
	info.ap = unit.ap
	info.max_ap = unit.max_ap()
	info.base_ap = CardRules.PLAYS_PER_TURN if unit.card_mode else unit.data.ap
	info.mp = unit.mp
	info.max_mp = unit.max_mp()
	info.base_mp = unit.data.mp
	for status in unit.statuses:
		info.statuses.append(StatusInfo.from_data(status.data, status.turns_left, status.counting))
	info.spells = unit.data.spells
	for spell in unit.data.spells:
		info.cooldowns.append(unit.cooldown_left(spell))
	info.card_mode = unit.card_mode
	if unit.card_mode:
		info.hand_slots.assign(unit.hand)
		for slot in unit.hand:
			info.hand_spells.append(unit.data.spells[slot])
		info.deck_size = CardRules.deck_for(unit.data).size()
		info.draw_count = unit.draw_pile.size()
		info.discard_count = unit.discard_pile.size()
	info.power = unit.power()
	info.role = unit.role
	info.initiative = unit.initiative()
	info.damage_taken = unit.damage_taken_percent() - 100
	var types := DamageType.all().duplicate()
	for type in unit.resistance_types():  # A type outside the catalog still shows.
		if type not in types:
			types.append(type)
	for type in types:
		info.resistances[type.display_name] = unit.resistance_percent(type)
	return info


## "Knight · Lv 7", or just the name.
func title_text() -> String:
	return tr("%s · Lv %d") % [tr(display_name), level] if level > 0 else tr(display_name)


## Three lines, e.g. "Initiative 110, damage taken +0%", "Power: All +8%" and "Resist:
## Physical +0%, Fire +20%, …". Every stat and damage type is listed, zeros included, so
## nothing reads as missing. "All" leaves room for per-type power later.
func combat_stats_text() -> String:
	if hide_power_and_resistances:
		return tr("Initiative %d, damage taken %+d%%") % [initiative, damage_taken]
	var resist: Array[String] = []
	for type_name in resistances:
		if resistances[type_name] >= UnitState.MAX_ENEMY_RESISTANCE_PERCENT:
			resist.append(tr("%s immune") % tr(type_name))
		else:
			resist.append("%s %+d%%" % [tr(type_name), resistances[type_name]])
	return "%s\n%s" % [tr("Initiative %d, damage taken %+d%%") % [initiative, damage_taken],
			tr("Power: All %+d%%\nResist: %s") % [power, ", ".join(resist) if not resist.is_empty() else tr("none")]]
