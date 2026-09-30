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

### 3. Design tools — done
Decisions: `decisions/2026-09-29-design-tools.md`; plan: `plans/2026-09-29-design-tools.md`.
- **Skill designer** — area of effect (visual shape preview), power, scaling; previews such as damage per AP at each level. Slice plan item 5.
- **Enemy designer** — level, stats, loot table, XP given on death, difficulty presets (normal / elite / boss). Slice plan item 6.

*Why here:* content volume grows from now on; tools built on a stable data model don't need rework.

### 4. Run loop (roguelite) — done
Decisions: `decisions/2026-09-29-run-loop.md` (stages + infinite tower; supersedes the bullets below where they differ); plan: `plans/2026-09-29-run-loop.md`.
- Procedural map generator (connectivity-checked, previewed in the editor — the preview part of slice plan item 3; the map painter is mostly replaced by generation).
- Encounter generator: enemy presets and a difficulty budget that grows with depth. **The first battles must be easy** (playtest feedback: the slice battle is too hard as a first fight); the slice's 10–10 AI-vs-AI tuning is a mid-difficulty baseline, not the opening experience. Levers: encounter budget, enemy presets, a gentler AI profile early.
- AI difficulty profiles and smarter strategies — slice plan item 2.
- Run flow: battle → reward choice → next battle; death → hub, keeping level and loot.
- Saving between battles.

*Why here:* everything it needs exists by then — this is when the game becomes the game.

### 4.5. Walking through allies and starting positions — done
Decisions: `decisions/2026-09-29-allies-and-placement.md`; plan: `plans/2026-09-29-allies-and-placement.md`.
- Units walk through their allies (enemies still block).
- A placement phase before each battle: heroes pre-placed by role in a 3 × 3 start zone, rearranged by the player, then Ready. Generated maps vary the zone's layout (facing edges, corners, ambushes).

*Why here:* both change the rules; polish should come after the mechanics settle.

Milestone 5 used to be one "Polish" milestone; it is split in three. Earlier decision records and plans that defer items "to M5" mean the matching part below: UI and UX items → 5, art and audio → 6, balance, exports and release checks → 7.

### 5. UI and UX revamp — done
Decisions: `decisions/2026-09-30-ui-revamp.md` and `decisions/2026-09-30-screens.md`; plans: `plans/2026-09-30-battle-ui.md` (5a) and `plans/2026-09-30-screens.md` (5b). Split in **5a battle** (HUD, timeline, unit cards, status icons, damage preview, move costs, guidance) and **5b screens** (theme, title, hub, run screen, settings, first-run hints).
- UI theme, fonts and spell / status icons; title, hub (party screen), run screen and settings menus — the first-version screens from M2 and M4 are replaced.
- Battle HUD: an event-driven refresh (events carrying "after" values, status countdowns mid-playback), the status display and unit inspection panels redone, the preset tag color, a lasting sudden-death tag, the placement phase's hints.
- Readability: move costs on the hovered path (see "Clearer climbing cost" below), first-run hints, a hint when a unit has nothing left to do.
- Small UX items from the reviews: rebindable spell keys (rebindable click is not built), right click over the HUD cancels aiming, keeping the selected hero across screens, spells in the level-up summary, self-buff turns wording.
- Platforms: built for desktop and web first, then maybe Android, later gamepad (same platforms). Nothing is hover-only, layouts are anchored, and platform differences live in `SettingsApplier` / `OS.has_feature`; a web export must include `CREDITS.md` (shown in the settings) and `user://` persists as browser storage.

*Why here:* the screens are placeholders over stable mechanics; independent of the art, so 5 and 6 can swap order.

### 6. Art and audio
- Replace the placeholder capsules and boxes: unit models and animations (idle, walk, cast, hit, death) through `UnitData.model_scene`, board tiles and props through `BoardTheme` — slice plan item 4 (display polish and asset integration).
- Spell VFX and particles, hit and heal feedback; sound effects and music.
- Visual scale for elites and bosses carried to labels, pick colliders and status tags.

*Why here:* the display already reads everything from data (`model_scene`, `BoardTheme`), so assets slot in without rule changes; independent of the UI revamp.

### 7. Balance and release
- Balance pass with playtests and the balance lab (tower bands, boons, presets, the slice baseline).
- Exported builds (`export_presets.cfg`), an export filter for `addons/`, UID save references checked in a real export, a golden test pinning generated floors across engine upgrades.

*Why last:* balance and builds are only final once the content and UI stop moving. The "small but polished" goal lives in 5–7.

Some early placeholder art (one model, one spell effect) can slot in anywhere; it's independent of the rest.

## Future features

Ideas to schedule into a milestone (grill them first):

- **Clearer climbing cost** — a climb costs 1 extra MP per level, so a 3-cell move can spend 4 MP, and players can't tell why (playtest feedback). Either drop the extra cost (climbing costs a normal step; the climb and drop limits stay), or make it readable: the MP cost shown next to the hovered path (e.g. "4 MP"), climbing steps marked on the path, and the reachable area shaded by cost. Deciding means weighing height as a tactical lever against readability; the AI and balance follow the rule either way.

- **Choosing active spells** — heroes will know more spells than they can bring: the player picks up to **5 active spells** per hero (a loadout, e.g. on the hub), the rest stay inactive. Touches `HeroRecord` (saved loadout), level rewards (a new spell goes to the loadout if there's room), the party screen and the HUD's spell bar (5 slots).
- **Obstacles block line of sight only up to their top** — today an obstacle always blocks, even when the caster stands higher and visibly sees over it (playtest: the Ranger on a raised cell couldn't shoot past a block below it, floor 6). An obstacle should block like terrain rising to its drawn top (its cell height + its block height), so high ground sees over low blocks. Reopens the slice's line-of-sight rule (`decisions/2026-09-27-tactical-rpg-slice.md`); the AI and targeting previews follow the rule.
- **Undo a move** — a hero can take back its move(s) as long as it hasn't cast anything this turn (Disgaea-style). The slice already kept actions as commands and views re-syncing from state so undo stays cheap (`decisions/2026-09-27-tactical-rpg-slice.md`, "Undo"); needs a snapshot of the unit before its first move, an Undo button / key, and the AI never using it.
- **Localization** — translate the UI and content text (French first?). Godot's `TranslationServer` with CSV / PO files; every player-facing string goes through `tr()` (HUD, screens, `describe()` texts built from parts, content names as translation keys). Cheaper the earlier strings are routed through `tr()`.
- **Runes during a run** — today runes can't be changed between floors, but the player can leave to the hub, re-equip, and continue the run: a workaround that makes the rule meaningless. Pick one, consistently: (a) **allow** equipping between floors (a Party button on the run screen) — found loot is usable right away; or (b) **lock** rune changes while a run is saved (the hub shows them read-only until the run ends or is abandoned). Recommended: (a), since players already can and fresh loot is part of the fun.

## Open questions

To settle with `godot-grill` before the milestone that needs them:

- **Milestone 2 / 4 — what persists on death:** character level only, equipped items, the whole inventory? What resets?
- **Milestone 2 — party:** a fixed party of heroes (Knight, Mage) or a recruitable roster?
- **Undo:** the design keeps it cheap (command actions, views re-sync from state); decide whether the game wants it.
