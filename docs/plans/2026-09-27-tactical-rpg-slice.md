# Tactical RPG vertical slice — implementation plan

Decisions: [`docs/decisions/2026-09-27-tactical-rpg-slice.md`](../decisions/2026-09-27-tactical-rpg-slice.md).
Architecture: **rules produce events, the display replays them** (approach A).

## Design summary

### Rules layer (no nodes, headless-testable)

- **Content** (`scripts/data/`, instances in `data/`): `UnitData`, `SpellData`, `AreaShape`, `EffectData` → `DamageEffect` / `HealEffect`, `MapData` (map as a text grid: digit = height, `#` = obstacle, letters = spawns).
- **State** (`scripts/battle/`): `BattleState` (grid, units, turn order, seeded RNG, `clone()`), `Grid`, `UnitState`, `TurnOrder`.
- **Rules**: movement range/paths (Dijkstra with climb cost and max climb, units block), line of sight (height-aware grid traversal, units block), targeting (Manhattan range + high-ground bonus, LoS filter, area expansion).
- **Actions** (command pattern): `MoveAction`, `CastSpellAction`, `EndTurnAction` — `validate(state)` / `apply(state) -> Array[BattleEvent]`.
- **Events**: `TurnStarted`, `TurnEnded`, `UnitMoved`, `SpellCast`, `DamageDealt`, `Healed`, `UnitDied`, `BattleEnded`.
- **`Battle.perform(action)`**: validate, apply, check victory, advance turn, return events. The rules layer never emits signals.
- **`EnemyAI.choose_next(state, unit)`**: simulate candidates on a clone, score, pick best.

### Display layer

```
Battle (Node3D)                 battle_controller.gd
├── CameraRig (Node3D)          camera_rig.tscn — Q/E 90° tweened rotation, wheel zoom
│   └── Camera3D                orthographic, 40° down (T: 75° overhead view)
├── BoardView (Node3D)
│   ├── Cells (Node3D)          one column per cell (placeholder box or BoardTheme scene), collider tagged with its cell
│   └── Highlights (Node3D)     reachable / path / range / area overlays
├── UnitsView (Node3D)          one unit_view.tscn per unit
├── EventPlayer (Node)          sequential, awaited event playback
├── DirectionalLight3D + WorldEnvironment
└── HUD (CanvasLayer)           hud.tscn — TurnOrderBar, UnitPanel, SpellBar, EndTurnButton, ResultPanel
```

- Controller input states (enum FSM): `IDLE`, `TARGETING`, `ANIMATING`, `ENEMY_TURN`, `ENDED`.
- `BattleState` is the only source of truth; views re-read it after each playback.
- Asset swap: `BoardTheme` resource (cell scenes) + optional `UnitData.model_scene`.

## Tasks

Each task ends with: `--check-only` on edited scripts, headless tests green, and a commit.
If unsure of a Godot 4.7 API, check the official docs before writing it.

### Foundation

- [x] **Task 1: Project scaffolding and test runner** — create the folders (`scripts/battle`, `scripts/data`, `scripts/view`, `data/{units,spells,maps}`, `scenes/battle`, `tests/`); add the Input Map actions (`camera_rotate_left/right`, `camera_zoom_in/out`, `cancel`, `end_turn`); write `tests/run_tests.gd`; add the test command to the README.
  Pattern: SceneTree test runner that counts failures and calls `quit(code)`, never bare `assert()` (`godot-gdscript-headless-testing`).

- [x] **Task 2: Content resource classes** — `UnitData`, `SpellData`, `AreaShape`, `EffectData` + `DamageEffect` + `HealEffect`, `MapData` with a parser to `Grid`.
  Pattern: custom `Resource` with `class_name` and typed `@export` fields; effects as polymorphic Resource subclasses (strategy pattern). Each resource has `get_validation_errors()`.
  Done: resources are data-only; `EffectData.apply()` is added in Task 6 (it needs state and events). A minimal immutable `Grid` was added here because the map parser produces it. Map format also has `.` holes.
  Tests: map text parses to the right sizes, heights, obstacles and spawns; malformed maps are rejected with a clear error.

- [x] **Task 3: Battle state** — `Grid`, `UnitState`, `TurnOrder`, `BattleState` with `clone()`.
  Pattern: plain-data `RefCounted` model; deep copy for simulation (content Resources are shared, read-only references — never mutated at runtime).
  Tests: turn order by initiative (ties broken by unit id, deterministic); AP/MP reset at turn start; a clone mutated does not affect the original.

### Rules

- [x] **Task 4: Movement** — reachable cells within MP, path reconstruction, climb cost, max climb, occupied cells blocked.
  Pattern: Dijkstra / uniform-cost flood fill over a 4-neighbour grid with per-edge costs (edge cost depends on height difference, which is why `AStarGrid2D` per-cell weights don't fit).
  Tests: flat map diamond; a wall of height > max climb is impassable; climbing costs extra MP; units block but don't disappear from range queries of other rules.

- [x] **Task 5: Line of sight, targeting, areas** — LoS between cells, cells in spell range (min/max, high-ground bonus), area expansion (single / cross / circle / line).
  Pattern: grid traversal of the sight line (Amanatides–Woo / supercover) with the sight height interpolated along it; Manhattan distance for ranges (Dofus diamond).
  Tests: obstacle and taller cells block; a unit blocks; high ground sees over a low wall; min range excludes adjacent cells; high-ground bonus extends range only for spells that allow it; each area shape's cells.

- [x] **Task 6: Actions, events, `Battle`** — `MoveAction`, `CastSpellAction`, `EndTurnAction`; event classes; `Battle.perform()` with victory check and turn advance.
  Pattern: command pattern (`validate` / `apply`), events as immutable data records; single entry point that owns state mutation.
  Rule (from review): actions and events refer to units by **id**, never hold a `UnitState`; `validate` / `apply` look the unit up in the state they're given, so applying to an AI clone can never touch the real battle (same convention as `Movement.reach(state, unit_id)`).
  Tests: invalid actions rejected with a reason and no state change; move spends MP and emits `UnitMoved` with the path; spell spends AP, hits every unit in its area, emits `DamageDealt` / `UnitDied`; dead units leave the turn order; last enemy dead → `BattleEnded`; seeded RNG gives identical results for identical inputs.

- [x] **Task 7: Enemy AI** — `EnemyAI.choose_next(state, unit_id)`.
  Pattern: greedy utility AI — enumerate (move cell × spell × target), simulate each on `state.clone()`, score (damage, kills, distance to nearest enemy), take the best; always end with `EndTurnAction`.
  Rule (from review): enumerate candidates from `Movement.reach` and `Targeting.targetable_cells` once per unit and position; don't build and validate every candidate action from scratch (each `Move` validation reruns Dijkstra).
  Rule (from review): the AI must not see future dice rolls. Reseed each simulation clone (e.g. from turn number + candidate), or score with expected values ((min + max) / 2). `BattleState.clone()` itself stays exact, which is right for undo and replays.
  Tests: kills a low-HP target in range; walks toward enemies when nothing is in range; never returns an invalid action; a full AI-vs-AI battle terminates within N turns.
  Done: returns one action per call (the first step of the best plan), so the controller loops until `EndTurn`. Simulations use the average roll (rounded down); any other randomness gets dice seeded from (round, unit id), never the real RNG. Scoring weights (kill bonus, heal, friendly fire) come from an `AIProfile` resource, `data/ai/default.tres` by default. With nothing to cast it walks toward the nearest opponent along a multi-turn distance field (`Movement.distances_to`, a Dijkstra map) rather than straight-line distance. Free (0 AP) spells are ignored so a turn always ends.

- [x] **Task 8: Slice content** — one ~10×10 map with a few height levels and obstacles; 2 player units and 2 enemies; 2–3 spells each (melee, ranged with LoS, one AoE).
  Pattern: data-only `.tres` files; no code changes.
  Tests: the content loads and a scripted AI-vs-AI battle on it finishes.
  Done: `data/maps/slice.tres` (10×10 "Ruined Courtyard", heights 0–2, obstacles, holes); Knight + Mage vs. Brute + Archer (`data/units/`); 9 spells in `data/spells/` (areas and effects are sub-resources, spells are shared files). Files were generated once with `ResourceSaver` for correct `.tres` syntax. AI-vs-AI over 10 seeds: players win 7, enemies 3 — tune in Task 13 once a human plays.

### Display

- [x] **Task 9: Board view and camera** — `BoardTheme`; `BoardView` builds cell scenes from the grid (box stacked to its height, collider with cell metadata); highlight overlays; `camera_rig.tscn`.
  Pattern: view built from model data; orthographic `Camera3D` on a pivot, rotation in 90° steps with `Tween`; picking with an explicit `PhysicsRayQueryParameters3D` ray query from `project_ray_origin` / `project_ray_normal`.
  Verify: run the scene, `--write-movie` a few frames, check the board and a rotated view.
  Done: `scripts/view/` — `BoardTheme` (colors, level height; optional floor/obstacle scenes for an asset pack), `BoardView` (cell columns with tagged colliders on physics layer 1, a pit under holes, `show_highlight(kind, cells)` for REACH / PATH / RANGE / AREA, `pick_cell(camera, screen_pos)`), `CameraRig` (`camera_rig.tscn`; 45° diamond view, 35° pitch, Q/E quarter turns, wheel zoom). `scenes/battle/battle.tscn` exists with a stub controller (builds the slice board, hover highlight) that Task 12 grows. Picking (fixed after review): at 35° a one-level step hid the cell behind it, so the default pitch is 40°; a T toggle switches to a near-overhead view (75°, zoomed out) where every cell center picks itself. Physics layers are named `board` (1) and `units` (2); unit views carry a pick collider tagged with their cell, so clicking a unit's body picks its cell. `test_picking.gd` checks all of this on the slice map at the 4 camera turns. The test runner now runs on the first frame so nodes added to the tree get `_ready()`.
  For Task 12: the default view shows the (9, 9) corner in front; turn the camera so the player's spawns face it (`rotate_steps(n, false)`).

- [x] **Task 10: Units view and event player** — `unit_view.tscn` (capsule or `model_scene`, HP label); `play_move` along the path, `play_hit` with floating number, `play_cast`, `play_death`; `EventPlayer.play(events)`.
  Pattern: sequential playback queue — one `await` per event, each view method returns after its `Tween` finishes (`await tween.finished`).
  Done: `UnitView` (`unit_view.tscn`: capsule with a facing nose, team ring, billboard HP label; climbs go up then across, drops across then down; lunge toward the target; color flash + floating number on hit/heal; squash on death), `UnitsView` (views by unit id), `EventPlayer.play(events)` (awaits each event, flashes the spell area, emits `event_played` for the HUD/controller). `battle.tscn` now creates the battle from exported map + teams and shows the units. Checked by rendering a full AI-vs-AI battle played through the event player: views matched the state after every action. The test runner now supports async tests (awaited, with a global timeout).

- [x] **Task 11: HUD** — turn order bar, unit panel, spell bar (disabled without AP), end turn button, result panel.
  Pattern: Control containers + anchors; HUD emits signals up (`spell_selected`, `end_turn_pressed`) and is updated by method calls down; it never reads or writes game state itself.
  Done: `hud.tscn` + `Hud` — turn order chips (current outlined, round number), unit panel (HP bar, AP, MP), spell bar (buttons with tooltips from `EffectData.describe()`, disabled without AP, keys 1–9, selected spell outlined), End turn (Space via the `end_turn` action as a button shortcut, so it only works when enabled), a Top/Side view button, a fading turn banner, and a Victory/Defeat panel with Play again. Signals: `spell_selected`, `end_turn_pressed`, `view_toggle_pressed`, `restart_pressed`. The controller passes `Hud.UnitInfo` values, never state. Buttons take no focus (Space can't press them); layout containers ignore the mouse so clicks reach the board. The stub controller starts the battle and fills the HUD.

- [x] **Task 12: Battle controller** — load map + teams, create `Battle`, wire everything, input states, enemy turn loop; set `battle.tscn` as the main scene.
  Pattern: enum FSM in the controller (few states, no per-state data); signals up / calls down; enemy actions go through the same `perform` → `EventPlayer` path as the player's.
  From the Task 9–10 review, do here:
  - `EventPlayer.stop()` (generation counter; freeing a view mid-tween drops its coroutine, so `play()` would never return and `is_playing` would stick); skip null views; no rebuild while ANIMATING.
  - `UnitView.sync(unit)` / `UnitsView.sync(state)` after every playback (position, HP, visibility, pick collider; reset the death squash) — views re-read the state, which undo will need too.
  - Hover: update only when the picked cell changes; refresh after camera rotation or toggle.
  - Random battle seed; the area flash should use a tween interval (pauses with the tree) rather than a SceneTreeTimer.
  Done: `BattleController` (`battle.tscn`, now the main scene; the placeholder `main.tscn` is gone). FSM IDLE / TARGETING / ANIMATING / ENEMY_TURN / ENDED; public commands `click_cell`, `select_spell`, `cancel`, `end_turn`, `restart` (mouse, keys and HUD signals map to them). Every action goes `perform` → `EventPlayer.play` → `UnitsView.sync` → next turn; the AI's pause between actions is a tween interval. (The editor later re-created `main.tscn` from an open tab; removed again in Task 13.) Hover is re-picked each physics frame (follows camera turns), ignores the mouse over HUD controls, and only redraws when the cell changes: path while moving, area while aiming. The camera opens facing the player's spawns. Restart rebuilds in place; a battle generation counter and `EventPlayer.stop()` make leftover coroutines of the old battle give up. All review items above are in. The test runner now sizes the headless window to the project resolution (it starts at 64×64, where the HUD covers everything).
  Verify by hand: play a battle to victory and one to defeat.
  Verify: play a full battle by hand to victory and to defeat.

### Wrap-up

- [x] **Task 13: Review and polish** — `godot-code-review` pass over the whole slice; fix findings; update the README (how to run a battle, how to add a unit/spell/map); record any tuning values chosen (climb cost, max climb, high-ground formula) in the decision record.
  Pattern: code review checklist; decision record kept current.
  Done: after playtesting, line of sight was retuned to the drawn unit height (eyes 1.5 levels, body 1.0) and cells in range but out of sight are shown faded. Whole-slice review fixes: hover no longer clears a cast's area flash; the stray `main.tscn` removed; restart validates the new battle before abandoning the old one; EventPlayer checks its generation before clearing the flash; HUD/UnitsView rebuilds use `remove_child` + `queue_free` (safe from inside a button's signal); active-unit pulsing ring; camera zoom 12 with a small vertical offset so the top labels clear the turn bar; battle seed shown on the result screen; `CastSpell.can_afford` shared by the controller and the rules; the FSM field renamed `input_state`; deterministic flash-timing tests. README: controls and "Adding content". Tuning values are in the decision record.
  Deferred from the review — to status effects: AI scoring of statuses (a pure DoT spell scores 0 today and would never be cast; the simulation doesn't run turn-start ticks), one event-dispatch point instead of the two parallel chains in `EventPlayer` (e.g. `Event.subject_id()`), the turn-start death loop (already noted below), live HUD updates during playback (events carry `ap_spent` / `mp_spent` / `hp_after`). To AI difficulty: AI cost (~4 ms average, ~21 ms worst per decision; cache per turn or spread over frames for harder profiles), maybe a per-unit profile. To display polish / assets: line-of-sight heights, the HP label height and the pick capsule are tuned to the capsule and `level_height`, so size them from the model; a default `BoardTheme` `.tres`. Any time: Input Map actions for click and spell keys (rebinding), right click over the HUD to cancel, a hint when a unit has nothing left to do.

## After the slice

1. **Status effects (DoT first)** — first feature once the slice is done. Design notes:
   - `StatusData` resource: name, duration (turns), tick timing (turn start / end), `effects: Array[EffectData]` fired on each tick (reuses `DamageEffect` for DoT, `HealEffect` for HoT).
   - `ApplyStatusEffect` (an `EffectData`) puts a status on the target; `UnitState.statuses` holds active instances (data, turns remaining, caster id) and `clone()` copies them.
   - Ticks run in `Battle._start_turn()` (or turn end), emitting `StatusTicked` then the effects' events.
   - Extract the death check from `perform()` into a shared helper: a tick can kill the unit whose turn is starting, so turn start must report the death, remove it, check the outcome, and move on to the next unit (looping, since that unit may die to its own DoT).
   - Tests: DoT damage at turn start, DoT kill skips to the next unit, battle ends on a DoT kill, statuses expire, clones copy statuses.
   - `BattleState.roll()` is the one place effects roll dice (it switches to average rolls in AI simulations); status effects must use it too.

2. **AI difficulty and smarter strategies** — more `AIProfile` knobs and scoring terms (list in the decision record's open items). Task 12 picks the profile per battle; later battles can load harder ones.

3. **Editor tooling for maps and battles** — today the board is only built at runtime, so `battle.tscn` looks empty in the editor.
   - *Preview:* make `BoardView` a `@tool` script with an exported `map` that builds the board in the editor and rebuilds when the map changes (`MapData` emits `changed` when `layout` is set). Generated nodes get no `owner`, so they're never saved into the scene. `MapData`, `Grid` and `BoardTheme` must be `@tool` too, or the editor loads them as placeholders. Later, show units on their spawns.
   - *Editing:* an editor plugin (`EditorPlugin` + a bottom-panel or 3D-viewport tool) to paint cells in the viewport — raise/lower height, toggle obstacle / hole, place player / enemy spawns — and save the result as a `MapData` `.tres` (the text layout stays the storage format). Could grow into editing a whole battle setup (map + teams + AI profile).

4. **Display polish (from the Task 9–10 review, when an asset pack is chosen)** — strip colliders from asset-pack models when instancing (only our own picking colliders may sit on the `board` / `units` layers); stack one tile model per level or split top / side scenes; size the obstacle collider from its model; a hit flash for models; play the effects of one area cast in parallel; fade obstacles that hide the unit under the mouse (XCOM-style).

5. **Skill design tool** — an editor tool to design spells: area of effect (visual shape editor/preview), power, and scaling (how damage/heal grows with caster stats or level), with previews such as damage per AP at each level. Needs the stats/scaling model first.

6. **Enemy design tool** — an editor tool to design enemies: level, stats, loot table, XP given on death, and difficulty presets (e.g. normal / elite / boss multipliers). Needs stats, XP and loot systems first.
