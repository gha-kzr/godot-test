# Backlog

Features and ideas not built yet, in the order of the proposed milestones in [`roadmap.md`](roadmap.md). Each starts with a grill (`godot-grill`) and a plan before any code.

## Audio: sound effects, music and volume settings

*Milestone: 6b Feel: audio, effects and camera · Category: Audio · Pairs with: settings screen; credits*

Milestone 6b. Sound effects (UI clicks, hits, heals, spells, footsteps, deaths, turn start), music (hub, battle, victory / defeat stingers), and volume settings (master / music / effects, mute) in the settings screen; CC0 sources found and credited with the same safe-intake routine as the models (`docs/decisions/2026-10-01-art.md`). Grill first. Web browsers need a first click before audio plays (the title's Play press). Best timed together with the second pass on animation and effects.

## Second pass on animation, particles and spells

*Milestone: 6b Feel: audio, effects and camera · Category: Animation / VFX · Pairs with: audio (timed together)*

a quality pass on 6a's first version: better timing and blending of the character animations (walk, attack, cast, hit, death; victory and defeat poses at the result screen), richer particles (per-spell effects and projectiles through the existing `cast_effect` / `impact_effect` fields, screen feedback for big hits, status auras), and a look at the spells themselves (feel, readability, area shapes, new spell ideas). Best done with the 6b audio, since sound and effects are timed together.

## Camera follows a walking unit

*Milestone: 6b Feel: audio, effects and camera · Category: Animation / camera · Pairs with: camera rig*

the camera now slides to the acting unit at the start of each turn, but stays put while that unit walks, so a long move can leave the screen. Follow the unit along its path (the view position is already animated cell by cell in `UnitView.play_move`), probably by easing the focus point toward the unit during a move and stopping when the player pans; decide whether it applies to enemy moves too (likely yes) and whether to skip it for short moves that stay on screen. Touches `CameraRig` (a follow target) and `BattleController` / `EventPlayer` (start and stop around `UnitMoved`).

## Battle speed and quality of life

*Milestone: 7 First impressions · Category: UI / UX · Pairs with: event player timings, settings*

an animation speed setting (normal, fast, skip animations) in the settings and a quick toggle in battle, a faster enemy turn, and possibly an auto end-turn when a hero has nothing left to do (today End turn only pulses). Touches `EventPlayer` / `UnitView` timings (the queue's waits scale with the setting, animations keep playing on their own) and the settings screen. Small and pays off in long runs.

## Better tutorial and tooltips for the first levels

*Milestone: 7 First impressions · Category: UI / UX (onboarding) · Pairs with: hints, first floors*

today the only guidance is the prompt line and two one-time tips (hub, first battle). Improve the first floors: a short guided sequence (place, move, cast, end turn; reading the timeline, the unit cards, the damage preview and the path cost), contextual tips when a situation comes up for the first time (the first rune drop, the first status, the first elite and boss floor, the first level-up and new spell), and clearer tooltips on spells, statuses, stats and runes (what Power, resistance, AP and MP mean). Builds on `Hints` / `HintCard` (dismissals stored in the settings, "Show hints again"); questions for the grill: how intrusive (a scripted first battle vs tips only), keyboard and touch parity, and whether the first floors are also rebalanced to teach one idea at a time.

## Rename the game

*Milestone: 7 First impressions · Category: Branding · Pairs with: repo name, Pages address, save folder*

"Tower Tactics" is a placeholder; ideas: **Rune Ascent** or **Rune Ascend** (runes and the tower climb). To do when a name is chosen: `Game.TITLE` (the title screen), `application/config/name` and the window / web page title (the exported `index.html` takes it), the README and docs headings, the web build's page, and the icon if one is added. Two traps: changing `config/name` **moves the save folder** (`user://` is named after it), so keep saves by setting `application/config/use_custom_user_dir` with `custom_user_dir_name = "godot-test"` first (or migrate the files); and renaming the GitHub repo changes the Pages address (`gha-kzr.github.io/<repo>/`), so decide the repo name at the same time.

## Max floor reached and achievements

*Milestone: 7 First impressions · Category: Meta / UI · Pairs with: profile; feeds meta progression*

show the best floor reached (already recorded as `best_depth`: put it on the title and hub, per hero if useful) and a small achievements list (first boss, first elite, clear a floor without losing a hero, reach floor 10 / 20 / 30, equip a full rune set…), unlocked as the game goes, shown on a simple screen, saved in the profile (and optionally feeding the meta progression). Not a full run history.

## Choosing active spells (5-spell loadout)

*Milestone: 8 Hero depth · Category: Gameplay · Pairs with: level cap, hub, spell bar*

heroes will know more spells than they can bring: the player picks up to **5 active spells** per hero (a loadout, e.g. on the hub), the rest stay inactive. Touches `HeroRecord` (saved loadout), level rewards (a new spell goes to the loadout if there's room), the party screen and the HUD's spell bar (5 slots).

## Increase the level cap

*Milestone: 8 Hero depth · Category: Gameplay / balance · Pairs with: loadout, rewards content, balance*

heroes cap at level 10 (the XP table has 10 thresholds and the first tower reaches floor 10 at first, then 20, 30…). Raise it (20? 30?) with the XP curve, per-level rewards (stats, spells, the 4th spell at level 3 and +1 MP at level 6 today), enemy scaling per floor and the hub / run-screen displays; needs a balance pass and more `LevelReward` content per hero (so it pairs with the active-spell loadout item, which is how new spells would be handled).

## Movement spells: teleport, jump and more

*Milestone: 8 Hero depth · Category: Gameplay · Pairs with: height rules, enemy AI, enemy roles*

spells that move the caster (and later others): **teleport** (to a targeted free cell in range, ignoring obstacles, no path), **jump** (over obstacles or up high ground), charge / dash, swap places, push and pull. Rules in the battle layer (a new `MoveEffect` `EffectData`: the caster or the target moves, with its own events so the view animates it: a blink effect, a leap arc), range and line-of-sight rules for the destination, height rules (a jump can clear a drop or a climb the normal move can't), interplay with blockers and the AI's evaluation (`EnemyAI` must value positions). Pairs with the height system and the enemy roles (a charger, a blinker).

## Undo a move

*Milestone: 8 Hero depth · Category: Gameplay · Pairs with: command actions*

a hero can take back its move(s) as long as it hasn't cast anything this turn (Disgaea-style). The slice already kept actions as commands and views re-syncing from state so undo stays cheap (`decisions/2026-09-27-tactical-rpg-slice.md`, "Undo"); needs a snapshot of the unit before its first move, an Undo button / key, and the AI never using it.

## Enemy roles and team compositions

*Milestone: 9 Encounters · Category: Content / gameplay · Pairs with: new enemies, AI profiles, biomes*

the tower picks enemies from a pool at random. Give enemies **roles** (warrior / tank, healer, ranged, summoner, charger…) and build encounters from **compositions**: predefined teams that make tactical sense (for instance a healer always comes with a warrior to protect it, a ranged unit with a blocker), chosen per floor band, with elites and bosses having their own. Data: a role field on `EnemyData`, composition resources (`data/compositions/*.tres`: slots with role, level offsets, optional fixed enemy) referenced by the tower bands, and AI profiles per role (a healer prioritizes healing and keeps its distance); the generator fills the map from a composition. Not intent previews (those stay out of scope); questions for the grill: how many roles and enemy types at first, composition weights per band, how roles show in the UI (an icon on the card).

## Bigger maps

*Milestone: 9 Encounters · Category: Gameplay / content · Pairs with: props, map types, balance, AI speed*

generated floors are 8 to 11 cells wide (boss floors 12, ambush layouts 13) and the slice map is 10 × 9: small for a tactics game with 3 heroes against 2 to 3 enemies. Make them bigger where it helps (`MapGenSettings.min_size` / `max_size` / `boss_size` allow up to 30), with more enemies to fill them, longer approaches, more terrain and cover; check the camera (zoom limits, panning bounds already follow the board), the pathfinding and line-of-sight cost on larger boards, the AI's per-turn time, and balance (a bigger board slows fights). Best together with the props item above.

## More props and floor types

*Milestone: 10 World · Category: Art / content · Pairs with: biomes, bigger maps*

the maps feel empty: a single green terrain and a few rocks. Add floor variety (grass, dirt, stone, water-like or hazard tiles by theme, per-region or per-band looks) and props (barrels, chests, columns, bones, torches, trees; the Quaternius dungeon pack already has many, only five files are imported), placed by the map generator on cells that don't change the rules (decoration only), or with rules later (cover, hazards, slowing floors). Questions for the grill: purely visual first, or floor types with effects (a gameplay milestone); themes per tower band; how props avoid hiding units and the click targets. Touches `BoardTheme` / `BoardView` (floor variants, prop scenes), `MapGenerator` (decoration pass, a map-token or a separate layer), and credits.

## Map typologies from noise

*Milestone: 10 World · Category: Content / procedural · Pairs with: bigger maps, biomes*

generated floors are plateaus on flat ground. Add **map types** built from noise and shaped height fields, each a generator mode with its own settings: **mountain** (height rises to a peak at the centre, spawns on the foothills, ridges and slopes to fight over), **crater** (the opposite: a rim high around a low centre, fights down in or along the rim), **islands joined by bridges** (several raised islands over holes, narrow bridge cells as chokepoints), plus more to vary the board: **canyon / river** (a hole or low corridor splitting the map with a few crossings), **ruins** (many obstacle blocks forming rooms), **stairs / terraces** (concentric or linear steps), **maze-like corridors**, **open field**, **ridge line** (a long high wall of cells with gaps). Rules to keep: every floor cell reachable from the spawns (the connectivity check exists), climbs and drops within the limits (`Movement.MAX_CLIMB`, `MAX_DROP`), line-of-sight stays fair, and the start zone and enemy placement adapt to the shape. Touches `MapGenerator` (typology functions, `FastNoiseLite` seeded from the floor so floors stay deterministic), `MapGenSettings` (per-type settings, weights per tower band), the editor preview and the map tests. Pairs with bigger maps and props and floor types.

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

## Multiple games (save slots)

*Milestone: 13 Reach · Category: Core / profile · Pairs with: save format*

one profile today (`user://profile.json`, plus `settings.cfg` apart). Allow several saved games: a slot list on the title screen (New game, Continue, Delete, with each slot's summary: heroes' levels, best floor, a saved run), each slot its own profile file (`profile_<n>.json`, an index of slots in a small file), settings staying shared. Needs: a migration of the current save into slot 1, "Reset save" becoming per-slot, `Game` holding the active slot, the web build's storage (browser `user://`, per browser) and a limit on the number of slots; questions for the grill: how many slots, whether slots can be named or copied, and whether this is also meant as multiple players sharing one device. (If "multiple game" meant several runs in parallel inside one save, that is a different, larger design: say so.)

## Localization

*Milestone: 13 Reach · Category: UI / tech · Pairs with: every player-facing string; cheaper earlier*

translate the UI and content text (French first?). Godot's `TranslationServer` with CSV / PO files; every player-facing string goes through `tr()` (HUD, screens, `describe()` texts built from parts, content names as translation keys). Cheaper the earlier strings are routed through `tr()`.

## Gamepad support

*Milestone: 13 Reach · Category: Platform · Pairs with: focus navigation already on screens*

Screens already navigate by focus (arrows / Enter / Esc, the `ui_*` actions). Still needed: gamepad bindings in the input map, in-battle navigation (a cursor over cells, cycling targets and spells, End turn), button prompts that follow the device, and the settings' rebinding list for pads.

## Android and touch

*Milestone: 13 Reach · Category: Platform · Pairs with: camera drag already shaped for it*

The camera drag and the no-hover-only rule are already built with touch in mind (`docs/decisions/2026-09-30-screens.md`, Platforms). Still needed for a touch build: two-finger pan and pinch zoom, a touch layout for the HUD and screens (larger targets, no Esc or keyboard shortcuts), the Android export preset and a device check, and the Compatibility renderer's look on phones.

## Balance pass and release checks

*Milestone: 14 Balance and release · Category: Balance / release · Pairs with: content stable*

Milestone 7. A balance pass with playtests and the balance lab (tower bands, boons, presets, the slice baseline), then release checks: an export filter for `addons/` (the web preset already excludes `addons`, `tests`, `docs`, `tools`), UID save references checked in a real export, a golden test pinning generated floors across engine upgrades. Best once content and UI stop moving; the web build is already published (`tools/export_web.sh --publish`).
