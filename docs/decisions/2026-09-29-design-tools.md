# Design tools (milestone 3) — decisions

Milestone 3 of [`docs/roadmap.md`](../roadmap.md). Builds on the slice, status-effect and progression records ([`2026-09-27-tactical-rpg-slice.md`](2026-09-27-tactical-rpg-slice.md), [`2026-09-28-status-effects.md`](2026-09-28-status-effects.md), [`2026-09-28-progression.md`](2026-09-28-progression.md)): content as `.tres`, modifier stack, damage types as data, enemies with XP, loot tables and innate modifiers.

| Decision | Choice | Why | Revisit when |
|---|---|---|---|
| Where | A **Godot editor plugin** (`addons/`): panels and previews over the same `.tres` files | Content already lives in `.tres` edited in the editor; the plugin adds what the Inspector lacks and saves straight into the repo | a non-developer designer joins |
| Architecture | Inspector previews (`EditorInspectorPlugin`) + a Design bottom panel (create / duplicate, balance lab); data and rules scripts are `@tool` so editor code can run them; enemy levels and presets become permanent modifiers (the same stack as heroes) | The least custom UI for the most value; the rules layer doesn't change | — |
| Audience | The developer only: functional over pretty; the editor's own undo / inspector are enough | Keeps the milestone small | someone else designs content |
| Spell scaling | Each damage / heal effect gets a **Power scaling %** (default 100 %: today's behavior). No spell ranks yet | Build variety cheaply; ranks overlap with the skill-tree idea | a skill tree is designed |
| Enemy levels | Enemies have a **level** that scales their stats: an `EnemyData` resource wraps the unit (like `HeroData`) with per-level growth (HP, Power) and XP that grows with level; loot and XP move from `UnitData` to it | "Brute, level 5" from one definition; M4's generator needs it | — |
| Difficulty presets | Reusable preset resources (normal / elite / boss) changing: HP multiplier, bonus Power (optionally resistances), XP multiplier, extra loot rolls, a rarity floor, an AI profile, and a visual cue (size, name tag). Starting values: **elite** HP ×1.5, +20 Power, XP ×2, +1 roll, tag; **boss** HP ×3, +40 Power, XP ×5, +2 rolls, rare-or-better drops, sharper AI, 1.3× size, tag — tuned in the balance lab | Encounters say "level 5 elite Brute"; numbers stay data | balancing (M4) |
| Encounters | An `Encounter` resource: a map and spawns (enemy + level + preset). The game's battle and the balance lab use it; M4's generator will produce them | One description of a fight for play, testing and generation | M4 generation |
| Balance lab | In the plugin: pick party heroes (levels, optional runes), an encounter and a battle count; runs AI-vs-AI battles headless on a **worker thread** (the editor never freezes); shows win rate, average turns, damage dealt / taken per unit, spell usage | Turns the hand-run AI-vs-AI checks into a button; tunes enemies and presets before M4 | — |
| Skill designer | Spell previews: area and range grid (range diamond, area shape, line-of-sight need), expected damage / heal per level at several Power and resistance values, AP efficiency, status expected value; **create and duplicate** buttons | The Inspector can't show what a spell does; creation from templates saves the most time | — |
| Enemy designer | Enemy previews: stats at each level and preset, resistances, XP and loot odds; **create and duplicate** buttons | Same | — |
| Board preview | The battle scene draws its map in the editor (`@tool`), updating live when the map changes; the map painter stays in M4 | Cheap; M4's generator output needs it | M4 (painter) |
| HUD | Shows an enemy's level and preset, e.g. "Brute Lv 5 · Elite" | Players see what they fight | UI polish (M5) |
| Save references | Resources in saves by **UID** with the path as fallback (deferred from M2) | The tools create and rename files | — |
| Shared loot tables | Loot tables as their own `.tres` (deferred from M2), referenced by enemies | Reuse across enemies; editable in one place | — |

## Open / deferred
- Map painter — M4, once maps are known to be hand-made, generated or template-based.
- Spell ranks — with a skill tree.
- Polished tool UX (undo beyond the editor's, onboarding) — only if someone else designs content.
