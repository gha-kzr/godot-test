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
| — | Web build | A single-threaded web export published on GitHub Pages (`tools/export_web.sh --publish` builds and commits the `gh-pages` branch) | `README.md` |

## Next milestones (proposed)

The backlog grouped into milestones, in the order I would build them: each follows the ones whose systems it needs and ends in something playable on its own. The order can change if priorities do. Full descriptions and open questions are in [`backlog.md`](backlog.md); each milestone starts with a grill and a plan, like the finished ones.

### 7. First impressions

What a new player meets first, and what shows the game off: comfort in long battles, a real onboarding, a name, a visible best floor and achievements. New texts written here go through `tr()` and get their French entry (see `README.md`, Translations).

| Feature | Category | Pairs with |
|---|---|---|
| [Sound and animation leftovers](backlog.md#sound-and-animation-leftovers) | Audio / animation | audio set, unit model |
| [Selecting an enemy to attack also pins its card](backlog.md#selecting-an-enemy-to-attack-also-pins-its-card) | UI / UX | unit card pinning |
| [Battle speed and quality of life](backlog.md#battle-speed-and-quality-of-life) | UI / UX | event player timings, settings |
| [Better tutorial and tooltips for the first levels](backlog.md#better-tutorial-and-tooltips-for-the-first-levels) | UI / UX (onboarding) | hints, first floors |
| [Rename the game](backlog.md#rename-the-game) | Branding | repo name, Pages address, save folder |
| [Max floor reached and achievements](backlog.md#max-floor-reached-and-achievements) | Meta / UI | profile; feeds meta progression |

### 8. Hero depth

Deepens the tactics before content scales up: the spell loadout, a higher level cap (which needs the loadout for its new spells), movement spells and undo. Enemy AI must learn to value positions for the movement spells, which later milestones rely on.

| Feature | Category | Pairs with |
|---|---|---|
| [Choosing active spells (5-spell loadout)](backlog.md#choosing-active-spells-5-spell-loadout) | Gameplay | level cap, hub, spell bar |
| [Increase the level cap](backlog.md#increase-the-level-cap) | Gameplay / balance | loadout, rewards content, balance |
| [Movement spells: teleport, jump and more](backlog.md#movement-spells-teleport-jump-and-more) | Gameplay | height rules, enemy AI, enemy roles |
| [Undo a move](backlog.md#undo-a-move) | Gameplay | command actions |

### 9. Encounters

Smarter, more varied fights: enemy roles with predefined team compositions (needs new enemy content and AI that handles movement spells) and bigger maps with enough enemies to fill them.

| Feature | Category | Pairs with |
|---|---|---|
| [Enemy roles and team compositions](backlog.md#enemy-roles-and-team-compositions) | Content / gameplay | new enemies, AI profiles, biomes |
| [Bigger maps](backlog.md#bigger-maps) | Gameplay / content | props, map types, balance, AI speed |

### 10. World

Makes levels look and play differently: props and floor types, map typologies from noise, and biomes that change every few floors (a biome picks a look, map types and enemy pools from the previous milestones).

| Feature | Category | Pairs with |
|---|---|---|
| [More props and floor types](backlog.md#more-props-and-floor-types) | Art / content | biomes, bigger maps |
| [Map typologies from noise](backlog.md#map-typologies-from-noise) | Content / procedural | bigger maps, biomes |
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

Widens who can play, once screens and strings have settled: save slots, gamepad support and Android / touch.

| Feature | Category | Pairs with |
|---|---|---|
| [Multiple games (save slots)](backlog.md#multiple-games-save-slots) | Core / profile | save format |
| [Gamepad support](backlog.md#gamepad-support) | Platform | focus navigation already on screens |
| [Android and touch](backlog.md#android-and-touch) | Platform | camera drag already shaped for it |

### 14. Balance and release

The final pass when content stops moving: a balance pass with the balance lab, an export filter, UID checks in a real export and a golden test on generated floors.

| Feature | Category | Pairs with |
|---|---|---|
| [Balance observations from playtests](backlog.md#balance-observations-from-playtests) | Balance | level cap, area spells, tower bands |
| [Balance pass and release checks](backlog.md#balance-pass-and-release-checks) | Balance / release | content stable |

