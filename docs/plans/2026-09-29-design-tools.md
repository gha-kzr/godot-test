# Design tools (milestone 3) — implementation plan

Decisions: [`docs/decisions/2026-09-29-design-tools.md`](../decisions/2026-09-29-design-tools.md). Roadmap: [`docs/roadmap.md`](../roadmap.md), milestone 3.
Architecture: **A — Inspector previews + a Design bottom panel** in an editor plugin (`addons/design_tools/`). Editing stays in the standard Inspector; the plugin adds previews for spells and enemies, New / Duplicate buttons, and a balance lab. Data and rules scripts become `@tool` so editor code can run them (a non-tool script's resource loads as an inert placeholder in the editor).

## Design summary

### Data
- `DamageEffect` / `HealEffect`: `power_scaling` (%, default 100): multiplier = 100 + Power × power_scaling / 100.
- `DifficultyPreset` — `display_name`, `tag_color`, `hp_multiplier`, `power_bonus`, `extra_modifiers`, `xp_multiplier`, `extra_loot_rolls`, `rarity_floor`, `ai_profile` (optional), `visual_scale`. `data/presets/{normal,elite,boss}.tres`.
- `EnemyData` — `unit`, `hp_per_level`, `power_per_level`, `xp_base`, `xp_per_level`, `loot_table` (shared `data/loot/*.tres`); `build(level, preset) -> EnemyBuild` (unit, permanent modifiers, xp, loot, extra rolls, rarity floor, AI profile, visual scale, label). `UnitData.xp_reward` / `loot_table` move here.
- `EncounterSpawn` (`enemy`, `level`, `preset`) and `Encounter` (`display_name`, `map`, `spawns`, `ai_profile`). `data/encounters/slice.tres`.
- Saves reference resources by UID with a path fallback (version 3); every content file gets a UID.

### Rules and game
- `BattleState.create(..., player_modifiers, enemy_builds)`: enemy units get their build's permanent modifiers and a `UnitState.reward` (xp, loot, rolls, floor), `ai_profile`, `label`, `visual_scale`.
- `BattleRewards` uses each dead enemy's reward (extra rolls, rarity floor).
- The controller takes an encounter (plus the party); the AI uses a unit's own profile (preset) before the encounter's. `Game` exports an `encounter` instead of map + enemies; the standalone battle scene exports an encounter and players.
- HUD / unit views: enemy label "Brute Lv 5 · Elite" (name + tag), visual scale.

### Plugin (`addons/design_tools/`)
- `SpellInspector` / `EnemyInspector` (`EditorInspectorPlugin`): preview controls above the fields. Preview maths live in plain classes (`SpellPreview`, `EnemyPreview`) tested headless.
- `DesignPanel` (bottom panel): New / Duplicate spell, enemy, encounter, preset (file saved with a UID, opened in the Inspector); the balance lab.
- `BalanceLab` (plain class): N AI-vs-AI battles for a party (hero levels, runes) vs an encounter → win rate, average turns, damage dealt / taken per unit, spell usage; the panel runs it on a `WorkerThreadPool` task.
- Board preview: `BoardView` `@tool` with a `preview_map` drawn in the editor, rebuilt when the map changes (`MapData` emits `changed`).

## Tasks

Each task ends with: `--check-only` on edited scripts, headless tests green (plus mutation checks on new tests), a commit of explicit paths.

- [x] **Task 1: `@tool` rules and data; power scaling** — `@tool` on data, rules and progression scripts; `power_scaling` on damage / heal effects (formula, describe, validation).
  Pattern: tool scripts for editor-run code; data-driven scaling.
- [x] **Task 2: Enemies, presets, encounters** — `DifficultyPreset`, `EnemyData` / `EnemyBuild`, `EncounterSpawn`, `Encounter`, loot tables as files; `BattleState.create` enemy builds; `UnitState` reward / AI profile / label / scale; `BattleRewards` with extra rolls and rarity floor; content migrated (`data/enemies`, `data/loot`, `data/presets`, `data/encounters`).
  Pattern: data resources + a pure build step producing permanent modifiers (same stack as heroes).
- [x] **Task 3: Game and battle run encounters** — controller and `Game` take encounters; per-unit AI profile; HUD label and unit view scale.
  Pattern: dependency injection of an encounter; signals up, calls down.
  Done (tasks 2 and 3 together, since moving XP / loot off `UnitData` breaks the game flow until battles run from encounters): `data/enemies/{brute,archer}.tres` (Brute +5 HP / +3 Power / 15 + 5 XP per level; Archer +3 / +4 / 12 + 4), `data/loot/common_pool.tres`, `data/presets/{normal,elite,boss}.tres` (boss uses `data/ai/sharp.tres`), `data/encounters/slice.tres` (level 1 Brute and Archer). `UnitState` carries `reward`, `ai_profile`, `label`, `visual_scale`.
- [x] **Task 4: UID save references** — give every content file a UID; save version 3 (`{uid, path}`), older versions still read.
  Pattern: `ResourceUID` references with path fallback.
- [x] **Task 5: Plugin and inspector previews** — plugin skeleton; spell preview (area / range grid, damage by level × Power × resistance, AP efficiency, status value) and enemy preview (stats per level × preset, XP, loot odds).
  Pattern: `EditorPlugin` + `EditorInspectorPlugin` (`_can_handle`, `add_custom_control`); preview maths in plain testable classes.
- [x] **Task 6: Design panel — create and duplicate** — bottom panel; New / Duplicate for spells, enemies, encounters, presets; saved with UIDs and opened in the Inspector.
  Pattern: `add_control_to_bottom_panel`, `EditorInterface.edit_resource`, `ResourceSaver` + `ResourceUID`.
- [x] **Task 7: Balance lab** — `BalanceLab` + panel UI (encounter picker, hero levels, battle count, results), run on a worker thread.
  Pattern: pure simulation on the rules layer; `WorkerThreadPool` task polled from the panel; no node access off the main thread.
- [x] **Task 8: Board preview in the editor** — `BoardView` / `BoardTheme` `@tool`, `preview_map`, live rebuild; generated nodes not saved (no owner).
  Pattern: `@tool` + `Engine.is_editor_hint()`; editor-only children without owner.
- [x] **Task 9: Review and polish** — `godot-code-review` subagent; fixes; README (plugin, content workflow); docs.
  Done (review fixes): the balance lab can be cancelled (Cancel button, "n / N battles" progress; closing the panel or the editor cancels first instead of freezing until the run ends) and runs on deep copies of its inputs, so Inspector edits during a run can't race with the worker; units sharing a label are tallied apart ("Brute Lv 1 #2"); the level spinner stops at the level cap; duplicating an enemy copies its unit under the new name (it kept the original's name and shared its unit); `BoardView` no longer writes a default theme into `battle.tscn` when the editor preview builds (`active_theme()`); empty enemy / spawn slots report errors instead of crashing, and battles and the Game refuse an invalid encounter; the panel updates only the new file instead of rescanning; the factory test checks the UID in the file header (under `res://`, since `user://` files never store one); lab tests share one cached run (suite back to ~15 s).
  Deferred from the review: lab rune pickers, presets listed from `data/presets/` and loot odds per preset in the enemy preview, `BattleState.create` taking enemy builds only, `DamageType` cache invalidation if the tools use it, preview target filters for caster-targeted mixed spells → M4; the preset `tag_color` in the HUD, visual scale for labels / pick collider / status tags, the preview grid's width cap, `add_dock` if `add_control_to_bottom_panel` is deprecated, an export filter for `addons/`, and checking UID saves in a real export → M5.
