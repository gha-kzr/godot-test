# First impressions (milestone 7) — decisions

Milestone 7 of [`docs/roadmap.md`](../roadmap.md). The pin-on-attack item left it (done in 6c); the web "Click to start" screen joined it.

| Decision | Choice | Why | Revisit when |
|---|---|---|---|
| Order | Battle speed → web "Click to start" → tutorial and tooltips → best floor and achievements → result poses → rename and branding last | The rename touches the save folder and the repo; the rest is independent | — |
| Battle speed | `Settings.battle_speed`: normal, fast (2×) and instant (animations skipped: the events still reach the HUD and the views are synced from the state). A toggle button in the battle HUD cycles them; the enemy turn follows. **Auto end turn** setting (off by default): ends the turn when the hero can neither move nor afford a spell | Long runs need comfort; the rules never depended on animation | — |
| Tutorial style | **Tips only, no scripted battle, but not avoidable on the first battle**: each step dims the screen except a spotlight (the control or board area to use), shows a card, and waits until the player does that action (Ready, move, pick a spell, cast, End turn); inputs outside the spotlight are blocked. A small **Skip tutorial** link always exists (a returning player isn't trapped); "Show hints again" replays it. Keyboard and mouse parity. Then non-blocking tips: timeline, unit cards, damage preview | The owner wants the first actions forced, not dismissable | touch is built |
| Contextual tips | One-time, dismissable: the first status seen, the first elite floor, the first boss floor, the first level-up with a new spell. **The rune tip** is a blocking step like the others: it fires when the first rune lands in the stash and waits for the equip | Teach when the situation exists | — |
| A rune to teach with | The **first victory always grants a starter rune** (`ProgressionConfig.first_rune`, data; the profile stores that it was given) | The equip tip used to appear before the player owned any rune | — |
| Tooltips | Hover explanations of Power, resistance, AP, MP and initiative (unit card, hub stats) and of statuses (effect and duration); spell and rune tooltips already exist | New players don't know the terms | — |
| Best floor and achievements | Best floor on the title and the hub; about a dozen achievements (first elite, first boss, floors 10 / 20 / 30 / 50, a floor won without losing a hero, a full rune set, levels 10 / 30, a stage cleared…) listed on an **Achievements** screen from the hub, a toast when one unlocks, stored in the profile (cleared by "Reset save") | Visible progress without a run history | meta progression |
| Name | **Rune Ascent**: title, window and web page name, docs. The save folder stays (`use_custom_user_dir` with the current folder name) so saves survive. **The GitHub repository name is left to the owner** (renaming it changes the Pages address) | The owner picked the name; safe save handling | the repo is renamed |
| Branding | Slots for the owner's **logo and title image** in `ui/branding/` (loaded when present; text title otherwise); the square logo can be set by hand as the window and web icon (`application/config/icon`); credited as the owner's artwork | The owner supplies the art | the files arrive |
| Web "Click to start" | Web only: a minimal bilingual screen before the title; the click lets the browser play sound, so the title music starts from the beginning | Browsers block audio until a gesture | — |
| Result poses | On the result screen the survivors play their **Victory** animation (heroes after a win, enemies after a loss) while the fanfare plays. Not planned: smoother clip blending, a separate hub track; turn start stays silent | Cheap and visible | the owner asks |

## Outcome
- Battle speed, web start screen, tutorial (five blocking steps in the first battle, one in the hub), starter rune, contextual tips, glossary tooltips, achievements (12), best floor, result cheers and the rename are in. Branding files are slots until the owner provides them.
- Smoother clip blending is **not** done and the hub shares the title's music (the owner agreed).
- The save folder is kept with `custom_user_dir_name = "Godot/app_userdata/godot-test"` (the plain name would have moved it to `~/Library/Application Support/godot-test`).
- On Linux the default user folder is `~/.local/share/godot/app_userdata/...` (lowercase): the pinned folder name keeps saves in place on macOS and Windows only.
- A profile saved before this milestone gets the starter rune on its next win and meets the tutorial (skippable); beta, no migration.
- The repository was renamed `rune-ascent` afterwards (so was the local folder, and the Pages address is now `https://gha-kzr.github.io/rune-ascent/`); the save folder keeps the old name.

## Open / deferred
- The exact list of achievements is settled while implementing (data files, easy to extend).
