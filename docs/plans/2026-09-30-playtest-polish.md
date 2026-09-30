# Playtest polish (milestone 5d) — implementation plan

Decisions: [`docs/decisions/2026-09-30-playtest-polish.md`](../decisions/2026-09-30-playtest-polish.md).
Architecture: camera behaviour stays in `CameraRig` (calls down from the controller, which owns when to recentre); the HUD only reports clicks up; XP and HP numbers come from `Profile` / `RunDirector`; dropping a rune is a `Profile` rule applied by `Game` like equip.

## Design summary
- `CameraRig`: `focus_on(point, animate)` (tweened, clamped), `set_bounds(rect)`, `pan_by_screen(delta)` (screen → ground through the camera basis), arrow keys in `_process`, left / middle drag with a click threshold (`consume_drag()`), actions `camera_pan_*` (arrows, fixed) and `camera_recenter` (`C`, rebindable).
- `BattleController`: board clicks act on button **release** unless the rig says it was a drag; recentres on `TurnStarted`; Recenter key / HUD button → the active unit.
- `OrderOverlay` rows emit `unit_pressed`; `Hud` closes the overlay and forwards it like a chip press.
- `UnitInfo.xp_gain`, `RunScreen` fills it from the report; `PartyHpRow` draws the two-tone bar (`XpGainBar` under a transparent `XpBarOverlay`, theme variations) and the XP text.
- `Profile.drop_rune(stash_index)`; `RuneStash` rows = rune button + Drop button, with an inline confirm state; `drop_requested` → `Game`.

## Tasks
Each task ends with: `--check-only`, headless tests green (plus mutation checks), `tools/fill_uid_refs.gd` after CLI-made resources, a render check for visual changes, a commit of explicit paths.

- [x] **Task 1: Camera pan, recentre and follow** — rig focus / bounds / pan (keys, drag with threshold), controller click-on-release, recentre on each turn, Recenter key (rebindable) and HUD button.
  Pattern: orthographic pan by screen delta through the camera basis; click vs drag discrimination by a movement threshold (the same gesture model as touch); tweened camera moves.
  Done: `CameraRig` gains `focus_on` (smooth), `set_bounds` / `clamp_point` (board plus a one-cell margin), `pan_by_view` (screen plane → ground, ×1/sin(pitch) upwards), arrow-key panning in `_process` (`camera_pan_*` actions) and left / middle drag with a 10 px threshold (`dragged`; it reads each motion event's button mask, so a release another node ate can't leave it stuck). `BattleController` acts on a left **release** only if the press started on the board and the rig didn't drag, focuses the acting unit on every `TurnStarted` (using where the unit is drawn, not the final state cell), and handles the `camera_recenter` action (`C`, rebindable, in the settings list) and the HUD's Recenter button. Chip clicks slide there too.
- [x] **Task 2: Focus a unit from the full order** — overlay rows clickable.
  Pattern: signals up (`unit_pressed`), reuse the chip focus path.
  Done: a row of the `OrderOverlay` is clickable (`unit_pressed`, pointing-hand cursor, tooltip): it closes the overlay and `Hud` forwards it as `chip_pressed`, so the controller slides the camera to that unit like a timeline chip (any unit, not just the next five). Row children ignore the mouse so only the row takes the click (status icons pass it on and keep their tooltip).
- [x] **Task 3: XP gain on the floor-cleared screen** — two-tone bar and text.
  Pattern: stacked `ProgressBar`s with theme variations; plain-data `UnitInfo`.
  Done: `UnitInfo.xp_gain` / `xp_text`; `RunScreen._fill_xp` (XP from before = now − gain, the gain clamped to this level; a level-up shows a full bar and "Level up! (+27 XP)"); `PartyHpRow` stacks a lighter `XpGainBar` (to the XP now) under a transparent-background gold `XpBarOverlay` (to the XP before) and draws the text under it ("XP 30 / 50 (+7)"); both are theme variations in `build_theme.gd`. No animation.
- [x] **Task 4: Drop a rune** — Drop button, inline confirm, `Profile.drop_rune`.
  Pattern: rules-layer function applied by `Game`, view keeps a small confirm state.
  Done: `Profile.drop_rune`; `RuneStash` rows are a rune button plus a **Drop** button, and Drop turns that row into "Drop <rune>?" with **No** (focused first) / **Yes**, inline; Yes emits `drop_requested`, `PartyScreen` forwards it, `Game._on_drop_requested` drops, saves and refreshes (ignored unless the hub is on screen). After a drop the focus lands on the row that took its place.
- [x] **Task 5: Review and polish** — `godot-code-review` subagent, fixes, README, roadmap (done items out of the backlog, the currency / economy items stay).
  Done: a `godot-code-review` subagent reviewed `main..HEAD`. Fixed, each with a test: a release over the HUD (or on another cell than the press, e.g. after the camera slid) no longer clicks the board; a left press the rig never saw (HUD-held button) can't start a drag and a known-up button forgets its press; the level-cap XP bar is full gold (no gain segment); the first sudden-death turn follows the camera too; the arrow keys are left to the menus while the order overlay, leave question or result is open (`pan_enabled`); the drop question follows its rune (a `RuneData` reference) when the stash changes from outside and is cleared when that rune leaves; Recenter uses the unit on screen, not the state's final actor. Left as is: a failed save after a drop behaves like equip / unequip do, and hover still follows the mouse during a drag (cosmetic). README and roadmap updated; the currency / selling / fusing ideas stay in the backlog.
