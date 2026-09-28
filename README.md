# godot-test

Test godot game creation with AI agent.

This is a **Godot 4.7** project (GDScript), developed from the command line — the editor UI is optional.

## Setup

Godot is installed as a macOS app at `/Applications/Godot.app`. The app bundle doesn't put a `godot` command on your PATH, so add a symlink to the binary inside it:

```sh
ln -sf /Applications/Godot.app/Contents/MacOS/Godot ~/.local/bin/godot
godot --version   # 4.7.2.stable...
```

(`~/.local/bin` must be on your `PATH`.)

Running from the editor (F5): by default Godot embeds the game in the editor's **Game** tab, where the editor sets its size and it can look blurry on a non-Retina second monitor. For a real window, turn off "Embed Game on Next Play" in the Game tab's ⋮ menu (or set Editor Settings → Run → Window Placement → Game Embed Mode to Disabled). Turn it back on when you want the Game tab's runtime tools (clicking nodes in the running game, frame stepping, free camera).

## CLI usage

Run these from the repo root:

| Task | Command |
| --- | --- |
| Run the game (the battle) | `godot` |
| Run a specific scene | `godot scenes/battle/battle.tscn` |
| Run headless (no window), quit after N frames | `godot --headless --quit-after 60` |
| Import assets, refresh the `.godot/` cache (run after adding a `class_name` script) | `godot --headless --import` |
| Check a script for errors | `godot --headless --check-only --script scripts/battle/battle.gd` |
| Run all tests (exit code 1 on failure) | `godot --headless --script res://tests/run_tests.gd` |
| Run tests whose file name matches | `godot --headless --script res://tests/run_tests.gd -- movement` |
| Render frames to PNG (visual check; needs a window, not `--headless`) | `godot --write-movie /tmp/shot.png --fixed-fps 10 --quit-after 30 scenes/battle/battle.tscn` |
| Open the editor | `godot -e` |
| Export (needs `export_presets.cfg`) | `godot --headless --export-release "<preset>" build/<file>` |

## Playing

A turn-based tactical battle (Dofus / Disgaea style): your Knight and Mage against a Brute and an Archer. Units act in initiative order; each turn a unit has AP for spells and MP for moving.

| Control | Action |
| --- | --- |
| Left click on a highlighted (blue) cell | Move there |
| `1`–`9` or click a spell button | Aim a spell (again to unselect) |
| Left click on an orange cell (or a unit standing there) | Cast the aimed spell |
| `Esc` / right click | Stop aiming |
| `Space` | End turn |
| `Q` / `E` (`A` / `E` on AZERTY) | Turn the camera 90° |
| Mouse wheel | Zoom |
| `T` | Toggle the near-overhead view |

Hover a spell button for its range, area and effect; hover any other unit on the board to see its HP, AP / MP, statuses and spells in the panel on the right. Statuses show as colored tags above units (e.g. `P3`: Poison, 3 turns left) and in the unit panels: damage or heal over time ticks at the carrier's turn start, AP / MP and damage-taken changes last for the status's turns. While aiming, orange cells can be targeted and darker cells are in range but out of line of sight. The unit whose turn it is has a pulsing ring. The result screen shows the battle seed: set it as `rng_seed` on the `Battle` node to replay that battle.

## Adding content

Content is data (`.tres` resources), edited in the Inspector or as text; no code changes. The headless tests load and validate every file under `data/`, so run them after any change.

- **A spell** — `data/spells/<name>.tres`, a `SpellData`: `display_name`, `ap_cost`, `min_range` / `max_range` (Manhattan; `min_range = 0` allows the caster's own cell), `needs_line_of_sight`, `height_extends_range`, an `area` (`AreaShape`: SINGLE, CROSS, CIRCLE or LINE with a `size`) and `effects`, applied one after another: `DamageEffect` / `HealEffect` (`min_amount` / `max_amount`) or `ApplyStatusEffect` (`status`). Each effect has a `target_filter`: ALL units in the area (default), ALLIES, ENEMIES, or the CASTER only (even outside the area). New effect kinds are `EffectData` subclasses implementing `apply()` and `describe()`.
- **A status** — `data/statuses/<name>.tres`, a `StatusData`: `display_name`, `short_label` (tag text), `color`, `is_positive`, `duration` (the carrier's turns), `tick_effects` (fired at each of its turn starts, e.g. a `DamageEffect` for poison) and `modifiers` (`StatModifier`: AP, MP or DAMAGE_TAKEN_PERCENT with an `amount`). Recasting a status refreshes it; it keeps running if its caster dies. A spell applies it through an `ApplyStatusEffect`.
- **A unit** — `data/units/<name>.tres`, a `UnitData`: `display_name`, `max_hp`, `ap`, `mp`, `initiative` (higher acts first), `spells` (2–4 spell files), and a placeholder `color` (or a `model_scene` from an asset pack). A spell costing more AP than the unit has is a validation error.
- **A map** — `data/maps/<name>.tres`, a `MapData` whose `layout` is text, one row per line, one token per cell: a height (`0`, `1`, `2`…), `<height>p` / `<height>e` for player / enemy spawns (used in reading order), `#` for an obstacle, `.` for a hole. A step can climb 1 level and drop 2; keep every floor cell reachable from the spawns (the slice map test checks this for its map).
- **A battle** — select the `Battle` node in `scenes/battle/battle.tscn` and set `map`, `players` and `enemies` (one unit per spawn at most), `ai_profile` (`data/ai/*.tres`: kill bonus, heal and friendly-fire weights, and how it values statuses) and `rng_seed` (0 = random).

## Agent guidelines

Instructions for AI agents working on this repo:

- **Never improvise a game mechanic.** Before implementing one (movement, combat, inventory, state, save/load, …), use an established Godot pattern or best practice you know well. If you're not sure of the idiomatic approach for Godot 4.7, search for it (official docs first) before writing code. Name the pattern you're following when you explain the change.
- **Design before code for new systems:** settle open decisions with the `godot-grill` skill, then plan the scene tree and signals with `godot-brainstorming`.
- **Verify through the CLI:** run `--check-only` on edited scripts and run the game headless. Write tests following `godot-gdscript-headless-testing`.
- **No `assert()` in game or test code:** a failed assert hangs headless runs instead of failing. Use `push_error()` with a safe fallback in game code, and `TestCase` assertions in tests. Any error logged during a test fails it; a test that triggers one on purpose declares it with `expect_error()`.
- **Review with `godot-code-review`** before calling a mechanic done.
- **Design decisions are recorded in `docs/decisions/`.** Read them before designing; don't re-ask what's settled. The milestone order is in `docs/roadmap.md`.

Project skills live in `.claude/skills/`, copied from [GodotPrompter](https://github.com/jame581/GodotPrompter) and [awesome-gamedev-agent-skills](https://github.com/gamedev-skills/awesome-gamedev-agent-skills) and trimmed to stand alone.

## Project layout

```
project.godot     # project config (main scene: res://scenes/battle/battle.tscn)
scenes/           # .tscn scene files
scripts/          # .gd scripts (and their .uid files, commit these)
  battle/         #   rules: state, movement, targeting, actions, AI (no nodes)
  data/           #   content resource classes (units, spells, effects, maps, AI profiles)
  view/           #   display: board, camera, units, event player, HUD, controller
data/             # content .tres files (units, spells, maps, AI profiles)
tests/            # headless tests: test_*.gd files extending TestCase
docs/roadmap.md   # milestones toward the full game
docs/decisions/   # design decision records
docs/plans/       # implementation plans
.godot/           # editor/import cache, gitignored
```
