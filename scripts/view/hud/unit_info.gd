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
var power := 0
## A hero's XP towards its next level, for menus (xp_max 0: not shown, as in battle).
var xp_value := 0
var xp_max := 0
## Damage type name → resistance %, every damage type of the game, in display order.
var resistances: Dictionary[String, int] = {}


static func from_unit(unit: UnitState, hero_level := 0) -> UnitInfo:
	var info := UnitInfo.new()
	info.unit_id = unit.id
	info.display_name = unit.label
	info.color = unit.data.color
	info.is_player = unit.team == UnitState.Team.PLAYER
	info.level = hero_level
	info.hp = unit.hp
	info.max_hp = unit.max_hp()
	info.ap = unit.ap
	info.max_ap = unit.max_ap()
	info.base_ap = unit.data.ap
	info.mp = unit.mp
	info.max_mp = unit.max_mp()
	info.base_mp = unit.data.mp
	for status in unit.statuses:
		info.statuses.append(StatusInfo.from_data(status.data, status.turns_left, status.counting))
	info.spells = unit.data.spells
	info.power = unit.power()
	var types := DamageType.all().duplicate()
	for type in unit.resistance_types():  # A type outside the catalog still shows.
		if type not in types:
			types.append(type)
	for type in types:
		info.resistances[type.display_name] = unit.resistance_percent(type)
	return info


## "Knight · Lv 7", or just the name.
func title_text() -> String:
	return "%s · Lv %d" % [display_name, level] if level > 0 else display_name


## Two lines, e.g. "Power: All +8%" and "Resist: Physical +0%, Fire +20%, Poison +0%".
## Every damage type is listed, zeros included, so nothing reads as missing. "All"
## leaves room for per-type power later.
func combat_stats_text() -> String:
	var resist: Array[String] = []
	for type_name in resistances:
		resist.append("%s %+d%%" % [type_name, resistances[type_name]])
	return "Power: All %+d%%\nResist: %s" % [power, ", ".join(resist) if not resist.is_empty() else "none"]
