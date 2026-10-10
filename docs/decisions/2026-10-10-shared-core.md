# Solo and multiplayer in one game: the shared core

Decisions taken when the multiplayer fork was merged into this repository (the fork is frozen; this repository is the
one that continues).

## Decided

- **One game, two buttons.** The title has **Solo** (the hub, as before) and **Multiplayer** (the PvP front page), side
  by side so the menu still fits under the title picture. Both are always shown; the multiplayer flow handles an
  unreachable server itself.
- **Solo and multiplayer stay separate code paths for now.** Solo keeps its own heroes (levels, runes, loadout) and
  multiplayer its nine fixed-stat classes. Merging the classes is milestone 15 (needs a re-balance).
- **Card combat is multiplayer only** for now (a lobby toggle).
- **Co-op PvE later** is built on the multiplayer stack (the AI-takeover mechanism already plays a seat's hero), solo
  stays offline; solo is not migrated onto the match log.
- **Saves:** no migration (beta).

## The shared core

- `BattleController` is what every fight screen shares (views, HUD, camera, input, playback). Subclasses fill hooks:
  `_create_battle_state` (where the battle comes from), `_next_turn` (who acts next; the multiplayer controller replaces
  `_begin_next` altogether because the log decides), `_perform` (how an action is sent), `_allows` / `_action_done`
  (the tutorial's gate), `_event_seen`, `_refresh_extras`, `_connect_extras`, `_battle_started`, `_battle_speed`.
- `SoloBattleController`: the encounter, the AI turns, the tutorial, the one-time tips, the QA tools (cheats, Auto).
  `battle.tscn` uses it; `net_battle.tscn` inherits the scene and swaps the script for `NetBattleController`.
- `TopBar` (owned by the Game root): sound, settings (in a fight and in the multiplayer lobby) and, in a fight, a
  hamburger menu that asks to leave; gone once the result shows. The settings open as an overlay
  (`Game._open_settings_overlay`, `SettingsScreen.in_match`); a solo fight is paused behind them, a multiplayer match
  cannot be.

## Left for later (considered, not done)

- A common "start a battle" helper for `Game.start_battle` and `NetFlow._show_battle`: they share only five signal
  connections; the rest differs (tutorial, hints, music, the match). Not worth a layer.
- Sharing `NetUi`'s cards with the hub and run screens, and moving the solo screens out of `Game` into a flow like
  `NetFlow` (symmetry between the two modes).

Done afterwards, through the same hook: solo's `_spells_unit_id()` returns nobody during an enemy's turn, so the spell bar is empty.
