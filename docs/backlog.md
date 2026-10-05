# Backlog

Features and ideas not built yet, in the order of the proposed milestones in [`roadmap.md`](roadmap.md). Each starts with a grill (`godot-grill`) and a plan before any code.

## Sound and animation leftovers

*Milestone: 14 Balance and release, or any (it is small; left out of milestone 8 because the owner couldn't test sound) · Category: Audio / animation · Pairs with: audio set, unit model*

What milestones 6b to 7 left out on purpose: **turn start** stays silent (no candidate liked); a smoother blend between clips (walk to attack); the death sound is heavy, so its gain (`sfx_gain_db`) may need adjusting by ear. Hub and title share one track on purpose.

## Better animations

*Milestone: 14 Balance and release, or any · Category: Animation · Pairs with: clip sets, model workshop*

Easing is in (9e: `SNAP` and `SETTLE` on strikes, wind-ups and recoveries) and one creature's poses can be hand-tuned in the model workshop, but the clip sets are still short lists of poses. Left, in order of cost and payoff: follow-through (the head, tail and plume lag behind the body: a plume or a tail needs its own joint, and a follower track derived from the body's with a delay); anticipation and squash-and-stretch on landings; two-segment limbs (elbows and knees: more parts per creature, the biggest quality jump); per-creature attack feel (a heavier swing for the Brute and the Yeti, as shared tables or as tweaks); a smoother blend between clips. Possibly a higher detail tier for the solids (bevels, lathes, smooth shading) if the style should grow.

## More props and floor types

*Milestone: 10 World · Category: Art / content · Pairs with: biomes, bigger maps*

the maps feel empty: a single green terrain and a few rocks. Add floor variety (grass, dirt, stone, water-like or hazard tiles by theme, per-region or per-band looks) and props (barrels, chests, columns, bones, torches, trees; props are drawn with the own-models kit (`ModelKit` recipes)), placed by the map generator on cells that don't change the rules (decoration only), or with rules later (cover, hazards, slowing floors). Questions for the grill: purely visual first, or floor types with effects (a gameplay milestone); themes per tower band; how props avoid hiding units and the click targets. Touches `BoardTheme` / `BoardView` (floor variants, prop scenes), `MapGenerator` (decoration pass, a map-token or a separate layer), and credits.

## See-through props and walls

*Milestone: 10 World · Category: Art / camera · Pairs with: props, ruins, camera*

today obstacles are low rocks, so the board stays readable from every camera angle; once the ruins' blocks (and props such as columns or trees) become real walls, they will hide the units, the cells and the hover behind them. When something stands between the camera and a unit or the hovered cell, fade it (dithered or alpha transparency, or a cut-out circle around the units: the usual x-ray / occlusion fade of isometric tactics games), and maybe show hidden units as outlines. Questions for the grill: which objects fade (every prop and obstacle, or only tall ones), fade by camera ray to each unit and the cursor or by a screen-space circle, outlines for hidden units, the cost on the web build's Compatibility renderer. Touches `BoardView` (obstacle materials), `UnitView` (outlines), the camera rig (rays), and the shaders.

## More map typologies

*Milestone: 10 World · Category: Content / procedural · Pairs with: biomes*

milestone 9b brought six typologies from seeded noise (open field, mountain, crater, islands and bridges, canyon, ruins: `data/maps/typologies/`, `MapShapes`). Add more (owner's note): **stairs / terraces** (concentric or linear steps), **maze-like corridors**, **ridge line** (a long high wall of cells with gaps), and let biomes pick their own. The same rules hold (every map checked for two-way reachability and the enemies' walk, redrawn from the same seed), and the floor fingerprints test changes on purpose when bands' weights change.

## Biomes that change every X floors

*Milestone: 10 World · Category: Content · Pairs with: props, map types, enemy roles*

the tower changes setting every few floors (for example every 10, with the boss): forest, desert, ice, volcano, crypt, sky ruins. A biome sets the **look** (`BoardTheme`: floor colors and textures, props, obstacle models, lighting, background), the **map typologies** it favours (volcano craters, ice islands), the **enemy pool** and **compositions** (frost enemies in the ice biome), and maybe **hazards or damage-type modifiers** (fire biome: Fire resistance for enemies). Data: a `Biome` resource (theme, typology weights, enemy pool, props) referenced by the tower bands, chosen by floor number so floors stay deterministic; a transition moment (banner or short screen) when entering a new biome. Pairs with the props and floor types item, the typologies above, and new enemy content.

## Rune sets and rune power tiers

*Milestone: 11 Loot depth · Category: Gameplay / content · Pairs with: save format, loot, hub*

two independent ideas on runes. **Sets**: runes belong to a set (Fire, Guardian…), and wearing several pieces of a set grants bonuses (2 / 4 pieces), independent of a rune's rarity. **Power tiers**: every effect a rune gives has its own rarity tier (normal power, rare power, epic, legendary: the same stat comes in tiers of strength, e.g. +4 / +8 / +14 Power), so a rune is a set, a main effect with a tier, and perhaps secondary effects with their own tiers. Touches `RuneData` (a set, effect tiers), the drop rules (`LootTable`: roll the tier per effect, rarity weights), the hub (set bonus display, tier colors on each effect), balance, and the save format (runes would need to save their rolled tiers, not only a file path). Questions: how many sets and pieces, whether rune rarity (the slot rules: epic and above one per hero) stays separate from effect tiers, fixed or rolled effects.

## Rune economy: sell, fuse, stash cap

*Milestone: 11 Loot depth · Category: Core loop · Pairs with: a currency decision; meta progression*

dropping a rune is done (5d), but the stash can still grow large, and a dropped rune is just gone. Options to grill: (b) **sell** runes for a currency — needs something to spend it on (a shop for runes? a level-up or respec cost? run boons?), so it is really an economy milestone; (c) **salvage / fuse** runes (three commons into a rare) — keeps runes as the currency, no money needed; (d) a **stash cap** that forces the choice (with the hub warning when full). Questions: is a currency wanted in the game at all, what would it buy, and is the stash a collection or just an inventory? Touches `Profile` (stash, save format), `RuneStash` and the drop rules (`LootTable`).

## Meta progression

*Milestone: 12 Run structure and meta · Category: Core loop / meta · Pairs with: currency, achievements, new heroes*

lasting upgrades between runs. A currency or points earned by runs (floors cleared, bosses, achievements) spent on hub upgrades (starting stats, extra rune slots, a better starting rune, shop discounts), unlocks (new heroes, new spells in the pool, new boons, harder tiers), kept in the profile and shown on a hub screen. Needs a grill on what runs earn and what can be bought so the game stays about skill; it links to the rune economy (a currency), the level cap, and the new heroes and enemies.

## Branching run map (to elaborate)

*Milestone: 12 Run structure and meta · Category: Core loop · Pairs with: rune economy, meta progression; needs a full grill*

the tower is a straight line of floors. The idea: between floors, choose a path on a small map (Slay the Spire style): normal fight, elite (harder, better loot), rest (heal), shop or a rune forge, mystery event, boss at the end. It would make a run a series of decisions and give use to the rune economy and the boons. Open and to be elaborated before anything is built: how long a run is (still floors of 10 with a boss? a map per act?), how paths branch and how much is visible ahead, what the non-fight nodes do (and so what currency and items exist: this depends on the rune economy and meta progression), how it fits the deterministic floors-by-number design (daily seeds, the "same for everyone" rule), whether endless climbing stays, and how the run screen and `RunState` / `RunDirector` change (the saved run would store the map and the position). Needs a full grill.

## Clearer achievement unlock

*Milestone: 13 Reach · Category: UX / feedback · Pairs with: achievements, toasts, audio*

an achievement unlock gets a notification or popup the player can't miss. Today a unlock shows a small toast for 3.5 seconds at the top of the screen (`Game`, `TOAST_SECONDS`), which is easy to miss in the middle of a battle result or the run screen, where it also overlaps the title. Ideas: a popup card with the achievement's name, description and icon that stays until dismissed or for longer, a sound (a short jingle in the audio set), a queue when several unlock at once (a boss floor can unlock two), showing it again in the achievements list as "new" until seen, and not covering the result or run screen's buttons. Question for the grill: whether it should block (like the tips) or stay passive but more visible. Every new text needs its French translation.

## Visualize status effects

*Milestone: 13 Reach · Category: UX / battle readability · Pairs with: statuses, unit cards, tooltips*

a way to see at a glance which statuses a unit carries and what they do (poison, a shield like Sheltered, slows, buffs). Today a status shows as a small icon with its turns left above the unit, a soft looping aura and a line on the unit card. Ideas: a clearer icon set and colors (positive vs negative), a hover tooltip on the icon with its name, effect and turns left (also on the turn order's chips), a stack of icons that stays readable with 3 or more statuses, a "what this status does" glossary reachable from the card, a preview of the statuses a spell would apply or remove (already a hint while aiming), tick numbers floating when poison or regeneration fires, and a distinct aura per status so a unit's state reads from the board. Question for the grill: how much to show on the board before it gets cluttered, and whether colour-blind-safe shapes are needed.

## Multiple games (save slots)

*Milestone: 13 Reach · Category: Core / profile · Pairs with: save format*

one profile today (`user://profile.json`, plus `settings.cfg` apart). Allow several saved games: a slot list on the title screen (New game, Continue, Delete, with each slot's summary: heroes' levels, best floor, a saved run), each slot its own profile file (`profile_<n>.json`, an index of slots in a small file), settings staying shared. Needs: a migration of the current save into slot 1, "Reset save" becoming per-slot, `Game` holding the active slot, the web build's storage (browser `user://`, per browser) and a limit on the number of slots; questions for the grill: how many slots, whether slots can be named or copied, and whether this is also meant as multiple players sharing one device. (If "multiple game" meant several runs in parallel inside one save, that is a different, larger design: say so.)

## Better tooltips and more hints

*Milestone: 13 Reach · Category: UX / onboarding · Pairs with: first-run hints, glossary tooltips, localization*

the one-time tip cards (hub intro, first status, elite and boss floors, level-up) are now modal: a dim blocks the screen until **Got it**. Improve them and add more. Improve: look and placement (a pointer to what the tip is about, the card next to it rather than a fixed corner), a short title per tip, several tips chained as a step-by-step when one topic needs it, a "Tips" list in the settings to reread any tip, and consistent wording with the glossary tooltips (AP, MP, HP, Power, resistances). More: spells screen and loadout, rune slots and rarities, cooldowns and movement spells, placement, line of sight and height, sudden death, boons, stages, the QA tools' first use. Questions for the grill: which tips must block (modal) and which can stay passive, how to avoid tip fatigue (a cap per session, skip all), and whether tips get illustrations. Every new text needs its French translation.

## Gamepad support

*Milestone: 13 Reach · Category: Platform · Pairs with: focus navigation already on screens*

Screens already navigate by focus (arrows / Enter / Esc, the `ui_*` actions). Still needed: gamepad bindings in the input map, in-battle navigation (a cursor over cells, cycling targets and spells, End turn), button prompts that follow the device, and the settings' rebinding list for pads.

## Android and touch

*Milestone: 13 Reach · Category: Platform · Pairs with: camera drag already shaped for it*

The camera drag and the no-hover-only rule are already built with touch in mind (`docs/decisions/2026-09-30-screens.md`, Platforms). Still needed for a touch build: two-finger pan and pinch zoom, a touch layout for the HUD and screens (larger targets, no Esc or keyboard shortcuts), the Android export preset and a device check, and the Compatibility renderer's look on phones.

## Balance observations from playtests

*Milestone: 14 Balance and release (the first two points may come earlier, with the level cap) · Category: Balance · Pairs with: level cap, area spells, tower bands, balance lab*

Notes from the owner's playtests, to turn into one balance pass (with the balance lab, `docs/decisions` records and `data/tower/tower.tres` bands):
- **Enemy levels vs hero levels:** on floor 20, a level 4 Brute (57 HP) has about the stats of the owner's level 10 hero, and a level 4 elite Brute (171 HP) more than that. It is not too hard (the fight was easy by kiting with the ranged hero), but a level that doesn't match the power it stands for feels wrong: a level 4 enemy should be clearly weaker than a level 10 hero, or levels should be shown differently. Related: the Knight died very quickly, so melee heroes seem too fragile next to ranged ones (enemy damage, HP growth, how enemies pick targets). Look at `hp_per_level` / `power_per_level`, the elite and boss presets and the band's `enemy_level` curve against hero growth, and how a level is displayed.
- **Area spells are not worth it:** a spell can be cast only once per turn, so two casts of a single-target spell out-damage one area spell unless three enemies stand in a cross, which is rare with so few enemies. Options to weigh: cheaper area spells (lower AP), higher damage per target, more enemies per floor, or bigger / better-shaped areas; the balance lab's damage-per-AP view (Inspector preview) helps compare.
- **Stage difficulty:** a stage should be much harder than the floors below it (the ones the player starts from once it is cleared) but simpler than the floors it unlocks above it. Today a stage plays like that floor's boss fight (`difficulty_floor`), which may not sit between the two; re-tune each stage's `difficulty_floor` / seed against the floors on both sides with the balance lab (Run tower from the unlocked start floor).
- **First stage too easy to reach (milestone 8 playtest):** the Ruined Gate (Porte en ruine) is easily won without ever clearing the first 10 tower floors, and clearing it lets runs start at floor 11 straight away. Options to weigh: require a cleared floor 10 before the first stage opens, raise its difficulty, or start the stages' unlocks from a higher floor.
- **Level cap:** raised to 100 in milestone 6c, with enemy levels re-tuned; new spells at levels 3, 5, 9 and 14 came with the loadout in milestone 8.

## Balance pass and release checks

*Milestone: 14 Balance and release · Category: Balance / release · Pairs with: content stable*

Milestone 7. A balance pass with playtests and the balance lab (tower bands, boons, presets, the slice baseline), then release checks: an export filter for `addons/` (the web preset already excludes `addons`, `tests`, `docs`, `tools`), UID save references checked in a real export, a golden test pinning generated floors across engine upgrades. Best once content and UI stop moving; the web build is already published (`tools/export_web.sh --publish`).
