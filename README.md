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
| Run the game (hub, then tower or stage runs) | `godot` |
| Run one battle on its own (no progression) | `godot scenes/battle/battle.tscn` |
| Run headless (no window), quit after N frames | `godot --headless --quit-after 60` |
| Import assets, refresh the `.godot/` cache (run after adding a `class_name` script) | `godot --headless --import` |
| Check a script for errors | `godot --headless --check-only --script scripts/battle/battle.gd` |
| Run all tests (exit code 1 on failure) | `godot --headless --script res://tests/run_tests.gd` |
| Run tests whose file name matches | `godot --headless --script res://tests/run_tests.gd -- movement` |
| Add missing UIDs / `uid=` references to `.tres` / `.tscn` made from the CLI | `godot --headless --script res://tools/fill_uid_refs.gd` |
| Render frames to PNG (visual check; needs a window, not `--headless`) | `godot --write-movie /tmp/shot.png --fixed-fps 10 --quit-after 30 scenes/battle/battle.tscn` |
| Open the editor | `godot -e` |
| Export (needs `export_presets.cfg`) | `godot --headless --export-release "<preset>" build/<file>` |

## Playing

A turn-based tactical roguelite (Dofus / Disgaea style). The game opens on the **party screen**, the hub: your three heroes (Knight, Mage, Ranger), their level, stats and runes, the rune stash, and where to fight next.

- **Tower:** **Climb the tower** starts a run: a straight line of floors until the party falls or clears the top floor (10 at first). Every floor is the same for everyone (map and enemies come from its number; dice and loot stay random). Floors ending in 5 have an elite, multiples of 10 a boss. HP carries over between floors; after each win, heroes below 25 % (fallen ones too) are raised to 25 %. After a boss, pick a **boon** (a bonus for the whole party until the run ends) or a full heal, then continue or leave. Your best floor is recorded.
- **Stages:** one hard battle each, in order. Clearing one raises the tower's top floor by 10 and lets runs start 10 floors higher (11, 21…).
- **Runs are saved between floors:** quit any time outside a fight and **Continue run** from the hub (or **Abandon run**).
- **Sudden death:** from round 40, each hero loses 10 % of max HP every turn, so a stalled battle always ends.
- **Progression:** every enemy killed gives XP; a won battle gives each hero the full XP (fallen heroes too), levels (+HP, +Power; a 4th spell at level 3, +1 MP at level 6; cap 10) and the runes the enemies dropped. A lost battle ends the run and gives nothing for that fight; levels and runes are always kept.
- **Runes:** 6 slots per hero. Click a rune in the stash to equip it on the selected hero, click a slot to unequip it. Common and rare runes stack; epic and legendary ones are one per hero.
- **Stats:** Power raises damage and heals by a percentage; resistances reduce damage of one type (Physical, Fire, Poison), at most 50 %.
- **Save:** automatic after each battle, boss choice and rune change, in `user://profile.json` (on macOS `~/Library/Application Support/Godot/app_userdata/godot-test/profile.json`). Delete it to start over.

In battle, units act in initiative order; each turn a unit has AP for spells and MP for moving.

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

## Design tools (editor plugin)

`addons/design_tools` is enabled in the project. Open the editor (`godot -e`):

- **Previews in the Inspector** — select a spell `.tres` to see its range and area on a grid, expected damage / heal across Power (columns) and resistance (rows), damage per AP and its statuses' totals; select an enemy to see HP / Power / XP / resistances at levels 1–10 for the normal, elite and boss presets, and its loot odds. Previews follow your edits.
- **Design panel** (bottom, next to Output) — **New** creates a spell, enemy (with its unit), encounter or preset from a valid template; **Duplicate selected** copies the one open in the Inspector under a new name; **Export floor** saves a tower floor's generated encounter (map included) in `data/encounters/`. New files get a UID and open in the Inspector.
- **Balance lab** (in the Design panel) — pick an encounter, three heroes and their levels, a battle count, and **Run**: AI-vs-AI battles run in the background and show the party's win rate, average rounds, damage dealt / taken per unit and spell use. **Run tower** plays whole tower runs instead (from a starting floor, heroes at a level, keeping levels and runes between runs or not; found runes are equipped automatically) and shows where runs end and how often each floor is lost: the tool for tuning the tower's bands. The AI plays the party worse than a player does, so read it as a lower bound.
- **Board preview** — `scenes/battle/battle.tscn` shows its map in the 3D viewport (`BoardView.preview_map`), updated live as you edit the map's layout.

## Adding content

Content is data (`.tres` resources), edited in the Inspector or as text; no code changes. The headless tests load and validate every file under `data/`, so run them after any change.

- **A spell** — `data/spells/<name>.tres`, a `SpellData`: `display_name`, `ap_cost`, `min_range` / `max_range` (Manhattan; `min_range = 0` allows the caster's own cell), `needs_line_of_sight`, `height_extends_range`, an `area` (`AreaShape`: SINGLE, CROSS, CIRCLE or LINE with a `size`) and `effects`, applied one after another: `DamageEffect` / `HealEffect` (`min_amount` / `max_amount`, `power_scaling`: how much of the caster's Power applies, 100 % by default) or `ApplyStatusEffect` (`status`). Each effect has a `target_filter`: ALL units in the area (default), ALLIES, ENEMIES, or the CASTER only (even outside the area). New effect kinds are `EffectData` subclasses implementing `apply()` and `describe()`.
- **A status** — `data/statuses/<name>.tres`, a `StatusData`: `display_name`, `short_label` (tag text), `color`, `is_positive`, `duration` (the carrier's turns), `tick_effects` (fired at each of its turn starts, e.g. a `DamageEffect` for poison) and `modifiers` (`StatModifier`: AP, MP or DAMAGE_TAKEN_PERCENT with an `amount`). Recasting a status refreshes it; it keeps running if its caster dies. A spell applies it through an `ApplyStatusEffect`.
- **A unit** — `data/units/<name>.tres`, a `UnitData`: `display_name`, `max_hp`, `ap`, `mp`, `initiative` (higher acts first), `spells` (2–4 spell files), `innate_modifiers` (always-on stats, e.g. an enemy's resistances), and a placeholder `color` (or a `model_scene` from an asset pack). A spell costing more AP than the unit has is a validation error.
- **A map** — `data/maps/<name>.tres`, a `MapData` whose `layout` is text, one row per line, one token per cell: a height (`0`, `1`, `2`…), `<height>p` / `<height>e` for player / enemy spawns (used in reading order), `#` for an obstacle, `.` for a hole. A step can climb 1 level and drop 2; keep every floor cell reachable from the spawns (the slice map test checks this for its map).
- **A damage type** — `data/damage_types/<name>.tres`, a `DamageType` (`display_name`, `color`); set it as a `DamageEffect`'s `damage_type` and in resistance modifiers.
- **A rune** — `data/runes/<name>.tres`, a `RuneData`: `display_name`, `rarity` (COMMON, RARE, EPIC, LEGENDARY: drop weight and color; epic+ are one per hero), `modifiers` (`StatModifier`: AP, MP, POWER, MAX_HP, INITIATIVE, DAMAGE_TAKEN_PERCENT, or RESISTANCE_PERCENT with a `damage_type`). Add it to enemies' loot tables to make it drop.
- **An enemy** — `data/enemies/<name>.tres`, an `EnemyData`: its `unit` (a `UnitData`), per-level growth (`hp_per_level`, `power_per_level`), XP (`xp_base` + `xp_per_level`) and a `loot_table` (`data/loot/*.tres`: `rolls`, `drop_chance`, `runes`; a drop picks a rune weighted by rarity). Use **New → Enemy** in the Design panel.
- **A difficulty preset** — `data/presets/<name>.tres`, a `DifficultyPreset`: `tag` (shown after the name, e.g. "Elite"), `hp_multiplier`, `power_bonus`, `extra_modifiers`, `xp_multiplier`, `extra_loot_rolls`, `rarity_floor`, an optional `ai_profile` and `visual_scale`.
- **An encounter** — `data/encounters/<name>.tres`, an `Encounter`: a `map`, `spawns` (each an enemy, a `level` and a `preset`, in enemy-spawn order) and an `ai_profile`. Try it in the balance lab.
- **A hero** — `data/heroes/<name>.tres`, a `HeroData`: its `unit` (a `UnitData`: base stats and kit) and `level_rewards` (one `LevelReward` per level from 2: `modifiers` and unlocked `spells`; 4 spells at most in total). Add it to `data/progression/roster.tres` (`heroes`, `starting_unlocked`, `starting_party`); the XP curve and level cap are in `data/progression/config.tres`.
- **The tower** — `data/tower/tower.tres`, a `TowerConfig`: `seed_salt` (changing it changes every floor), `initial_cap`, `bands` (`FloorBand` from a floor: `enemy_level` + `levels_per_floor`, `min_enemies` / `max_enemies`, `enemy_pool`, `boss_pool`), the normal / elite / boss presets, `ai_profile`, `boons` and `boss_tier_floors` (a boss on floor 10 offers tier-1 boons, 20 tier 2, 30 and above tier 3; `boon_offer_size` of them), `map_settings` (`MapGenSettings`: sizes, plateaus, heights, obstacle and hole densities), the sudden-death round and percent, and `stages`.
- **A boon** — `data/boons/<name>.tres`, a `BoonData`: `display_name`, `tier`, `modifiers` (like a rune's, applied to every hero for the rest of the run). Add it to the tower's `boons`.
- **A stage** — `data/stages/<name>.tres`, a `StageData`: `display_name`, `seed` (its map and enemies), `difficulty_floor` (it plays like that floor's boss fight), `unlocks_cap` and `unlocks_start_floor`. Add it to the tower's `stages`, in order.
- **A standalone battle** — select the `Battle` node in `scenes/battle/battle.tscn` and set `encounter`, `players`, a fallback `ai_profile` (`data/ai/*.tres`: kill bonus, heal and friendly-fire weights, and how it values statuses) and `rng_seed` (0 = random).

## Agent guidelines

Instructions for AI agents working on this repo:

- **Never improvise a game mechanic.** Before implementing one (movement, combat, inventory, state, save/load, …), use an established Godot pattern or best practice you know well. If you're not sure of the idiomatic approach for Godot 4.7, search for it (official docs first) before writing code. Name the pattern you're following when you explain the change.
- **Design before code for new systems:** settle open decisions with the `godot-grill` skill, then plan the scene tree and signals with `godot-brainstorming`.
- **Verify through the CLI:** run `--check-only` on edited scripts and run the game headless. Write tests following `godot-gdscript-headless-testing`.
- **No `assert()` in game or test code:** a failed assert hangs headless runs instead of failing. Use `push_error()` with a safe fallback in game code, and `TestCase` assertions in tests. Any error logged during a test fails it; a test that triggers one on purpose declares it with `expect_error()`.
- **Review with `godot-code-review`** before calling a mechanic done.
- **Keep resource files in the editor's format.** After generating or hand-editing `.tres` / `.tscn` files from the CLI, run `tools/fill_uid_refs.gd` (a test fails otherwise), so opening the editor doesn't rewrite them into formatting-only diffs. Commit any editor re-save on its own.
- **Design decisions are recorded in `docs/decisions/`.** Read them before designing; don't re-ask what's settled. The milestone order is in `docs/roadmap.md`.

Project skills live in `.claude/skills/`, copied from [GodotPrompter](https://github.com/jame581/GodotPrompter) and [awesome-gamedev-agent-skills](https://github.com/gamedev-skills/awesome-gamedev-agent-skills) and trimmed to stand alone.

## Project layout

```
project.godot     # project config (main scene: res://scenes/game/game.tscn)
addons/           # editor plugins (design_tools: previews, Design panel, balance lab)
scenes/           # .tscn scene files
scripts/          # .gd scripts (and their .uid files, commit these)
  battle/         #   rules: state, movement, targeting, actions, AI (no nodes)
  data/           #   content resource classes (units, spells, effects, maps, AI profiles)
  view/           #   display: board, camera, units, event player, HUD, controller
  progression/    #   lasting progress: hero records, profile, save (no nodes)
  run/            #   run loop: tower and map generators, run state and director (no nodes)
  game/           #   game root (profile, screens), hub (party screen) and run screen
data/             # content .tres files (units, enemies, spells, statuses, damage types, runes, loot, presets, encounters, heroes, maps, AI profiles, tower, boons, stages)
tests/            # headless tests: test_*.gd files extending TestCase
tools/            # CLI helper scripts (fill_uid_refs.gd)
docs/roadmap.md   # milestones toward the full game
docs/decisions/   # design decision records
docs/plans/       # implementation plans
.godot/           # editor/import cache, gitignored
```
