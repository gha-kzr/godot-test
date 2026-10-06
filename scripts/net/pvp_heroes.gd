class_name PvpHeroes
extends RefCounted
## The classes of a PvP match (data/pvp/roster.tres): fixed units with no levels, no runes and no Power.
## What the lobby shows of a class, and what a match builds from it.

const ROSTER := "res://data/pvp/roster.tres"


static func roster() -> PvpRoster:
	return load(ROSTER) as PvpRoster


static func hero_count() -> int:
	return roster().heroes.size()


static func hero(hero_index: int) -> PvpHero:
	var all := roster().heroes
	return all[clampi(hero_index, 0, all.size() - 1)]


## The class's name for the lobby.
static func hero_name(hero_index: int) -> String:
	return TranslationServer.translate(hero(hero_index).display_name())


## The class's unit and its permanent modifiers (none: classes are what they are).
static func build(hero_index: int) -> Dictionary:
	return {"unit": hero(hero_index).unit, "modifiers": []}


## What the lobby shows of a class: name, role, short description, stats and its spells.
static func summary(hero_index: int) -> Dictionary:
	var entry := hero(hero_index)
	var unit := entry.unit
	var state := UnitState.new(0, unit, UnitState.Team.PLAYER, Vector2i.ZERO)
	var icons: Array[Texture2D] = []
	var names: Array[String] = []
	for spell in unit.spells:
		icons.append(spell.display_icon())
		names.append(TranslationServer.translate(spell.display_name))
	return {"name": hero_name(hero_index), "role": TranslationServer.translate(entry.role_label),
			"description": TranslationServer.translate(entry.description), "gender": entry.gender,
			"hp": state.max_hp(), "ap": state.max_ap(), "mp": state.max_mp(),
			"spell_icons": icons, "spell_names": names}


## Everything the info popup shows: the summary, plus each spell in full.
static func details(hero_index: int) -> Dictionary:
	var info := summary(hero_index)
	var spells: Array[Dictionary] = []
	for spell in hero(hero_index).unit.spells:
		spells.append({"name": TranslationServer.translate(spell.display_name), "icon": spell.display_icon(), "ap": spell.ap_cost,
				"lines": SpellBar.detail_lines(spell)})
	info["spells"] = spells
	return info
