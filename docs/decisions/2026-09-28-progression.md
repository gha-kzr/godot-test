# Progression model (milestone 2) — decisions

Milestone 2 of [`docs/roadmap.md`](../roadmap.md). Builds on the slice record ([`2026-09-27-tactical-rpg-slice.md`](2026-09-27-tactical-rpg-slice.md): single-player, 3D, GDScript, content as `.tres`, rules separate from display, saving between battles) and the status record ([`2026-09-28-status-effects.md`](2026-09-28-status-effects.md): modifier stack read on demand, `StatModifier`).

| Decision | Choice | Why | Revisit when |
|---|---|---|---|
| Scope | A system the design tools (M3), the run loop (M4) and polish (M5) build on | Roadmap | — |
| What persists on death | Hero levels, XP and every item persist; only the run (depth, run-only rewards from M4) resets | Roguelite with kept progression (game direction); runaway power is handled by M4's difficulty curve | playtests show power creep M4 can't absorb |
| Party | A small roster: start with Knight and Mage; a third hero exists as data but stays **locked**; its unlock condition is decided in M4 (run depth, boss…). Battles use 2 heroes | Unlocks are a long-term goal; within the 2–3 hero scope guard | M4 run loop |
| New stats | **Power** (general) and **per-type Resistance**, on top of HP, AP, MP, initiative. Built to grow: a **per-type Power** will be added later as a second, distinct number in the damage formula | Readable; crit / dodge randomness deferred | per-type power, crit, dodge are wanted |
| Damage types | Data: one resource per type; every damage effect has a type. Milestone 2 types: **Physical, Fire, Poison** (matching current spells); more types (e.g. Ice) are new `.tres` with content that uses them | Evolutive: a new element needs no code | an element needs special rules |
| Power scaling | Percent, Dofus-style: damage and heals = roll × (100 + Power) / 100. Per-type Power will add to it later (assumed **additive**: 100 + Power + type Power) | Scales every spell proportionally; stays balanced as numbers grow | per-type power is designed |
| Resistance | Per damage type, a percent reduction, **capped at 50 %**; combines with the existing damage-taken modifiers (Guard, Crippled) | Nothing becomes immune | balancing pass |
| XP | Each enemy gives XP on death (field on the enemy, edited by the M3 enemy designer). XP, level-ups and loot are all **resolved at the end of a won fight**; each hero gets the **full total**, fallen heroes included | Heroes stay level with each other; no loss for dying in a won fight | — |
| Losing a fight | Gives nothing from that fight; everything from earlier fights is kept | Each fight matters without erasing progress | — |
| Levels | Cap **10** for now (raised as content grows); automatic growth (+HP, +Power) each level; the **4th spell at level 3** and **+1 MP at level 6** (revised from the assumed "spells at 3 and 6": kits are capped at 4 spells and heroes start with 3); the XP curve is a tuning value | Enough to test the loop | content grows |
| Architecture | **Permanent modifier sources**: levels and runes become `StatModifier`s a battle unit carries all fight, summed with status modifiers; a **game root scene** owns the profile and swaps party screen ↔ battle (no autoload) | Reuses the milestone 1 modifier stack; the party screen can explain every number; tests need no global state | — |
| Hero identity | Heroes grow differently per level (Knight +4 HP / +2 Power, Mage +2 HP / +5 Power, Ranger +3 / +4) and the Mage hits harder from range (Firebolt 7–10, Fireball 6–8): the Mage is a glass cannon, not just a weaker Knight | Playtest: the Mage felt less resistant *and* less powerful | balancing pass (M4) |
| Innate modifiers | `UnitData.innate_modifiers` apply to a unit in every battle, summed with statuses, levels and runes. Enemies use them for resistances: Brute +20 % Physical (counters the Knight), Archer +20 % Fire (counters the Mage). The HUD always shows Power and resistances ("Resist none" when there are none) | Enemies need stats too (the M3 enemy designer edits them); hidden zeros read as missing information | — |
| Level rewards | A **data table** per hero: rewards per level (stat modifiers, spell unlocks), so a skill / passive tree can later replace or extend it without battle-code changes | Evolutive, as asked | a skill / passive tree is designed |
| Items | **Runes**: 6 universal slots per hero (no weapon / armor, no class-specific items); hand-made, fixed stats, a rarity; stat modifiers only in M2 (the data can hold other effects later) | Simple, build-friendly; special effects are their own feature later | rune special effects are wanted |
| Rarity | Common, rare, epic, legendary; sets drop weight and color. **Common and rare runes stack** (a hero may equip copies); **epic and legendary are unique per hero** | Builds without "six copies of the best rune" | balancing pass |
| Storage | One shared stash for the party | Simple | — |
| Loot | Each enemy has a loot table (field on the enemy, edited by the M3 tool); drops are resolved when a battle is won | Consistent with XP | — |
| Party screen (first version) | Heroes, levels, stats, runes, stash; reachable before a battle and from the result screen. Game flow: party screen → battle → result → party screen; the game boots into the party screen. **To be revamped** in M5 | Needed to use levels and runes | UI polish (M5) |
| Saving (first version) | One automatic profile: a versioned JSON file in the user folder (hero XP, runes, stash, unlocks and party, all resources referenced by path), written when a battle ends and after rune changes; a missing save starts fresh; an unreadable one is moved aside (`.bak`) and play starts fresh; one from a newer version is left untouched and not overwritten. Run saving stays in M4; improvable later | Progression must survive quitting, and a bad load must never destroy it | M4 run saving, more profiles; uid references when M3 tools rename files |

## Open / deferred
- Per-type Power — later; the formula keeps room for it (assumed additive with general Power).
- Crit / dodge, rune special effects, random rune stats — later, on the same models.
- Skill / passive tree — later; replaces or extends the level reward tables.
- Third hero's unlock condition — M4.
- Ice and other damage types — with content that uses them.
