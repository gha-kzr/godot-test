@tool
class_name CardRules
extends RefCounted
## The card combat mode: a unit's spells become a deck. Each turn it draws up to HAND_SIZE cards and may play at most
## PLAYS_PER_TURN of them (a play is an action point: statuses that give or steal AP give or steal plays); the cards it
## does not play stay in its hand, or are thrown away. A card is one cast of one spell, so a played or thrown card goes
## to the discard pile, and the draw pile is the discard pile shuffled once it runs out.
## A spell's rarity is how many copies of it the deck holds: costly spells and spells with a long cooldown are rare.

const HAND_SIZE := 4
const PLAYS_PER_TURN := 2

enum Rarity { COMMON, UNCOMMON, RARE }

## Copies of a spell in a deck, by rarity.
const COPIES: Dictionary[Rarity, int] = {Rarity.COMMON: 3, Rarity.UNCOMMON: 2, Rarity.RARE: 1}


## How strong a spell is for the deck: its AP cost, plus a little for waiting turns before it can be cast again.
static func weight(spell: SpellData) -> int:
	var waiting := 0
	if spell.cooldown >= 2:
		waiting = 2
	elif spell.cooldown == 1:
		waiting = 1
	return spell.ap_cost + waiting


static func rarity(spell: SpellData) -> Rarity:
	var value := weight(spell)
	if value <= 2:
		return Rarity.COMMON
	if value <= 4:
		return Rarity.UNCOMMON
	return Rarity.RARE


static func rarity_name(spell: SpellData) -> String:
	match rarity(spell):
		Rarity.COMMON:
			return TranslationServer.translate("Common")
		Rarity.UNCOMMON:
			return TranslationServer.translate("Uncommon")
	return TranslationServer.translate("Rare")


static func rarity_color(spell: SpellData) -> Color:
	return [Color(0.75, 0.78, 0.85), Color(0.45, 0.8, 1.0), Color(1.0, 0.75, 0.25)][rarity(spell)]


static func copies(spell: SpellData) -> int:
	return COPIES[rarity(spell)]


## The unit's whole deck: each spell's slot number, once per copy, in slot order (the shuffle is the unit's).
static func deck_for(data: UnitData) -> Array[int]:
	var deck: Array[int] = []
	for slot in data.spells.size():
		for copy in copies(data.spells[slot]):
			deck.append(slot)
	return deck
