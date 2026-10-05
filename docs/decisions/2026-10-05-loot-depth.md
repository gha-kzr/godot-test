# Loot depth and see-through props (milestone 11) — decisions

Settled with the owner. The milestone takes the backlog's "Rune sets and power tiers" and "Rune economy" in a smaller shape (no sets for now) and pulls "See-through props and walls" forward from the World milestone.

| Decision | Choice | Why | Revisit when |
|---|---|---|---|
| Rune power | **Rune levels** (1 to 10): an owned rune is its file plus a level; its stats are the file's modifiers scaled by the level. No sets for now; rarity stays the slot rule (epic and legendary one per hero) and the drop weight | Power grows without a pile of near-identical files; sets and rolled effect tiers can come later on the same data | build variety is wanted (sets), or rolled effects |
| Scaling | Each level adds **20 % of the base amount** (level 10 = 2.8x), rounded, never below the base. **AP and MP never scale** (a +1 AP rune stays +1); so a rune whose amounts are all AP / MP **has no levels** (always level 1, no Fuse button), and a mixed rune (Focus: +1 AP, +5 Power) levels only its other effects | Flat AP / MP are the strongest stats in the game | the balance pass |
| In the code | A leveled rune is a `RuneData` copy (`level`, `base` = the file it comes from, scaled modifiers); level 1 is the file itself. So stashes, slots, tests and the UI keep working with `RuneData`. The save stores `{rune, level}` | Smallest change to a system many files touch | runes need per-instance data beyond a level |
| Where levels come from | **Drops follow depth** (`1 + enemy level / 5`, 20 % of drops one higher, capped at 10) **and fusing** raises a rune by one level | Both paths feed progression; the tower stays the main source | the tower's enemy levels change |
| Fusing | **3 identical runes** (same file, same level) **plus essence** make one at level + 1, up to level 10. Essence cost = the target level x 5 | Common copies become fuel; the cost paces it | the economy playtest |
| Salvage and essence | **Salvage replaces Drop**: throwing a rune away gives **essence**, by rarity and level (common 1, rare 3, epic 8, legendary 20, times the level). Essence is a counter in the profile, shown on the rune stash, spent only on fusing; milestone 12 may reuse it as its currency | The owner wanted salvage to feed a meta resource that fusing needs; one button, no wasted value | meta progression |
| Stash cap | **None**; fusing is the answer to a large stash | The owner's choice | the stash becomes unmanageable |
| See-through | Each physics frame, a ray from the camera to each living unit's feet and middle is cast against the board's colliders (a rock's own convex shape); the obstacles it meets first (up to three in a row) **fade**. Terrain never fades, and the hovered cell is not a target (the mouse only picks what is in front, so fading for it made rocks vanish at random). Obstacles under one world unit tall would not fade. Dither with `discard`, which also works on the web's Compatibility renderer. No outlines for now | Keeps the board readable once walls are real | hidden units still get lost (outlines) |

## Outcome
- `RuneData` has `level`, `base` and `leveled()` (a copy with scaled amounts; level 1 is the file), `title()`, `salvage_value()`, `fuse_cost()` and `level_for_enemy()`; `Profile` has `essence`, `salvage_rune()`, `fuse_group()` / `fuse_error()` / `fuse()`, and saves `{rune, level}` and the essence. `UnitReward.enemy_level` feeds `BattleRewards`.
- The rune stash shows each rune on two lines (the rune, then Fuse and Salvage), the essence counter, and keeps up / down on the runes; QA gives runes at a level and essence.
- `ObstacleFade` (`scripts/view/obstacle_fade.gd`) fades the obstacles `BoardView.look_through()` finds with physics rays toward each living unit (feet and middle). Alpha hash is drawn opaque by the Compatibility renderer, so it uses plain alpha blending there.
- Balance, one light pass by reasoning (no simulation): level 10 needs enemy level 45; fusing a level costs 3 of the last one, so levels 2 to 4 are within reach by fusing while higher ones come from the tower; salvaged epics and legendaries (8 / 20 essence per level) pay for most fusing. Numbers are constants in `RuneData`.
- Left in the backlog: rune sets and rolled effects, other uses for essence, a stash cap or sorting, props and outlines for the fade.

## Playtest fixes (same milestone)
- The first fade tested a box around each rock and the hovered cell: rocks "disintegrated" next to units and under the mouse. Replaced by the rays above.
- Identical runes are the same resource, so the salvage question looked up the first copy: it opened on the wrong row (out of sight, so "nothing happened"). The stash now tracks the clicked row, keeps the question's row as tall as the rune row it replaces, and keeps the list scrolled where it was.
- The Fuse button shows for every rune that has levels and says what is missing; flat AP / MP runes have no levels.
- The hub fits a small window: rune slot names clip instead of widening the screen, the stash is 300 px wide at least; the sound button lines up with the achievements button.
