# Roadmap

**Goal:** a small but polished tactical roguelite. A run is a series of procedural battles (maybe endless); on death the run restarts from scratch, but the player keeps level and loot.

**Done:** the tactical RPG vertical slice — see [`plans/2026-09-27-tactical-rpg-slice.md`](plans/2026-09-27-tactical-rpg-slice.md). Its "After the slice" section holds the detailed design notes referenced below.

**Scope guard:** the first release stays small (one biome, 4–6 enemy types, ~10 spells, 2–3 heroes, a short run) and polished; everything that widens it (biomes, more heroes and enemies, branching runs) is in the backlog below.

Each milestone starts by settling its open decisions (`godot-grill`), then a plan (`godot-brainstorming`), then implementation task by task, then a `godot-code-review` pass. Decisions are in `decisions/`, plans in `plans/`.

## Done

| # | Milestone | What it brought | Decisions · plan |
|---|---|---|---|
| 0 | Vertical slice | A turn-based tactical battle on a heightmap grid: movement with climb costs, line of sight, spells with areas, an AI, the hover and click picking | [plan](plans/2026-09-27-tactical-rpg-slice.md) · [decisions](decisions/2026-09-27-tactical-rpg-slice.md) |
| 1 | Combat depth | Status effects (damage and heal over time, buffs, debuffs), AI that values statuses, inspect any unit | [decisions](decisions/2026-09-28-status-effects.md) · [plan](plans/2026-09-28-status-effects.md) |
| 2 | Progression model | Stats, levels and XP, spell scaling, runes (equipment) and loot | [decisions](decisions/2026-09-28-progression.md) · [plan](plans/2026-09-28-progression.md) |
| 3 | Design tools | An editor plugin: spell and enemy previews, the Design panel, the balance lab | [decisions](decisions/2026-09-29-design-tools.md) · [plan](plans/2026-09-29-design-tools.md) |
| 4 | Run loop | The roguelite: an infinite tower of generated floors, stages, boons, saved runs, procedural maps and encounters | [decisions](decisions/2026-09-29-run-loop.md) · [plan](plans/2026-09-29-run-loop.md) |
| 4.5 | Allies and placement | Walking through allies, a placement phase before each battle | [decisions](decisions/2026-09-29-allies-and-placement.md) · [plan](plans/2026-09-29-allies-and-placement.md) |
| 5a | Battle UI revamp | HUD components (timeline, cards, spell bar), event-driven HUD, status icons, exact damage preview, path costs, prompt line | [decisions](decisions/2026-09-30-ui-revamp.md) · [plan](plans/2026-09-30-battle-ui.md) |
| 5b | Screens | Title, settings (window, UI scale, key rebinding, credits), hub, run screen, first-run hints, keyboard navigation | [decisions](decisions/2026-09-30-screens.md) · [plan](plans/2026-09-30-screens.md) |
| 5c | Gameplay rules pass | Obstacles as cubes blocking sight up to their top, runes changeable between floors, leave a fight | [decisions](decisions/2026-09-30-gameplay-rules.md) · [plan](plans/2026-09-30-gameplay-rules.md) |
| 5d | Playtest polish | Camera pan, recenter and follow, focus a unit from the turn order, XP gain display, drop a rune | [decisions](decisions/2026-09-30-playtest-polish.md) · [plan](plans/2026-09-30-playtest-polish.md) |
| 6a | Art pass | Quaternius character models with a shared animation set, toon board with rock obstacles, particle effects, elite and boss scale | [decisions](decisions/2026-10-01-art.md) · [plan](plans/2026-10-01-art.md) |
| 6b | Feel and language | French translation (gettext, extraction tool, tests), audio (sound effects, hub / battle / boss music, volume settings), camera follows walking units, screen shake and status auras, per-spell projectiles, timing and effects, the spell stage | [decisions](decisions/2026-10-02-feel-and-language.md) · [plan](plans/2026-10-02-feel-and-language.md) |
| 6c | Progression and balance | Level cap 100 with a generated XP curve and growth rule, enemy levels that follow the party's pace, a sturdier Knight, area spells worth casting, stages between the floors around them, pin-on-attack fix, cast / death / victory sounds | [decisions](decisions/2026-10-02-progression-and-balance.md) · [plan](plans/2026-10-02-progression-and-balance.md) |
| 7 | First impressions | Battle speed and auto end turn, the web Click to start screen, a spotlight tutorial that waits for the player's actions (with a starter rune to learn equipping), one-time tips and glossary tooltips, best floor and achievements, victory cheers, the rename to Rune Ascent and branding slots | [decisions](decisions/2026-10-02-first-impressions.md) · [plan](plans/2026-10-02-first-impressions.md) |
| 8 | Hero depth | A 5-spell loadout chosen on the party screen, three new spells per hero (levels 5, 9, 14), movement spells (teleport, charge, push, pull, Backslash's leap back), spell cooldowns, free repositioning until a cast (instead of undo), Holy and Frost, resistance caps 75 % / 100 %, the Skeleton Archer, Ghoul and Ghost replacing the Archer | [decisions](decisions/2026-10-03-hero-depth.md) · [plan](plans/2026-10-03-hero-depth.md) |
| 9a | Encounters | Enemy roles (tank, bruiser, ranged, support, skirmisher) with a positioning AI that can't kite for ever, four new enemies (Orc Guard, Mushroom Sage, Warg, Yeti), sixteen team compositions, the first stage after tower floor 10 | [decisions](decisions/2026-10-04-encounters.md) · [plan](plans/2026-10-04-encounters.md) |
| 9b | Bigger maps | Map sizes per band (9–11 up to 15–18, never bigger), six map typologies from seeded noise (open field, mountain, crater, islands, canyon, ruins), enemies a bounded walk away, a camera that fits the board | [decisions](decisions/2026-10-04-maps.md) · [plan](plans/2026-10-04-maps.md) |
| 9c | QA tools | A QA switch: a floor browser with map previews, a playground, a quick team, profile tools, Auto (the AI plays the heroes) and cheats in QA battles that never touch the save | [decisions](decisions/2026-10-05-qa-tools.md) · [plan](plans/2026-10-05-qa-tools.md) |
| 9d | Own models | Every hero, enemy, weapon and board rock built in the project from flat-shaded low-poly solids on named joints, with procedural animations (idle, walk, attack, cast, hit, death, victory, defeat); no downloaded 3D model left; a model stage to preview them | [decisions](decisions/2026-10-05-own-models.md) |
| — | Web build | A single-threaded web export published on GitHub Pages (`tools/export_web.sh --publish` builds and commits the `gh-pages` branch) | `README.md` |

## Next milestones (proposed)

The backlog grouped into milestones, in the order I would build them: each follows the ones whose systems it needs and ends in something playable on its own. The order can change if priorities do. Full descriptions and open questions are in [`backlog.md`](backlog.md); each milestone starts with a grill and a plan, like the finished ones.

### 9e. Model workshop

Makes the hand-built models easy to refine without a code change: tweaks (part positions, sizes, colors, joint rest poses) kept in a file next to each model and re-applied when the draft is rebuilt, clips as editable pose tables, and a workshop scene with sliders, a pose scrubber and live reload. Also the animation upgrades the first drafts lack (easing, follow-through, anticipation, two-segment limbs) and, if wanted, richer solids for more detailed creatures.

| Feature | Category | Pairs with |
|---|---|---|
| [Model workshop](backlog.md#model-workshop) | Tools / art | own models (9d), spell stage |
| [Better animations](backlog.md#better-animations) | Animation | clip sets, model workshop |

### 10. World

Makes levels look and play differently: props and floor types (with see-through props and walls, so units stay visible), more map typologies (terraces, mazes, ridge lines; six exist since 9b), and biomes that change every few floors (a biome picks a look, map types and enemy pools from the previous milestones).

| Feature | Category | Pairs with |
|---|---|---|
| [More props and floor types](backlog.md#more-props-and-floor-types) | Art / content | biomes, bigger maps |
| [See-through props and walls](backlog.md#see-through-props-and-walls) | Art / camera | props, ruins, camera |
| [More map typologies](backlog.md#more-map-typologies) | Content / procedural | bigger maps, biomes |
| [Biomes that change every X floors](backlog.md#biomes-that-change-every-x-floors) | Content | props, map types, enemy roles |

### 11. Loot depth

Makes runes interesting and manageable: sets and power tiers, and the answer to the stash piling up (sell, fuse or cap), which settles whether the game has a currency.

| Feature | Category | Pairs with |
|---|---|---|
| [Rune sets and rune power tiers](backlog.md#rune-sets-and-rune-power-tiers) | Gameplay / content | save format, loot, hub |
| [Rune economy: sell, fuse, stash cap](backlog.md#rune-economy-sell-fuse-stash-cap) | Core loop | a currency decision; meta progression |

### 12. Run structure and meta

Gives runs a shape and lasting value: meta progression (needs the currency decided in Loot depth) and the branching run map (needs events and items to put on its nodes). Both need a full grill first.

| Feature | Category | Pairs with |
|---|---|---|
| [Meta progression](backlog.md#meta-progression) | Core loop / meta | currency, achievements, new heroes |
| [Branching run map (to elaborate)](backlog.md#branching-run-map-to-elaborate) | Core loop | rune economy, meta progression; needs a full grill |

### 13. Reach

Widens who can play, once screens and strings have settled: better tooltips and more hints, a way to see status effects, save slots, gamepad support and Android / touch.

| Feature | Category | Pairs with |
|---|---|---|
| [Better tooltips and more hints](backlog.md#better-tooltips-and-more-hints) | UX / onboarding | first-run hints, glossary tooltips, localization |
| [Visualize status effects](backlog.md#visualize-status-effects) | UX / battle readability | statuses, unit cards, tooltips |
| [Multiple games (save slots)](backlog.md#multiple-games-save-slots) | Core / profile | save format |
| [Gamepad support](backlog.md#gamepad-support) | Platform | focus navigation already on screens |
| [Android and touch](backlog.md#android-and-touch) | Platform | camera drag already shaped for it |

### 14. Balance and release

The final pass when content stops moving: a balance pass with the balance lab, an export filter, UID checks in a real export and a golden test on generated floors.

| Feature | Category | Pairs with |
|---|---|---|
| [Balance observations from playtests](backlog.md#balance-observations-from-playtests) | Balance | level cap, area spells, tower bands |
| [Balance pass and release checks](backlog.md#balance-pass-and-release-checks) | Balance / release | content stable |
| [Sound and animation leftovers](backlog.md#sound-and-animation-leftovers) (or any milestone: it is small) | Audio / animation | audio set, unit model |

