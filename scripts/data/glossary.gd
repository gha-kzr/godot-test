@tool
class_name Glossary
extends RefCounted
## Plain explanations of the game's terms, shown as tooltips on the stats (the unit card, the hub).
## The texts are English message ids; tip() translates them.

const TEXTS: Dictionary[StringName, String] = {
	&"hp": "HP: health. At 0 the unit falls.",
	&"ap": "AP: action points. Each spell costs some; they refill every turn.",
	&"mp": "MP: movement points. Walking costs 1 per cell (and 1 more per step up); they refill every turn.",
	&"power": "Power: percent added to the damage and heals of the unit's spells.",
	&"resistance": "Resistance: percent less damage of one type (never more than three quarters for heroes; an enemy can be immune).",
	&"initiative": "Initiative: the higher it is, the earlier the unit plays.",
	&"damage_taken": "Damage taken: percent more (or, below 0, less) damage the unit takes, from statuses and runes.",
}


static func tip(key: StringName) -> String:
	return TranslationServer.translate(TEXTS.get(key, ""))


## Several terms together, one per line, for a label that shows more than one.
static func tips(keys: Array[StringName]) -> String:
	return "\n".join(keys.map(func(key: StringName) -> String: return tip(key)))
