# Progression and balance quick wins (milestone 6c) — decisions

From the owner's playtests (floor 20 felt off, the level cap is reached too fast, area spells aren't worth casting, the Knight dies first). One light tuning pass with the balance lab, then tools for the owner to continue; no long simulation sessions. Observations are in [`docs/backlog.md`](../backlog.md) ("Balance observations from playtests").

| Decision | Choice | Why | Revisit when |
|---|---|---|---|
| Shape | One small milestone, **6c**, before milestone 7. Order: pin behavior and web audio fix, then the level cap and balance, then the missing sounds (the owner picks them by ear) | Small certain things first; tuning last | — |
| Level cap | **100** (`ProgressionConfig.level_cap`) | The owner asked for a very high cap | the tower and content grow past it |
| XP curve | One generated curve, `curve_coefficient × (L − 1) ^ curve_exponent` (8.0, 2.45), after the hand-set first levels (20, 50, 90); the two numbers are the pacing knobs | No authored numbers for 100 levels | pacing feels off |
| Level rewards past 10 | **Stats only, from a growth rule**: each hero's per-level HP and Power continue at the rate of its levels 2–10 (`HeroData` growth fields); **+1 MP at level 15, +1 AP at level 20**. Levels 2–10 stay hand-authored, untouched. New spells come with the spell loadout (milestone 8) | No authored content for 90 levels | the loadout milestone |
| Enemy level meaning | A level **N enemy is slightly weaker than a level N hero** (about 90 % of its stats), so early levels aren't a slaughter; enemy growth per level may exceed the heroes' so enemies keep up once runes are worn. Elites (×1.5 HP) stay clearly stronger than a normal enemy of their level; bosses stronger than elites | Levels must read the same on both sides | the balance lab says otherwise |
| Tower pace | Target: a hero reaches **level 10 around floor 25, level 20 around floor 60, level 30 around floor 100**; the floor bands' `enemy_level` follows that pace (a little behind, so enemies are slightly weaker). Floors from 10 have 3 enemies, 4–5 deeper | Escalation matches how fast a party levels | playtests |
| Knight durability | Higher HP growth per level and a small innate physical resistance for melee heroes. **No enemy AI change for now** | AI changes are bigger and riskier | the Knight is still singled out |
| Area spells | Raise area spells' damage per target so that hitting **2 enemies beats two single-target casts by about 30 %**; more enemies per floor (above); AP costs stay | An area spell on a lone enemy stays a bad deal on purpose | — |
| Stage difficulty | A stage is a **boss fight** (boss preset) at the enemy level of a floor **halfway between the floors below it and the floors it unlocks**: `difficulty_floor = unlocks_cap − 5` (stage 1 → 15, stage 2 → 25, stage 3 → 35: harder than floors 11–30, easier than the boss-like floors above). Not an elite fight | The owner's rule: between the floor it follows and the next block | playtests |
| Pin on attack | A click that casts a spell or moves **never pins** a card; a click that does nothing else still pins; hover is unchanged | Pinning while attacking was unwanted noise | — |
| Missing sounds | Cast: a default per damage type with an optional per-spell override (`SpellData.cast_sound`); death: a soft thud; victory: a different jingle; turn start: stays silent. CC0 candidates in a sampler, the owner picks by ear | Reuses the safe-intake routine | — |
| Web audio | The web build was silent. Likely cause: Godot's default web **sample playback** with runtime-created buses and runtime-set loops. Switch the web build to **stream playback** (`audio/general/default_playback_type.web = 0`): all features work, a little more latency | Can't be verified from the CLI: the owner tests the published page; fallback ideas below | audio plays |

## Outcome of the tuning pass (numbers in the data, checked by `tests/test_balance_rules.gd`)
- **Pace** (first climb, every floor cleared): hero level at the start of floor 25 = 10, floor 60 = 19, floor 100 = 31 (targets 10 / 20 / 30). Before: level 10 at floor 16, level 20 at floor 33.
- **Tower bands** (enemy level at the band's first floor, per-floor growth, enemies): f1 L1 ×1–2 · f5 L1 +0.3 ×2 · f10 L2 +0.4 ×3 · f25 L8 +0.31 ×3 · f40 L12 +0.30 ×4 · f60 L18 +0.28 ×4 · f80 L23 +0.28 ×5 · f100 L29 +0.25 ×5. Enemy level ends 1–2 levels behind the party's (equal from floor ~100).
- **Enemy growth equals the heroes'**: Brute 4 HP / 2 Power per level (Knight 5 / 2), Archer 3 / 4 (Ranger 3 / 4); a level N enemy is 75–100 % of the matching hero's HP and no more than its Power.
- **Knight**: base HP 44 (was 40), +5 HP per level (was 4), 10 % innate physical resistance.
- **Area spells** (damage per target, AP): Fireball 5–7 at 3 AP (was 6–8 at 4), Volley 4–5 at 3 (was 4–6 at 4), Whirlwind 6–8 (was 5–7), Piercing Thrust 6–8 at 3 AP (was 6–9 at 4). Per turn (6 AP) an area spell on 2 targets deals ≥ 1.25× the best single-target loop and stays below it on 1 target.
- **Stages** (boss preset at floor `unlocks_cap − 5`): Ruined Gate 15, Sunken Crypt 25, Sky Bastion 35 (the one that unlocks the cap of 40). Previously 10 / 20 / 30.
- **Balance-lab check** (AI party, a lower bound; heroes at level 5 from floor 11, progress kept across 10 runs): reaches floors 12–19, loses mostly on elite floors (15, 17) and the floor 20 boss. First climb from floor 1: 10 of 12 runs clear floor 10.

## Sounds chosen by ear
Fire cast (Firebolt): rubberduck's `spell_fire_01`; Fireball: its own sound (Julien Matthey, event `cast_fireball`, set by `SpellData.cast_sound`); physical cast: a swish; poison: slime; generic cast: `magical_1`; death: `creature_die_01` (found heavy, so set 12 dB down); victory: cynicmusic's "Victory Fanfare Short" (a JRPG-style fanfare); turn start stays silent. Sources and hashes in `assets/audio/SOURCE.md`.

## Saves
The game is in beta: **no backward compatibility is kept** for saves. The XP curve changed, so a save from before milestone 6c recomputes each hero's level from its XP and may show a lower level (delete the save, or accept it). A migration was written and then removed at the owner's request.

## Open / deferred
- Gains of the new sounds were set without hearing them in the game; adjust `sfx_gain_db` in `data/audio/audio_set.tres`.
- If stream playback is still silent: log the AudioContext state, try creating the audio buses in a bus layout resource instead of in code, and set loops at import time.
- Hero growth beyond the tower's reach (cap 100 vs floors up to 40 for now): more stages extend it.
