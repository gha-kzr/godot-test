# PvP classes (multiplayer balancing milestone)

## Why
The three single-player heroes at "level 30" made poor PvP classes: the Knight had no way to move or to make others
move, Power and resistances meant nothing (nobody can change them in a match), and the numbers hid behind Power.
PvP gets its own roster, authored for 1v1 up to 4v4.

## Decisions
- **PvP classes are separate from the single-player heroes** (`data/pvp/**`, `PvpHero` + `PvpRoster`). A class is a
  unit with five spells at fixed strength: no levels, no runes, no Power (a test forbids innate Power). The numbers on
  the spells are what the player sees. The lobby and the fight never show Power or resistances (unit cards hide them).
- **Source of truth while balancing: `scripts/tools/pvp/pvp_class_specs.gd`.** `tools/build_pvp_classes.gd` writes the
  `.tres` files from it (a rebuild keeps UIDs; run `tools/fill_uid_refs.gd` after). The files stay ordinary resources
  (tweakable in the Inspector); a rebuild overwrites them. Spells borrow the look and sound of an existing spell.
- **Nine classes**, each with one clear job and one clear weakness:
  Knight (bruiser: Charge, Shield Bash, Guard, Whirlwind), Ranger (kiting sharpshooter: marks, slows, Backslash),
  Sorceress (glass cannon: the biggest numbers, 85 HP, Blink), Necromancer (poison and rot over time, root, slow,
  action-point drain, no healing), Rogue (Vanish, then an Ambush for +80 %), Priestess (healer and booster: heals allies
  only, Mending Rain, Blessing +1 AP, Purify; very low damage), Goblin (bombs and dynamite that hurt friends too,
  Pickpocket steals an AP, Scamper), Wraith (70 % physical resistance and -50 % holy; frost and drain), Monk
  (skirmisher: dash, push, pull, self-heal). Female classes: Sorceress, Rogue, Priestess.
- **Placeholders:** Knight, Ranger, Sorceress (the Mage's model) and Wraith (the Ghost's) reuse single-player models;
  the other five are coloured capsules until their models are built (`UnitData.model_scene`).
- **Stealth** (new rule, `StatusData.stealth`): a unit carrying it is hidden from the other team unless an enemy
  stands next to it. Spells that require an enemy target can't pick it, the AI never aims at it, the other team's
  screen doesn't draw or let it be clicked. It ends when the carrier casts an offensive spell, or is hurt (poison
  included). Area spells aimed at the right cell still hit it. Hiding is a rule and a display choice only: every peer
  holds the whole state (nothing in this design is secret from a modified client).
- **Other new pieces:** `CleanseEffect` (remove harmful or helpful statuses), `DamageEffect.ambush_bonus_percent`
  (extra damage while the caster is hidden), `SpellData.is_offensive()`, `PvpHero.ai_positioning` (the AI keeps
  ranged classes at range and the healer near allies; it also drives the AI taking over a player who left).
- **Support classes are weak alone, on purpose.** A healer that can heal itself fully stalls any 1v1; Healing Touch
  therefore targets allies only. The target is 40 to 60 % in team games; 1v1 may spread wider for kits made for teams.
- **Duplicates are allowed** (two Knights in a team is fine); a stacking limit can come later if it proves a problem.

## Balance process
`tools/pvp_balance.gd` plays AI-vs-AI matches on the real rules and maps (`PvpSimulator`): `duel` (1v1 matrix of every
class against every class) and `teams2` / `teams3` / `teams4` (random teams, win rate per class). One tuning pass was
made with it (numbers in the spec file); after that it is a tool for the next pass. The AI plays worse than a person
(no plan over two turns, never holds a stealth on purpose, cannot kite perfectly), so classes built on tricks (Rogue,
Necromancer, Ranger, Priestess) read lower than they play; the point is to catch a class far from the others.

## Not done
- Models and animations for the new classes; per-class sounds; real spell effects (they borrow other spells').
- Per-class tutorials or a "class guide" screen beyond the card and the (i) popup.
- A team-composition check (e.g. refuse five healers); duplicate limits.
