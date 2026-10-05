# Model workshop (milestone 9e) — decisions

Settled with the owner. Reason for the milestone: the hand-built models (9d) are drafted from code, so refining a part's position, a color or a pose means editing a recipe and rebuilding; polish should not need a code change, and a rebuilt draft must not lose it.

| Decision | Choice | Why | Revisit when |
|---|---|---|---|
| Where it lives | A **standalone scene** (`scenes/tools/model_workshop.tscn`), like the spell stage, built on the model stage: run from the editor (F6) or the CLI | No plugin code; works in a plain window; same pattern as the other tools | the workshop is wanted inside the editor or in exported builds |
| Source of truth | **Recipe + a tweaks file** per model (`assets/models/<name>.tweaks.tres`), re-applied by `tools/build_models.gd` on every rebuild | Recipes stay readable text and define shapes; polish survives redrafts | a model is polished for good (an "eject" into a hand-edited scene can be added then) |
| Editing | **Sliders panel in the scene**: a tree of the model's joints and parts, sliders and a color picker for the selected one, a clip picker with a time scrubber, Reset, Undo, **Save** (writes the tweaks file) | Typing numbers into resource arrays is clumsy in 3D; sliders show the result live | gizmos in the 3D view are wanted |
| What a tweak changes | **Parts**: position, rotation, scale, color, emissive, hidden. **Joints**: rest position and rotation. Shapes (prism taper, blob radii) are not tweakable: scale covers it, the recipe defines the solid | Covers the polish seen so far without each part remembering how it was built | a creature needs reshaping that scale cannot give |
| Keys and renames | A tweak is keyed by the node's **name path** under the model root (`Rig/Hips/Head/Helmet`; a part name is only unique under its joint). A path that no longer exists is an **orphan**: the build and the workshop list it, the file keeps it; a `renames` table in the file (old path → new path) maps it by hand | Nothing is lost silently; no guessing | many renames make the table a chore |
| Animation edits | **Per-model pose overrides** in the tweaks file: (clip, time, joint, rotation / position offset), applied on top of the clip set when the animations are built; the shared clip sets (`BipedClips`…) stay in code | Polish one creature's attack without touching the others | clip sets move to shared tables (`.tres`) with the animation upgrades |
| Order | The tool first, then the animation upgrades (easing, follow-through, anticipation, two-segment limbs) in the same milestone | The workshop makes tuning those faster | — |

## Notes
- Rest tweaks must be in place **before** the clips are made (clips are offsets from the joints' rest), so the tweaks apply when `RigAnimator.build()` runs, not after the recipe returns.
- Not translated: a developer tool, like the model stage and the spell stage.

## Outcome
- `NodeTweak`, `PoseOverride` and `ModelTweaks` (`scripts/tools/modeling/`) hold the polish; `ModelKit.apply_tweaks()` applies it once, before the clips are made; `ModelBuilder` is the code shared by `tools/build_models.gd` and the workshop; `tests/test_model_tweaks.gd` checks that every committed tweaks file still fits its recipe.
- `WorkshopSession` (`scripts/tools/model_workshop_session.gd`) has the rules without any UI (draft, undo, pose overrides, orphans, save), tested in `tests/test_model_workshop.gd`; `ModelWorkshop` (`scenes/tools/model_workshop.tscn`) is the screen, tested in `tests/test_model_workshop_scene.gd`. How to use it is in the README.
- `tools/build_models.gd` leaves a scene alone when it only differs by Godot's random node ids (rebuilds no longer make a diff of every model).
- Animations: a pose's optional third value, `RigAnimator.SNAP` / `SETTLE`, gives strikes, wind-ups, recoveries, falls and hops their easing in the three clip sets.
- Moved to the backlog: follow-through, squash-and-stretch, two-segment limbs, per-creature attack feel and a higher detail tier ("Better animations"). Gizmos in the 3D view, and reshaping a solid, were not needed yet.
