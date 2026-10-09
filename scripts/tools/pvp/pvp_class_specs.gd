class_name PvpClassSpecs
extends RefCounted
## The PvP classes, their spells and statuses, as plain data: the numbers live here, in one place, so balancing
## is "edit a number, rebuild" (`godot --headless --script res://tools/build_pvp_classes.gd`, then
## `tools/fill_uid_refs.gd`). The build writes data/pvp/**.tres; after that the .tres files are ordinary
## resources you can also tweak in the Inspector (a rebuild overwrites them).
##
## A damage or heal is [kind, min, max, ...]. Spell effects:
##   ["dmg", min, max, type, filter, {lifesteal, ambush}]   ["heal", min, max, filter]
##   ["status", id, filter]   ["move", kind, distance, filter]   ["cleanse", "harmful"|"helpful", filter]
## filter: "all", "allies", "enemies" or "caster". Areas: "single", ["circle", n], ["cross", n], ["line", n].
## `from` borrows an existing spell's look and sound (icon, projectile, impact, animation); `icon` overrides the icon
## (ui/icons/<icon>.svg): the spells of one class must all have different icons (a test checks it).

## Class order is the lobby's order.
const ORDER: Array[String] = ["knight", "ranger", "sorceress", "necromancer", "rogue", "priestess", "goblin", "wraith", "monk"]


static func statuses() -> Dictionary:
	return {
		# --- Helpful ---
		"stealth": {"name": "Hidden", "label": "H", "dur": 6, "positive": true, "color": [0.7, 0.7, 0.9], "stealth": true},
		"bulwark": {"name": "Bulwark", "label": "B", "dur": 2, "positive": true, "color": [0.6, 0.75, 1.0], "mods": [["dmg", -35], ["mp", 1]], "aura": "guarded"},
		"blessed": {"name": "Blessed", "label": "+", "dur": 2, "positive": true, "color": [1.0, 0.9, 0.5], "mods": [["ap", 1]]},
		"regrowth": {"name": "Regrowth", "label": "R", "dur": 3, "positive": true, "color": [0.5, 1.0, 0.6], "ticks": [["heal", 7, 9]], "aura": "regeneration"},
		"hasty": {"name": "Hasty", "label": ">", "dur": 1, "positive": true, "color": [0.6, 1.0, 0.6], "mods": [["mp", 3]]},
		"nimble": {"name": "Light fingers", "label": "L", "dur": 1, "positive": true, "color": [1.0, 0.85, 0.4], "mods": [["ap", 1]]},
		# --- Harmful ---
		"plague": {"name": "Plague", "label": "P", "dur": 3, "color": [0.55, 0.9, 0.3], "ticks": [["dmg", 9, 9, "poison"]], "aura": "poison"},
		"rot": {"name": "Rot", "label": "T", "dur": 2, "color": [0.5, 0.7, 0.2], "ticks": [["dmg", 17, 17, "poison"]], "aura": "poison"},
		"miasma": {"name": "Miasma", "label": "M", "dur": 3, "color": [0.4, 0.8, 0.5], "ticks": [["dmg", 6, 6, "poison"]], "mods": [["mp", -1]], "aura": "poison"},
		"rooted": {"name": "Rooted", "label": "Ro", "dur": 1, "color": [0.6, 0.45, 0.25], "mods": [["mp", -9]], "aura": "crippled"},
		"slowed": {"name": "Slowed", "label": "S", "dur": 2, "color": [0.5, 0.8, 1.0], "mods": [["mp", -2]], "aura": "chilled"},
		"drained": {"name": "Drained", "label": "D", "dur": 1, "color": [0.7, 0.4, 0.9], "mods": [["ap", -2]], "aura": "dread"},
		"dread": {"name": "Dread", "label": "Dr", "dur": 1, "color": [0.7, 0.5, 0.9], "mods": [["ap", -1]], "aura": "dread"},
		"hunted": {"name": "Hunted", "label": "!", "dur": 2, "color": [1.0, 0.6, 0.3], "mods": [["dmg", 25]], "aura": "marked"},
		"robbed": {"name": "Robbed", "label": "$", "dur": 1, "color": [0.9, 0.8, 0.3], "mods": [["ap", -1]]},
		"bleeding": {"name": "Bleeding", "label": "Bl", "dur": 3, "color": [0.9, 0.3, 0.3], "ticks": [["dmg", 4, 4, "physical"]]},
	}


static func spells() -> Dictionary:
	return {
		# --- Knight ---
		"knight_slash": {"name": "Slash", "from": "slash", "ap": 3, "range": [1, 1], "fx": [["dmg", 16, 20, "physical"]]},
		"knight_charge": {"name": "Charge", "from": "charge", "ap": 3, "range": [2, 5], "los": false, "cd": 3, "target": "any",
				"fx": [["move", "charge", 1, "caster"], ["dmg", 11, 15, "physical", "enemies"]]},
		"knight_bash": {"name": "Shield Bash", "from": "shield_bash", "ap": 3, "range": [1, 1], "cd": 1,
				"fx": [["dmg", 10, 14, "physical"], ["move", "push", 2, "enemies"]]},
		"knight_guard": {"name": "Guard", "from": "guard", "ap": 2, "range": [0, 0], "los": false,
				"fx": [["status", "bulwark", "caster"]]},
		"knight_whirlwind": {"name": "Whirlwind", "from": "whirlwind", "ap": 4, "range": [0, 0], "los": false, "area": ["circle", 1],
				"fx": [["dmg", 13, 17, "physical", "enemies"]]},
		# --- Ranger ---
		"ranger_arrow": {"name": "Arrow", "from": "arrow", "ap": 3, "range": [2, 7], "height": true, "fx": [["dmg", 18, 22, "physical"]]},
		"ranger_volley": {"name": "Volley", "from": "volley", "ap": 4, "range": [3, 6], "area": ["circle", 1],
				"fx": [["dmg", 11, 14, "physical", "enemies"]]},
		"ranger_mark": {"name": "Hunter's Mark", "from": "hunters_mark", "ap": 2, "range": [2, 7], "fx": [["status", "hunted", "enemies"]]},
		"ranger_pin": {"name": "Pinning Shot", "from": "pinning_shot", "ap": 3, "range": [2, 6], "cd": 1,
				"fx": [["dmg", 9, 11, "physical"], ["status", "slowed", "enemies"]]},
		"ranger_backslash": {"name": "Backslash", "from": "backslash", "ap": 2, "range": [1, 1], "cd": 1, "los": false,
				"fx": [["dmg", 9, 11, "physical", "enemies"], ["move", "retreat", 4, "caster"]]},
		# --- Sorceress: pure damage ---
		"sorc_firebolt": {"name": "Firebolt", "from": "firebolt", "ap": 3, "range": [2, 6], "height": true, "fx": [["dmg", 22, 27, "fire"]]},
		"sorc_fireball": {"name": "Fireball", "from": "fireball", "ap": 4, "range": [3, 6], "area": ["circle", 1],
				"fx": [["dmg", 16, 20, "fire", "enemies"]]},
		"sorc_frost_spike": {"name": "Frost Spike", "from": "frost_lance", "ap": 2, "range": [2, 5], "cd": 1, "fx": [["dmg", 15, 19, "frost"]]},
		"sorc_meteor": {"name": "Meteor", "from": "fireball", "icon": "meteor", "ap": 6, "range": [4, 7], "cd": 4, "area": ["circle", 2],
				"fx": [["dmg", 36, 44, "fire", "enemies"]]},
		"sorc_blink": {"name": "Blink", "from": "blink", "ap": 2, "range": [1, 4], "los": false, "cd": 3, "fx": [["move", "teleport", 1, "caster"]]},
		# --- Necromancer: damage over time and alterations ---
		"necro_plague_bolt": {"name": "Plague Bolt", "from": "spore_bolt", "ap": 3, "range": [2, 5],
				"fx": [["dmg", 10, 12, "poison"], ["status", "plague", "enemies"]]},
		"necro_rot": {"name": "Rot Curse", "from": "spore_hex", "ap": 3, "range": [2, 5], "fx": [["status", "rot", "enemies"]]},
		"necro_miasma": {"name": "Miasma", "from": "spore_hex", "icon": "miasma", "ap": 4, "range": [3, 6], "area": ["circle", 1],
				"fx": [["status", "miasma", "enemies"]]},
		"necro_grasp": {"name": "Grasping Dead", "from": "chill_touch", "ap": 3, "range": [2, 5], "cd": 3, "fx": [["status", "rooted", "enemies"]]},
		"necro_drain": {"name": "Drain Will", "from": "wail", "ap": 3, "range": [2, 5], "cd": 2,
				"fx": [["dmg", 5, 7, "poison"], ["status", "drained", "enemies"]]},
		# --- Rogue: appears and vanishes ---
		"rogue_dagger": {"name": "Dagger Strike", "from": "slash", "ap": 2, "range": [1, 1], "fx": [["dmg", 11, 15, "physical"]]},
		"rogue_ambush": {"name": "Ambush", "from": "piercing_thrust", "ap": 3, "range": [1, 1],
				"fx": [["dmg", 18, 22, "physical", "enemies", {"ambush": 80}]]},
		"rogue_vanish": {"name": "Vanish", "from": "guard", "ap": 2, "range": [0, 0], "los": false, "cd": 4, "fx": [["status", "stealth", "caster"]]},
		"rogue_shadow_step": {"name": "Shadow Step", "from": "blink", "ap": 2, "range": [2, 4], "los": false, "cd": 2, "fx": [["move", "teleport", 1, "caster"]]},
		"rogue_hamstring": {"name": "Hamstring", "from": "hamstring", "ap": 2, "range": [1, 1], "cd": 1,
				"fx": [["dmg", 7, 9, "physical"], ["status", "slowed", "enemies"]]},
		# --- Priestess: heals and boosts, very little damage ---
		"priest_smite": {"name": "Smite", "from": "smite", "ap": 3, "range": [1, 4], "fx": [["dmg", 12, 15, "holy"]]},
		"priest_heal": {"name": "Healing Touch", "from": "mend", "ap": 3, "range": [1, 4], "target": "ally", "fx": [["heal", 22, 28, "allies"]]},
		"priest_rain": {"name": "Mending Rain", "from": "regeneration", "ap": 4, "range": [0, 4], "area": ["circle", 1],
				"fx": [["status", "regrowth", "allies"]]},
		"priest_bless": {"name": "Blessing", "from": "guard", "ap": 2, "range": [1, 5], "cd": 3, "target": "ally", "fx": [["status", "blessed", "allies"]]},
		"priest_purify": {"name": "Purify", "from": "spore_mend", "ap": 2, "range": [0, 4], "cd": 1,
				"fx": [["cleanse", "harmful", "allies"], ["heal", 8, 10, "allies"]]},
		# --- Goblin: bombs, tricks, mobility ---
		"goblin_sling": {"name": "Slingshot", "from": "arrow", "ap": 2, "range": [2, 5], "fx": [["dmg", 9, 12, "physical"]]},
		"goblin_bomb": {"name": "Bomb", "from": "fireball", "ap": 3, "range": [2, 5], "area": ["circle", 1],
				"fx": [["dmg", 14, 18, "fire", "all"]]},
		"goblin_pickpocket": {"name": "Pickpocket", "from": "hamstring", "ap": 2, "range": [1, 1], "cd": 3,
				"fx": [["dmg", 5, 7, "physical", "enemies"], ["status", "robbed", "enemies"], ["status", "nimble", "caster"]]},
		"goblin_scamper": {"name": "Scamper", "from": "guard", "ap": 2, "range": [0, 0], "los": false, "cd": 2, "fx": [["status", "hasty", "caster"]]},
		"goblin_dynamite": {"name": "Dynamite", "from": "fireball", "icon": "dynamite", "ap": 4, "range": [3, 6], "cd": 3, "area": ["circle", 2],
				"fx": [["dmg", 24, 30, "fire", "all"], ["move", "push", 1, "all"]]},
		# --- Wraith ---
		"wraith_touch": {"name": "Spectral Touch", "from": "chill_touch", "ap": 3, "range": [1, 3], "fx": [["dmg", 14, 18, "frost"]]},
		"wraith_wail": {"name": "Wail", "from": "wail", "ap": 3, "range": [0, 0], "los": false, "cd": 2, "area": ["circle", 2],
				"fx": [["dmg", 8, 10, "frost", "enemies"], ["status", "dread", "enemies"]]},
		"wraith_phase": {"name": "Phase Walk", "from": "blink", "ap": 2, "range": [1, 4], "los": false, "cd": 2, "fx": [["move", "teleport", 1, "caster"]]},
		"wraith_siphon": {"name": "Life Siphon", "from": "icy_grasp", "ap": 3, "range": [1, 3], "fx": [["dmg", 10, 12, "frost", "enemies", {"lifesteal": 60}]]},
		"wraith_chill": {"name": "Grave Chill", "from": "chill_touch", "icon": "grave_chill", "ap": 2, "range": [2, 5], "fx": [["dmg", 8, 10, "frost"], ["status", "slowed", "enemies"]]},
		# --- Monk: pushes, pulls and quick feet ---
		"monk_palm": {"name": "Palm Strike", "from": "club", "ap": 2, "range": [1, 1], "fx": [["dmg", 10, 14, "physical"]]},
		"monk_dash": {"name": "Flying Kick", "from": "charge", "ap": 3, "range": [2, 4], "los": false, "cd": 2, "target": "any",
				"fx": [["move", "charge", 1, "caster"], ["dmg", 10, 14, "physical", "enemies"]]},
		"monk_staff": {"name": "Whirling Staff", "from": "whirlwind", "ap": 3, "range": [0, 0], "los": false, "area": ["circle", 1], "cd": 1,
				"fx": [["dmg", 7, 9, "physical", "enemies"], ["move", "push", 2, "enemies"]]},
		"monk_hook": {"name": "Iron Grip", "from": "grapple_shot", "ap": 3, "range": [2, 5], "cd": 1,
				"fx": [["dmg", 8, 10, "physical", "enemies"], ["move", "pull", 3, "enemies"]]},
		"monk_peace": {"name": "Inner Peace", "from": "regeneration", "ap": 3, "range": [0, 0], "los": false, "cd": 2,
				"fx": [["heal", 18, 22, "caster"], ["cleanse", "harmful", "caster"]]},
	}


## Per class: unit stats, its spells in key order, and what the lobby shows. `look` borrows a single-player model, `model` names an own recipe in scripts/tools/modeling/recipes (and `height` is its top in meters).
static func heroes() -> Dictionary:
	return {
		"knight": {"name": "Knight", "gender": "male", "hp": 180, "ap": 7, "mp": 4, "init": 100, "look": "knight", "color": [0.25, 0.45, 0.9],
				"role": "Frontline", "desc": "Charges in, bashes enemies out of position and shrugs off blows with Guard. Slow to reach, hard to remove.",
				"spells": ["knight_slash", "knight_charge", "knight_bash", "knight_guard", "knight_whirlwind"]},
		"ranger": {"name": "Ranger", "gender": "neutral", "hp": 130, "ap": 7, "mp": 5, "init": 108, "look": "ranger", "color": [0.3, 0.75, 0.4],
				"ai": "ranged", "role": "Mobile sharpshooter", "desc": "Shoots from far away, slows and marks targets, and leaps back out of reach. Weak when caught.",
				"spells": ["ranger_arrow", "ranger_volley", "ranger_mark", "ranger_pin", "ranger_backslash"]},
		"sorceress": {"name": "Sorceress", "gender": "female", "hp": 85, "ap": 7, "mp": 4, "init": 105, "model": "sorceress", "height": 1.6, "color": [0.85, 0.4, 0.3],
				"ai": "ranged", "role": "Glass cannon", "desc": "The biggest damage in the game and nothing else. One careless step and she is gone: keep her behind your team.",
				"spells": ["sorc_firebolt", "sorc_fireball", "sorc_frost_spike", "sorc_meteor", "sorc_blink"]},
		"necromancer": {"name": "Necromancer", "gender": "male", "hp": 150, "ap": 7, "mp": 4, "init": 100, "model": "necromancer", "height": 1.5, "color": [0.45, 0.25, 0.55],
				"ai": "ranged", "role": "Curses and poison", "desc": "Wears enemies down with poison and rot, roots them, slows them and steals their action points. Little burst, no healing.",
				"spells": ["necro_plague_bolt", "necro_rot", "necro_miasma", "necro_grasp", "necro_drain"]},
		"rogue": {"name": "Rogue", "gender": "female", "hp": 110, "ap": 7, "mp": 6, "init": 115, "model": "rogue", "height": 1.5, "color": [0.25, 0.3, 0.35],
				"role": "Assassin", "desc": "Vanishes until her next attack, then strikes for extra damage. Enemies can't see her, even next to her, until she attacks, is hurt, or one of them walks into her (which hurts them).",
				"spells": ["rogue_dagger", "rogue_ambush", "rogue_vanish", "rogue_shadow_step", "rogue_hamstring"]},
		"priestess": {"name": "Priestess", "gender": "female", "hp": 150, "ap": 7, "mp": 4, "init": 100, "model": "priestess", "height": 1.55, "color": [0.95, 0.9, 0.6],
				"ai": "support", "role": "Healer and support", "desc": "Heals, cleanses and blesses her team for extra action points. Her own damage is very low, and she cannot heal herself with Healing Touch.",
				"spells": ["priest_smite", "priest_heal", "priest_rain", "priest_bless", "priest_purify"]},
		"goblin": {"name": "Goblin", "gender": "male", "hp": 100, "ap": 7, "mp": 6, "init": 120, "model": "goblin", "height": 1.0, "color": [0.45, 0.7, 0.25],
				"ai": "ranged", "role": "Bomb thrower", "desc": "Fast, sneaky and reckless: bombs and dynamite hurt everyone around, friends included. Steals action points.",
				"spells": ["goblin_sling", "goblin_bomb", "goblin_pickpocket", "goblin_scamper", "goblin_dynamite"]},
		"wraith": {"name": "Wraith", "gender": "neutral", "hp": 115, "ap": 7, "mp": 5, "init": 112, "look": "ghost", "color": [0.55, 0.4, 0.8],
				"role": "Spirit", "desc": "Shrugs off most physical attacks, but holy light burns it. Drains life, chills and terrifies.",
				"spells": ["wraith_touch", "wraith_wail", "wraith_phase", "wraith_siphon", "wraith_chill"],
				"resist": [["physical", 70], ["holy", -50]]},
		"monk": {"name": "Monk", "gender": "male", "hp": 140, "ap": 7, "mp": 6, "init": 108, "model": "monk", "height": 1.5, "color": [0.9, 0.55, 0.2],
				"role": "Skirmisher", "desc": "Quick on its feet: kicks in, pulls enemies close, sweeps them away and recovers on the spot.",
				"spells": ["monk_palm", "monk_dash", "monk_staff", "monk_hook", "monk_peace"]},
	}
