# Gameplay rules pass (milestone 5c) — implementation plan

Decisions: [`docs/decisions/2026-09-30-gameplay-rules.md`](../decisions/2026-09-30-gameplay-rules.md). Roadmap: "Future features" (line of sight, runes during a run).
Architecture: rules stay in the rules layer (`Grid`, `Targeting`, `Profile` / `RunDirector`); views read the same numbers; the Game root owns the screen flow.

## Design summary
- `Grid.obstacle_levels(cell) -> int` (2 today, the obstacle's height in levels). `Targeting._blocks` tests an obstacle cell against `height_at + obstacle_levels`. `BoardView` draws the block as a cube from the same value (`levels × level_height`, `block_fill` wide) and uses it for the pick collider.
- `RunScreen` gets a **Party** button (`party_pressed`); `Game.show_party()` already shows Continue run. After a rune change in a run, `RunDirector.clamp_hp(profile)` caps saved HP to the new maxima (-1 "full" stays).
- No new nodes or autoloads.

## Tasks
Each task ends with: `--check-only`, headless tests green (plus mutation checks), `tools/fill_uid_refs.gd` after CLI-made resources, a render check for visual changes, a commit of explicit paths.

- [x] **Task 1: Obstacle cube and line of sight** — `Grid.obstacle_levels`, `Targeting._blocks`, `BoardView` cube and collider, tests (high ground sees over, ground is blocked, exact heights, previews / AI follow through `Targeting`), README and the slice decision's line-of-sight row noted as reopened.
  Pattern: one source of truth read by rules and view (the rules own the number, the view derives its drawing from it).
  Done: `Grid.OBSTACLE_LEVELS` (2) and `Grid.obstacle_levels(cell)`; `Targeting._blocks` tests an obstacle against `height + obstacle_levels` (so a caster two levels up sees over a block, the ground doesn't); `BoardView` draws the block as a full-cell cube of `obstacle_levels × level_height` (was 0.8 × 0.9 × 0.8) and uses it for the pick collider (`OBSTACLE_SIZE` is gone). The damage preview and AI follow because they go through `Targeting` (tested). README and the slice decision row updated.
- [x] **Task 2: Runes between floors** — Party button on the run screen, `RunDirector.clamp_hp` after a rune change in a run, tests (button signal, HP capped on equip / unequip, no heal, `-1` kept), README.
  Pattern: signals up, calls down through `Game`; a rules-layer function for the HP invariant.
  Done: `RunScreen.party_pressed` (a Party button next to Next floor and at a boss choice; none once the run is over) → `Game.show_party()` (Continue run is on the hub); `RunDirector.clamp_hp(profile)` after every rune change in a run (HP never rises with a bigger maximum, a smaller one takes the excess for good, -1 "full" stays); `Game` ignores equip / unequip requests unless the hub is on screen (never during a fight). README updated.
- [x] **Task 3: Review and polish** — `godot-code-review` subagent, fixes, roadmap ("Future features" items moved to done), playtest findings.
  Done: a `godot-code-review` subagent reviewed `main..HEAD`. Fixed, each with a test: generated blocks sank to level 0 next to plateaus (new `<height>#` token, written by the generator); a hero saved as "full" (-1) got a free heal from a bigger maximum (`RunDirector.materialize_hp` before a rune change); out-of-bounds cells always block; equip during a pending boss choice and the return to it are tested. Accepted and recorded: line of sight samples the middle of the segment inside a cell, as for terrain (errs toward the player). Roadmap: the two "Future features" items moved to a done section.
- [x] **Playtest feedback (after the review)** — three notes from playing the branch:
  - Rebound keys now show everywhere: End turn / Ready, the view and order buttons, the order overlay's close hint, the prompt line and the first-battle hint read the key from `SettingsApplier.key_text`, not a hard-coded one (tests rebind and check each). While testing this, found that the test runner never called a test file's `after_each_clean()`: it does now (bindings and saved files no longer leak between tests).
  - XP is visible again in the menus: a gold `XpBar` theme variation, text drawn inside the hub panel's bar, a thin bar on each hero tab and on the run screen's party chips (`Profile.xp_progress` / `xp_text`); not shown in battle.
  - Terrain half steps vs the cube obstacle: explained (a level is half a cell, an obstacle is two levels); no change.
  - Leaving a fight: a **Menu** button on the battle HUD asks "Leave the fight?" (Stay / Leave; Esc stays); Leave returns to the hub with the run saved at the same floor, no rewards and HP as before (a fight is never saved mid-way). Not offered in a standalone battle or once the result shows; the shortcuts are locked while the question is open. HP bars above XP bars on the hero tabs and panel (`RunDirector.hero_hp`).
