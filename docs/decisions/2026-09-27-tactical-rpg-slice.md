# Tactical RPG vertical slice — decisions

A tactical RPG in the vein of Dofus / Disgaea. This slice is the foundation the real game grows from.

| Decision | Choice | Why | Revisit when |
|---|---|---|---|
| Scope | Vertical slice: foundation code, built to be extended | The real game grows from it; no throwaway rewrite | — |
| Game direction | A small but polished tactical roguelite: procedural runs of battles; on death the run restarts but level and loot are kept. Milestones in [`docs/roadmap.md`](../roadmap.md) | Replayability from generated content; persistent progression softens roguelike restarts | the core loop doesn't hold up in playtests |
| Authority | Single-player | No multiplayer planned | multiplayer is wanted |
| Language | GDScript | Project convention (README) | — |
| View | 3D, camera rotates in 90° steps + zoom, pitched 40°; **T** toggles a near-overhead view (75°) | Disgaea-like readability; fixed angles keep cell picking simple; 40° keeps one-level steps from hiding cells, overhead reveals anything else terrain hides | free rotation is wanted |
| Picking | Clicking a cell or a unit's body picks that cell (colliders on named `board` / `units` physics layers) | Units stick out above obstacles, so their body is the natural click target | — |
| Visuals | Plain shapes (boxes for cells, capsules for units); visuals isolated from rules | Swap in an asset pack later without touching combat code | an asset pack is chosen |
| Turn model | Dofus-style: one unit at a time, initiative order, AP/MP per turn | Simpler turn loop and AI; AP/MP drives spell costs and positioning | Disgaea-style team phases are wanted |
| Undo | Actions are command objects, so undo stays possible | Keeps Disgaea-style move undo cheap to add | undo is wanted |
| Height | Cells have elevation; it affects **movement** (climb cost, max climb), **line of sight**, and **range** (high-ground bonus) | Makes terrain tactical | damage bonus from height is wanted |
| Climbing (tuning) | A step climbs at most 1 level (+1 MP per level) and drops at most 2 levels (free) | High ground is easy to leave, hard to reach | per-unit jump stats are wanted (Disgaea-style) |
| Blocking | Every living unit blocks its cell, allies included. **Superseded** by [`2026-09-29-allies-and-placement.md`](2026-09-29-allies-and-placement.md): units walk through allies (they still can't end a move on one) | Dofus rule; positioning matters | — |
| High-ground range (tuning) | +1 max range per level above the target, capped at +2, only for spells with `height_extends_range` | Rewards high ground without making it dominant | balancing pass |
| Line of sight | 3D line from caster's eyes (cell + 1.5 levels) to target's body (cell + 1.0); cells rising above it block; obstacles block up to their top ("reopened" in `2026-09-30-gameplay-rules.md`; first version: always) and units always block, holes never; exact corners block only if both sides do. Cells in range but out of sight are shown faded while aiming | Heights match the drawn units (almost 2 levels tall): a one-level bump doesn't hide units on the same level, a two-level wall does, high ground sees over low walls. Tuned after playtesting (was 1.0 / 0.5, which blocked shots that visibly weren't blocked). Dofus-like unit blocking; permissive corners avoid arbitrary results | LoS feels too strict or too loose |
| Targets and areas | Any floor cell is targetable (empty ones too); obstacles and holes are not, but areas may cover them; areas can include the caster; areas ignore walls | Dofus rules; ground-targeted AoE; no odd height/LoS results from aiming at a hole | — |
| Mutual wipe | Both teams wiped out in one action = DRAW in the rules, shown to the player as a **defeat** | Single-player: "you didn't win"; no extra result screen | a distinct draw screen is wanted |
| Height → damage | Not in the slice | Pure number tuning; add as an effect rule later | balancing pass |
| Slice content | ~10×10 map with a few height levels, 2v2, 2–3 spells per unit (up to 4 from milestone 1, see `2026-09-28-status-effects.md`) (melee, ranged needing LoS, one AoE), initiative order, win/lose on team wipe | Exercises every core system once | slice is done |
| Enemy control | Simple AI: score candidate actions, pick the best | Grows into smarter AI instead of being replaced | AI feels too dumb |
| AI scoring | Weights live in an `AIProfile` resource (kill bonus, heal weight, friendly-fire weight; `data/ai/default.tres`); simulations use the **average roll, rounded down** | Profiles give per-battle difficulty without code changes; the average makes choices steady and never counts on a lucky roll | difficulty levels or smarter strategies are added |
| Content data | Units, spells, effects as Resource `.tres` files | Editable in the Inspector and as text via CLI; balance changes never touch code | content exceeds what `.tres` handles comfortably |
| Rules vs. display | Battle state and rules in plain data classes; nodes only render and animate | Headless-testable, AI can simulate moves, saving is easy later | — |
| Testing | Headless tests on the rules layer (`godot-gdscript-headless-testing`) | Foundation code needs a safety net | — |
| Saving | None in the slice. Planned **between battles** only, when leveling/loot exist | Nothing worth saving yet; plain-data state keeps it easy to add | leveling or loot is added |

## Open / deferred
Ordered into milestones in [`docs/roadmap.md`](../roadmap.md), which also lists the open design questions.

- Status effects (DoT, buffs, debuffs) — **first feature after the slice**; design notes in the plan.
- AI difficulty and smarter strategies — after the slice: harder profiles for later battles, a "mistakes" knob for easy ones, real kill odds instead of the average roll, focus fire (healers / dangerous units first), ranged units keeping their best range, avoiding cells where the player can kill them.
- Editor tooling — after the slice: preview the board in the editor (`@tool`), then an editor plugin to paint maps (heights, obstacles, holes, spawns) and save them as `.tres`. Design notes in the plan.
- Stalemates — if units can never reach each other the battle never ends. Map tests check connectivity; a turn limit or draw rule is undecided.
- Leveling, loot, inventory, save between battles — after the slice.
- Content design tools — a skill designer (area, power, scaling) and an enemy designer (level, stats, loot table, XP on death, difficulty presets). Notes in the plan.
