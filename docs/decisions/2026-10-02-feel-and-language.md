# Feel and language (milestone 6b) — decisions

Milestone 6b of [`docs/roadmap.md`](../roadmap.md): audio, a second pass on animation and effects, the camera following a walking unit, and localization (moved here from "Reach" so that every later string is written with `tr()`). Features are described in [`docs/backlog.md`](../backlog.md); art decisions (sources, safety, style) are in [`2026-10-01-art.md`](2026-10-01-art.md).

| Decision | Choice | Why | Revisit when |
|---|---|---|---|
| Structure | **One branch, `milestone-6b`**, commits in this order: localization, camera, effects tooling and polish, audio | Strings written during the other tasks already go through `tr()` | a task grows enough to deserve its own milestone |
| Languages | **English (source) and French** | The owner plays in both | more languages are wanted: one more `.po` file |
| Translation format | **gettext `.po` files in `locale/`, English source text as the message id** (Godot's recommended workflow for source-text keys); `tr()` / `tr_n()` in code, `auto_translate_mode` on Controls, `tr(text, context)` where one English word has two meanings. A `tools/extract_strings.gd` script rebuilds `locale/messages.pot` from `tr()` calls and from content `.tres` files; a test fails when a French entry is missing or a string has no id | Source-text ids need no extra step for a designer (a new spell just works, falling back to English); `.po` handles plurals and context | designers want key-based tables |
| What is translated | **All of it**: screens, HUD, hints, settings, the generated descriptions (`describe()` built from translated templates with placeholders, never glued fragments), and content names (`display_name` of heroes, enemies, spells, runes, boons, statuses, stages, damage types) | The owner chose full coverage | — |
| Language choice | The OS / browser language when it is English or French, else English; a **Language** row in the settings overrides it and is saved in `settings.cfg` | Works with no setup, never traps the player | — |
| Font | The UI font must cover French accents (checked in the first task; swapped or extended with a fallback font, credited, if not) | A broken glyph would defeat the translation | — |
| Audio | **Sound effects** (UI clicks, hits, heals, casts, footsteps, deaths, turn start), **one hub track, one battle track**, victory and defeat stingers; sliders for master, music and effects and a mute in the settings, saved in `settings.cfg`. CC0 from OpenGameArt, Kenney or similar through the safe-intake routine of the art record; I shortlist candidates and the owner picks by ear before anything is committed. Web audio starts at the title's Play click | Covers the whole loop cheaply; the web build needs a user gesture | the owner commissions music |
| Effects scope | **Polish of the existing 15 spells**, no new spells (those belong to milestone 8): animation timing, per-spell effects and projectiles through `cast_effect` / `impact_effect`, screen shake on big hits, status auras | Stays in "feel" | — |
| Effects tooling | An **editor tool to adjust and preview a spell's animation and particles in context** (see below) | The owner wants to tune spells visually, not by trial and error in battles | — |
| Camera follow | Follows **every move, allies and enemies**; eases toward the walking unit and **stops following as soon as the player pans**; skips moves that stay on screen. During enemy turns the camera never whips between units: every focus change glides for at least 0.4 s and holds for 0.3 s, and a move whose whole path is already inside the visible area does not move the camera at all, so a run of enemy moves in one area produces one glide, not many. | The owner fears a dizzying camera during enemy turns | playtest says otherwise |

## Effects tooling (assumed from the owner's wish: "adjust and visualize a spell animation and particles in the Godot engine, drag and drop an animation file, cut it")

| Decision | Choice | Why |
|---|---|---|
| Preview | A **Spell stage**: a scene (`scenes/tools/spell_stage.tscn`, run from the Design panel's button or with F6; the Game tab shows it inside the editor) that plays the cast through the real rules and the real `EventPlayer` (same code as a battle), so what is previewed is what ships. It reloads by itself when the spell or its effect files are saved on disk, and has a speed slider and a loop. **Changed from the first draft** (a dock inside the editor): a running scene needs no `@tool` on the view scripts, which would have run inside the editor, and it is the game's own code path |
| Animation from another file | `SpellData.animation_scene` (optional): any imported model file (`.fbx`, `.glb`) dropped in the project; its animation is borrowed by the caster when the spell is cast, if the skeleton's bone names match (the Quaternius characters share one rig; mismatches are reported by the validation, never crash) | "Drop an animation file" without a retargeting system |
| Cutting | `SpellData` fields for the animation's **start and end time, speed**, and the **delay before the impact effects play**; all editable in the Inspector and visible at once in the Spell stage. Cutting a clip permanently in the file stays Godot's own Advanced Import dialog (Animation tab: split, trim, loop) | Data fields keep the choice per spell; the editor already owns file-level cutting |
| Particles | Effects stay scenes (`Fx` root + `CPUParticles3D`); the Spell stage reloads them on save so a particle edit in the editor shows at the next Play. A **projectile** is an optional scene a spell flies from the caster to the target before the impact | Native editor workflow, no custom editor |

## Outcome (owner's choices by ear)
- Sounds kept: UI click, hit, heal, footstep (quiet, pitch-varied, rate-limited), defeat jingle. **Silent on purpose**: cast (played for every spell, found annoying), death, turn start, victory (no candidate liked). Music: hub, ordinary battle (Battle Theme B) and boss floors / stages (Battle Theme A: too fast for ordinary floors).
- Mid-tempo battle music was a second sampler round; Battle Theme A moved to a new `boss` track.

## Open / deferred
- Sounds for cast, death, turn start and victory; per-spell sounds — backlog entry "Sound and animation leftovers".
- Camera glide and hold times (0.4 s / 0.3 s) are first guesses, tuned by playtest.
- New spells — milestone 8.
- More languages — one `.po` file each, no code.
