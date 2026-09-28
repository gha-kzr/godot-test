# Progression model (milestone 2) — implementation plan

Decisions: [`docs/decisions/2026-09-28-progression.md`](../decisions/2026-09-28-progression.md). Roadmap: [`docs/roadmap.md`](../roadmap.md), milestone 2.
Architecture: **A + C** — levels and runes are **permanent modifier sources** on battle units (the milestone 1 modifier stack, extended to non-expiring sources); a **game root scene** owns the profile and swaps between the party screen and the battle (signals up, calls down, no global state).

## Design summary

### Data (`scripts/data/`, `.tres` content)
- `DamageType` — `display_name`, `color`. `data/damage_types/{physical,fire,poison}.tres`. `DamageEffect.damage_type`.
- `StatModifier.Stat` grows (existing values unchanged): `POWER`, `RESISTANCE_PERCENT` (with `damage_type`), `MAX_HP`, `INITIATIVE`. A later per-type power is one more stat using `damage_type`.
- `RuneData` — `display_name`, `rarity: Rarity { COMMON, RARE, EPIC, LEGENDARY }`, `modifiers`; epic and legendary are unique per hero; rarity sets drop weight and color.
- `LootTable` — `rolls`, `drop_chance`, `runes` (a roll that drops picks a rune weighted by rarity).
- `UnitData` gains `xp_reward` and `loot_table` (enemy fields; the M3 enemy designer edits them).
- `LevelReward` — `modifiers`, `spells` (unlocked at that level). `HeroData` — `unit: UnitData` (base template and kit), `level_rewards: Array[LevelReward]` (index 0 = reaching level 2). `ProgressionConfig` — `level_cap`, `xp_thresholds` (total XP per level). `Roster` — `heroes`, `starting_party`, `starting_unlocked`.

### Battle rules (`scripts/battle/`)
- `UnitState.permanent_modifiers` (levels + runes, never expire) join status modifiers in `stat_bonus(stat, damage_type)`; `max_hp()`, `initiative()`, `power()`, `resistance_percent(type)` (capped 50 %). HP starts at `max_hp()`; heal caps, turn order, HUD, AI use the accessors, not `data.*`.
- `BattleState.create(map, players, enemies, seed, player_modifiers := [])`.
- Damage = roll × (100 + caster power) / 100 × damage taken % / 100 × (100 − resistance %) / 100, rounded once. Heals = roll × (100 + power) / 100. `DamageEffect` / `HealEffect` expose the expected amount for the AI.
- `BattleRewards.compute(state)` — on a player win: XP = sum of dead enemies' `xp_reward`; loot rolled from their loot tables with an RNG seeded from the battle.

### Progression (`scripts/progression/`, plain data)
- `HeroRecord` — hero, level, xp, 6 rune slots; `modifiers()` (level rewards + runes), `spells()` (kit + unlocks), `battle_unit_data()`.
- `Profile` — roster records, unlocked heroes, party, stash; `equip` / `unequip` (stacking rules), `apply_rewards(rewards) -> Array[LevelUp]` (full XP to each party hero, level cap), `to_dict()` / `from_dict()` (resources by path, versioned).
- `SaveStore` — `user://profile.json`; missing or unreadable → a fresh profile, never a crash.

### Game flow (`scripts/game/`, `scenes/game.tscn` = main scene)
- `Game` owns profile + save store; shows `PartyScreen` → on start, builds and configures `battle.tscn` (`BattleController.setup(...)` before it enters the tree) → on `battle_finished`, computes rewards, applies, saves, shows the party screen with a summary.
- `BattleController`: `setup()` for injected battles; standalone `battle.tscn` still works from its exports. Result button: "Continue" when run by `Game`, "Play again" standalone.
- `PartyScreen` — heroes (third one locked), level / XP, stats (HP, AP, MP, initiative, Power, resistances), 6 rune slots, stash, reward summary, Start battle. Reads the profile to display; changes go up as signals (`start_pressed`, `equip_requested`, `unequip_requested`) and `Game` applies them.

## Tasks

Each task ends with: `--check-only` on edited scripts, headless tests green (plus mutation checks on new tests), a commit of explicit paths.

- [x] **Task 1: Damage types, new stats, damage formula** — `DamageType`; `StatModifier` new stats + `damage_type`; `UnitState.permanent_modifiers` and accessors; `BattleState.create` player modifiers; formula for damage and heals; replace `data.max_hp` / `data.initiative` reads; AI status valuation uses the formula; damage types on all content effects.
  Pattern: modifier stack read on demand (sources: statuses + permanent); data-driven damage types.
  Tests: power scales damage and heals; resistance per type, capped; combined with damage taken; max HP / initiative modifiers; untyped damage ignores resistances; AI values scaled ticks.

- [x] **Task 2: Runes, loot tables, battle rewards** — `RuneData`, `LootTable`, enemy `xp_reward` / `loot_table`, `BattleRewards.compute`.
  Pattern: data-only resources with validation; seeded RNG for deterministic loot.
  Tests: XP sums dead enemies; nothing on defeat / draw; loot deterministic per seed, weighted by rarity; validation.

- [x] **Task 3: Hero progression and profile** — `LevelReward`, `HeroData`, `ProgressionConfig`, `Roster`, `HeroRecord`, `Profile`.
  Pattern: plain-data model (RefCounted) separate from battle state; content resources shared read-only.
  Tests: XP → levels (multi-level jumps, cap); rewards accumulate; spells unlock; equip / unequip, stacking vs unique, full slots; party battle build (modifiers + spells + HP).

- [x] **Task 4: Save store** — versioned JSON round trip; robust load.
  Pattern: explicit serialization of plain data (resources referenced by path), versioned format.
  Tests: round trip; missing file, corrupt JSON, unknown resource paths, future version → fresh or partial profile without crashing.

- [x] **Task 5: Content** — damage types on spells and statuses; ~8 runes across rarities; loot tables and XP on Brute / Archer; hero data (Knight, Mage, and a locked Ranger) with level tables (+HP / +Power per level, 4th spell at level 3, +1 MP at level 6); the new level-3 spells; roster and config.
  Pattern: data-only `.tres`, generated once with `ResourceSaver`.
  Tests: all content validates; AI-vs-AI slice balance unchanged; hero builds at levels 1 / 3 / 6.
  Done: runes Might (+8 Power), Vitality (+6 HP), Quickness (+10 initiative) — common; Stone Skin (+20 % physical), Fire Ward and Venom Ward (+25 %) — rare; Swiftness (+1 MP) — epic; Focus (+1 AP, +5 Power) — legendary. Brute 15 XP, Archer 12 XP, each a 60 % drop from all runes. Heroes: +3 HP / +3 Power per level, +1 MP at 6; level-3 spells Whirlwind (Knight, enemies around it), Regeneration (the Mage's 4th spell moved from its base kit to its level-3 unlock, keeping the 4-spell cap), Hamstring (Ranger, hit + Crippled). The Ranger (Arrow, Volley, Poison Arrow) starts locked. Slice AI-vs-AI over 20 seeds: 14–6.

- [x] **Task 6: Game root and battle injection** — `Game` scene (main scene), `BattleController.setup()` / `battle_finished`, result button text, rewards applied and saved after a battle.
  Pattern: root scene swapping child screens; dependency injection before `_ready`; signals up, calls down.
  Tests: a won battle grants XP / loot and saves; a lost one grants nothing; standalone battle still works.

- [x] **Task 7: Party screen** — heroes, stats, rune slots, stash, reward summary, start button; equip / unequip through `Game`.
  Pattern: Control containers; screen reads the profile, emits signals, `Game` mutates.
  Tests: shows party and locked hero; equip / unequip via signals with rule errors surfaced; summary after a battle; render check.

- [x] **Task 8: Stats in battle HUD** — Power and resistances in the unit and inspect panels.
  Pattern: plain info values to the HUD.
  Tests: info carries the new stats; panels show them.

- [x] **Task 9: Review and polish** — `godot-code-review` subagent; fixes; README (party screen, runes, progression, adding a rune / hero); docs kept current.
  Done (review fixes): an unreadable save is moved aside (`profile.json.<time>.bak`) instead of being overwritten by the fresh profile, and a save from a newer version is never overwritten (the store turns read-only); malformed fields are skipped instead of raising script errors; party and unlocks are saved as hero paths (save version 2, version 1 still read), so reordering or extending the roster can't scramble saves, and new starting unlocks reach old saves; duplicate party entries dropped; rewards are applied and saved when the battle ends (`battle_ended`), not on Continue, so closing the game on the result screen loses nothing; a party that can't fit the map, a battle that fails to start, and save failures are reported on the party screen; write errors keep the previous save; `StatModifier` types match exactly and a type on a non-per-type stat is a validation error (a later per-type power gets its own `Stat`); statuses can't change MAX_HP / INITIATIVE yet (validation), heals never go negative; stash tooltips show the rune's stats; tests clean up `user://`.
  Deferred from the review: uid-based save references and shared loot-table resources → M3 (design tools); balance — heroes out-level the fixed encounter (AI-vs-AI 14–6 at level 1, 20–0 from level 6; 6× common Might beats all level rewards; 3× Stone Skin caps physical resistance) → M4 difficulty curve; recovering a `.tmp` save after a crash mid-rename (Windows) and multiple profiles → M4 run saving; keeping the selected hero across screens, spells in the level-up summary → M5.

## After the milestone (playtest)
- The Mage felt weaker than the Knight in every way: heroes now grow differently (Knight +4 HP / +2 Power, Mage +2 HP / +5 Power, Ranger +3 / +4) and Firebolt / Fireball hit harder (7–10, 6–8).
- Enemy resistances weren't visible because enemies had none: `UnitData.innate_modifiers` (always-on stats) added; Brute +20 % Physical, Archer +20 % Fire; the HUD always shows Power and resistances.
- AI-vs-AI on the standalone slice: 6–14. The measure is noisy around Firebolt's damage: when its average falls below Mend's average heal, the AI's Mage spams Mend instead of attacking (8–10 gave 19–1, 7–10 gives 6–14). A human plays the Mage differently; real balancing is M4's difficulty curve.
