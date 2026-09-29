# Walking through allies and choosing starting positions (milestone 4.5) — implementation plan

Decisions: [`docs/decisions/2026-09-29-allies-and-placement.md`](../decisions/2026-09-29-allies-and-placement.md). Roadmap: [`docs/roadmap.md`](../roadmap.md).
Architecture: **A — placement is a rules phase before `Battle.start()`**: `BattleState.create` places heroes by role on the zone; a `Place` action (valid only before the start) moves or swaps heroes through `Battle.perform` and returns `UnitPlaced` events; the controller gains a `PLACING` state whose Ready starts the battle. The lab, tower sim, AI and `Game` keep using the default placement.

## Design summary

### Rules (`scripts/battle/`)
- `Movement.reach`: cells holding an enemy are skipped; cells holding an ally are walked through (the flood continues) but are never destinations. Paths may cross allies.
- `Placement` (plain class): `default_cells(grid, zone, enemy_spawns, heroes)`: zone cells sorted by walking distance to the nearest enemy spawn; heroes sorted by role (average spell `max_range`, lowest = melee); closest cells to the melee heroes.
- `BattleState.zone` (the map's `p` cells); `create` uses `Placement.default_cells`.
- `BattleActions.Place(unit_id, cell)`: before the start only (`BattleState.started`), a player unit, a zone cell; swaps with a hero on it. `BattleEvents.UnitPlaced(unit_id, cell)`, one per unit moved.

### Generation (`scripts/run/`)
- `MapGenerator.generate(rng, settings, enemy_count, is_boss, layout)`: `EDGE` (zone one row in from the bottom edge, enemies on the top rows), `CORNER` (zone in a bottom corner, enemies in the opposite corner), `AMBUSH` (zone in the centre, enemies on 2–3 sides). The zone is a 3 × 3 square of walkable cells within one level of each other; connectivity both ways; every zone cell ≥ `min_enemy_distance` (5) steps from every enemy spawn. Retries from the same RNG, then an open `EDGE` fallback.
- `MapGenSettings`: `edge_weight`, `corner_weight`, `ambush_weight`, `ambush_from_floor` (6), `min_enemy_distance` (5). `FloorGenerator` picks the layout from the floor's RNG.

### Display (`scripts/view/`)
- `BattleController`: `State.PLACING` after `start_battle()` (game and standalone); click a hero to select it, a zone cell to place it (swap if taken), Esc / right click to deselect; hover works as usual; Ready = the End-turn button relabelled "Ready (Space)" → `battle.start()`.
- `BoardView`: `Highlight.ZONE`; the selected hero's cell uses `PATH`.
- `EventPlayer`: `UnitPlaced` → a short hop of the unit view.
- `Hud`: placement banner; spell bar disabled while placing; End-turn button text.

## Tasks

Each task ends with: `--check-only` on edited scripts, headless tests green (plus mutation checks on new tests), `tools/fill_uid_refs.gd` after CLI-made resources, a commit of explicit paths.

- [x] **Task 1: Walk through allies** — `Movement.reach`; tests (paths through allies, no ending on them, enemies still block, AI moves through allies).
  Pattern: Dijkstra flood fill where pass-through and destination sets differ.
- [x] **Task 2: Zone, default placement, Place action** — `Placement`, `BattleState.zone`, `create` by role, `Place` + `UnitPlaced`, `BattleState.started` (set by `Battle.start()`). A zone with exactly one cell per hero keeps the authored order.
  Pattern: command actions validated against state, events for every change (existing `Battle.perform` pipeline).
- [x] **Task 3: Generator layouts** — 3 × 3 zone, `EDGE` / `CORNER` / `AMBUSH`, weights and distances in `MapGenSettings`, `FloorGenerator` picks the layout; floors 1–100 valid.
  Pattern: seeded `RandomNumberGenerator` streams; generate-and-validate with deterministic retries.
- [x] **Task 4: Placement phase in the battle scene** — controller `PLACING`, zone highlight, `UnitPlaced` playback, HUD Ready and banner.
  Pattern: controller state machine (enum states); signals up, calls down; tweens for playback.
  Done: click a hero, then a zone cell (a hero there swaps; the selected hero again deselects). The default placement spreads heroes over the zone by reach (shortest reach on the closest cell, longest on the farthest), after a visual check showed all three heroes in the front row. Side effect: the standalone slice battle (2 heroes on its 3 spawns) now places the Mage back, and its AI-vs-AI baseline moved to 3 / 20 party wins (the Archer prefers Volley); the slice is a test baseline, the tower is the game.
- [x] **Task 5: Review and polish** — `godot-code-review` subagent; fixes; README (controls, map format, generator settings); docs; roadmap.
  Done (review fixes): a unit's own cell is no longer marked as an ally's cell (`cost_to(origin)` was -1, feeding the AI a wrong MP cost); moves, casts and turn ends are refused before the battle starts; Place checks the hero is alive and only swaps with heroes; AMBUSH enemy placement can't loop forever and the generator reports more than 6 enemies (the most CORNER can place) and warns when it falls back to an open map; the unit panel shows the selected (or first) hero while placing instead of the first unit to act; self-only spells (range 0) no longer count toward a hero's reach. The decision record now says what the zone distance guarantees: 5 MP of walking, a buffer before melee contact — ranged enemies may still shoot on their first turn.
  Deferred from the review: an end-to-end AI test of an enemy walking through its ally; a warning when only the ambush weight is set (early floors fall back to EDGE).
