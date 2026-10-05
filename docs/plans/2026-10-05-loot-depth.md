# Milestone 11: Loot depth and see-through props — plan

Decisions: [`docs/decisions/2026-10-05-loot-depth.md`](../decisions/2026-10-05-loot-depth.md). Branch `milestone-11` (on `main`); one commit per task; tests for the rules and the flows; French translations at the end; the save format changes freely (beta, no migration).

1. **Rune levels**: `RuneData.level` / `base` and `RuneData.leveled(base, level)` (scaling rule, AP / MP flat, cap 10), `title()` ("Rune of Might Lv 3"), `salvage_value()`, same-kind helpers; `Profile` uses `base` for the one-per-hero check; save stores `{rune, level}` (`to_dict` / `from_dict`). Tests: scaling, caps, identity of level 1, the unique rule across levels, a save round trip.
2. **Drops by depth**: the loot reward knows the enemy's level; `BattleRewards` rolls the rune level (`1 + level / 5`, 20 % of drops one higher, cap 10) from the seeded dice. Tests: deeper enemies drop higher levels, same seed same drops.
3. **Essence, salvage and fuse**: `Profile.essence` (saved), `salvage_rune()` replaces `drop_rune()`, `can_fuse()` / `fuse()` (three of the same file and level plus the cost). Tests for the rules and errors (not enough copies or essence, max level).
4. **Hub UI**: the rune stash shows each rune's level, an essence counter, **Salvage** (inline Yes / No, shows the essence gained) instead of Drop, and **Fuse** on a row when three identical runes and the essence are there (the cost on the button, a tooltip for why not); the run screen's found-runes text shows levels. Tests.
5. **QA, previews, tools**: the QA profile tools and the design previews understand levels (a level box for "get every rune", essence), `LootTable` previews unchanged.
6. **See-through obstacles**: a fade shader/material on tall obstacles (dithered alpha), a per-frame check from the camera to each unit and the hovered cell, a setting-free default. Tests on the ray test; look checked on the Ruins maps.
7. **Docs, translations, balance, review**: README (runes, salvage, fuse, the fade), roadmap and backlog, `locale/fr.po`, one light balance pass on the essence numbers, `godot-code-review`.
