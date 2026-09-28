# Roadmap

**Goal:** a small but polished tactical roguelite. A run is a series of procedural battles (maybe endless); on death the run restarts from scratch, but the player keeps level and loot.

**Done:** the tactical RPG vertical slice — see [`plans/2026-09-27-tactical-rpg-slice.md`](plans/2026-09-27-tactical-rpg-slice.md). Its "After the slice" section holds the detailed design notes referenced below.

**Scope guard:** one biome, 4–6 enemy types, ~10 spells, 2–3 heroes, a short run. Ship that polished before widening.

Each milestone starts by settling its open decisions (`godot-grill`), then a plan (`godot-brainstorming`), then implementation task by task, then a `godot-code-review` pass.

## Milestones

The order follows dependencies: each milestone needs the systems of the ones before it.

### 1. Combat depth — done
Implemented per `plans/2026-09-28-status-effects.md` (all tasks checked; a hand playtest remains).

- **Status effects** (DoT first, then buffs / debuffs) — decisions in `decisions/2026-09-28-status-effects.md`, plan in `plans/2026-09-28-status-effects.md`. Includes, from the reviews: AI scoring of statuses (a pure DoT spell scores 0 today and would never be cast), a single event-dispatch point, the turn-start death loop, live HUD updates during playback.
- **Inspect any unit on hover** — show any unit's stats (enemies included) in the side panel.

*Why first:* completes the combat rules while the code is fresh; statuses change the spell data model, which the skill tool will build on.

### 2. Progression model — done
Decisions: `decisions/2026-09-28-progression.md`; plan: `plans/2026-09-28-progression.md`.
- Unit stats (e.g. power, defense), levels and XP.
- Spell scaling formula (damage / heal growing with stats or level).
- Items and equipment that modify stats; loot drops.

*Why here:* this is the core of "keep level and loot", and both design tools need it.

### 3. Design tools
- **Skill designer** — area of effect (visual shape preview), power, scaling; previews such as damage per AP at each level. Slice plan item 5.
- **Enemy designer** — level, stats, loot table, XP given on death, difficulty presets (normal / elite / boss). Slice plan item 6.

*Why here:* content volume grows from now on; tools built on a stable data model don't need rework.

### 4. Run loop (roguelite)
- Procedural map generator (connectivity-checked, previewed in the editor — the preview part of slice plan item 3; the map painter is mostly replaced by generation).
- Encounter generator: enemy presets and a difficulty budget that grows with depth. **The first battles must be easy** (playtest feedback: the slice battle is too hard as a first fight); the slice's 10–10 AI-vs-AI tuning is a mid-difficulty baseline, not the opening experience. Levers: encounter budget, enemy presets, a gentler AI profile early.
- AI difficulty profiles and smarter strategies — slice plan item 2.
- Run flow: battle → reward choice → next battle; death → hub, keeping level and loot.
- Saving between battles.

*Why here:* everything it needs exists by then — this is when the game becomes the game.

### 5. Polish
- Assets: unit models and animations, spell VFX, particles, sound, board tiles — slice plan item 4 (display polish and asset integration).
- UI theme and spell icons; title, hub and settings menus.
- Balance pass, first-run hints, exported builds.
- Small UX items from the reviews: rebindable click and spell keys, right click over the HUD cancels aiming, a hint when a unit has nothing left to do.

*Why last:* polish on stable mechanics isn't wasted. The "small but polished" goal lives here.

Some early placeholder art (one model, one spell effect) can slot in anywhere; it's independent of the rest.

## Open questions

To settle with `godot-grill` before the milestone that needs them:

- **Milestone 2 / 4 — what persists on death:** character level only, equipped items, the whole inventory? What resets?
- **Milestone 4 — difficulty scaling:** keeping level and loot while enemies scale endlessly risks runaway power. Does difficulty follow run depth, player level, or both? Settle the difficulty curve here, starting easy.
- **Milestone 2 — party:** a fixed party of heroes (Knight, Mage) or a recruitable roster?
- **Milestone 4 — run length:** truly endless (depth as the score) or N battles ending with a boss?
- **Any time — stalemates:** if units can never reach each other the battle never ends; a turn limit or draw rule is undecided (map generation must keep maps connected meanwhile).
- **Undo:** the design keeps it cheap (command actions, views re-sync from state); decide whether the game wants it.
