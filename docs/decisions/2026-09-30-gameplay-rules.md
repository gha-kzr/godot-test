# Gameplay rules pass (milestone 5c) — decisions

A mini milestone on two rules from the roadmap's "Future features", found in playtests. Reopens the line-of-sight row of [`2026-09-27-tactical-rpg-slice.md`](2026-09-27-tactical-rpg-slice.md) (obstacles always block) and the rune rule of [`2026-09-29-run-loop.md`](2026-09-29-run-loop.md).

| Decision | Choice | Why | Revisit when |
|---|---|---|---|
| Scope | **Line of sight** and **runes during a run**, plus what the playtests find. Undo, the 5-spell loadout and localization stay separate (each gets its own grill) | Small, both already specified | — |
| Obstacle shape | A **full 1 × 1 × 1 cube**: one cell wide and deep, exactly **two height levels** tall (a level is half a cell, so one world unit). The drawn block, its pick collider and the line-of-sight rule all read the same integer height from the grid (`Grid.obstacle_levels(cell)`), no 0.9 block, no half steps | One number, nothing to keep in sync; the drawn block is what blocks | two-cell-high objects are wanted: the function returns a per-cell value then (map token or data) |
| Line of sight | An obstacle blocks like terrain rising to its top (cell height + `obstacle_levels`), so high ground sees over low blocks; units still always block, holes never; eyes at +1.5 and body at +1.0 levels as before. Targeting, the AI and the damage preview share `Targeting`, so they follow | Fixes the Ranger on a raised cell who couldn't shoot over a block (floor 6) | playtests |
| Block height on the map | A map token may carry the block's base height: `2#` is a block on a cell at height 2 (a bare `#` stays on level 0). The generator writes it, so a block on a plateau rises from the plateau instead of sinking to level 0 | The review found generated blocks next to level-3 plateaus lower than their neighbours | — |
| Line-of-sight sampling | As for terrain, a cell is tested at the sight height at the middle of the segment inside it, and grazing the top passes; this errs toward the player (a steeply descending ray can clip the far face of a cube). Out-of-bounds cells always block | Keeps one rule for terrain and blocks; predictable for players | playtests show shots through corners that feel wrong |
| Runes during a run | **Allowed between floors, never during a fight**: a **Party** button on the run screen opens the hub (whose destination bar shows Continue run); there is no equipment UI in battle, so a rune can't be swapped mid-fight (no damage rune, cast, swap to defense) | Fresh loot is usable at once; the old hub workaround becomes the rule | — |
| Max HP changes | **Current HP stays**, capped to the new maximum **when the rune changes** (so unequip then re-equip can't bring the capped HP back); no heal on gaining max HP, and a hero saved as "full" (-1) is first turned into its current maximum, so it can't get the bigger one for free | Stops the swap-heal exploit; keeps floor-to-floor HP pressure | — |

## Open / deferred
- Taller obstacles (two cells high): rule is ready (`obstacle_levels`), map syntax and art later.
- Undo a move, the active-spell loadout, localization — separate grills.
