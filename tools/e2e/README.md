# Browser end-to-end tests

The headless tests (`tests/`) cover the match rules and the screens with a fake network; the real WebSocket in the
browser build only exists in a browser, so these scripts drive real Chrome tabs against a relay server (`server/`) that
`run.sh` starts on this machine.

- `cdp.mjs`: a tiny Chrome DevTools driver (isolated browser contexts = separate storage, like separate players).
- `basic.mjs`: two players meet by room code.
- `roomlink.mjs`: a guest opens the room link (`#room=`) and joins by itself (`WAIT=<seconds>` keeps the host idle first).
- `hidden_host.mjs`: the host's tab is behind another tab when a guest joins (browsers slow down hidden tabs; the game keeps its loop running with a timer).
- `full.mjs`: three players, a started match, turns, a player whose connection to the server breaks and comes back to
  the same seat, the host's tab closing (host swap), the AI taking over, the host coming back by room link and getting the hero back.
- `screens.mjs`: screenshots of the lobby and the fight in `build/e2e-shots/` (to look at what the screens draw).
- The game exposes a small dev-only hook when the page address has `?e2e=1` (`scripts/net/e2e_hook.gd`); `&relay=ws://127.0.0.1:8787`
  points the game at the relay on this machine (only addresses on this machine are accepted).

Run with `tools/e2e/run.sh` (it exports the web build, serves it on 127.0.0.1:8061, starts the relay on 8787 and plays `full`), or
`tools/e2e/run.sh basic` / `roomlink` / `hidden_host`.
