# Own models (milestone 9d) — decisions

Settled with the owner after a prototype of three units (Knight, Warg, Ghost). Reason for the milestone: the downloaded packs mixed styles that did not go together (low-poly heroes, cartoon enemies, a smooth ghost, a realistic dog).

| Decision | Choice | Why | Revisit when |
|---|---|---|---|
| Source of models | **Built in the project**, from code: no downloaded 3D model, CC0 included. Each creature is a *recipe* (`scripts/tools/modeling/recipes/<name>.gd`) saved as a scene in `assets/models/` by `tools/build_models.gd` | One coherent style; the models are text, reviewable and editable; nothing to credit | the model workshop (next milestone) |
| Style | **Chunky and bold**: flat-shaded faceted solids, 3 to 5 colors per creature, one big silhouette piece (plume, hat, horns, cap, ears), a head about a third of a biped's height. Heroes keep their color identity | Reads from the tactical camera; much less minimal than cubes and capsules, much less detailed than the famous packs | a higher detail tier is wanted |
| Solids | `ModelKit`: `prism` (a tapering n-gon section: limbs, torsos, cones, boxes), `box`, `blob` (low-poly ellipsoid), `wedge` (ramp). Flat normals, one shared material per color (albedo × 0.62: the battle light is bright) | Five solids cover every creature so far | a creature needs lathes, lofts or smooth shading |
| Rigs | **Joints** (plain `Node3D`s named after the body part, `Arm.L`) with rigid parts, not a `Skeleton3D`. Three layouts: biped, quadruped, floater. Models face +Z, right side is -X | No skinning needed for rigid solids; held items hang from a joint | a creature needs bending bodies |
| Animations | **Procedural**: `RigAnimator` turns pose lists into the clips Idle, Walk, Attack, Cast, Hit, Death, Victory, Defeat (`BipedClips`, `QuadrupedClips`, `FloaterClips`). Every clip animates every joint any clip names, so none leaves a joint in another's pose | One code path for every creature; punchy; no dependency on a pack's bone names | the model workshop (easing, follow-through, two-segment limbs) |
| Dropped | Quaternius characters, monsters, props and dungeon rocks, their animations, the skeleton / bone-attachment path of `UnitModel`, `UnitData.skin_color`, the pack credits | Nothing uses them any more | — |
| Preview | `scenes/tools/model_stage.tscn`: units on tiles in the battle's light and camera angle, a turntable (`spin=1`), frozen poses (`anim=`, `at=`) | Compare and judge without a battle | — |

## Outcome
- `ModelKit`, `RigAnimator` and the three clip sets in `scripts/tools/modeling/`; one recipe per creature and per prop in `recipes/`; the built scenes in `assets/models/` (rebuilding keeps a scene's UID).
- `UnitModel` looks for a held item's hanging point among the model's joints (`held_item_bone = "Hand.R"`) and knows the `Cast` clip.
- `tests/test_modeling.gd`: solids closed and facing outward, every recipe saved, the full animation set on joints that exist, loops that close, a unit about as tall as its `model_height`.

## Open / deferred
- A **model workshop** (done in 9e: `docs/decisions/2026-10-05-model-workshop.md`).
- Higher detail tiers (bevels, lathes, smooth shading) and two-segment limbs (elbows, knees): see the backlog ("Better animations").
