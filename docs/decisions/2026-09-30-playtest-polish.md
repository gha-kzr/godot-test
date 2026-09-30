# Playtest polish (milestone 5d) — decisions

Four playtest items from the roadmap's "Future features". Builds on [`2026-09-30-ui-revamp.md`](2026-09-30-ui-revamp.md) (input and platforms: desktop mouse and keyboard now, touch and gamepad kept possible).

| Decision | Choice | Why | Revisit when |
|---|---|---|---|
| Scope | (a) focus a unit from the full turn order, (b) camera pan and recentre, (c) XP gain on the floor-cleared screen, (d) drop a rune. A currency, selling and fusing runes stay in the backlog (`Managing accumulating runes`, minus the drop) | Small, from play | — |
| Camera follow | **Recentre automatically on the acting unit at the start of every turn**, ally and enemy, with a smooth slide (the camera's tween); panning and chip or row clicks stay until the next turn. A **Recentre** key (`C`, rebindable in the settings) and HUD button go back to the acting unit at any time | Enemy actions stay visible; nothing is lost when you look elsewhere | playtests find the slide intrusive |
| Panning | **Arrow keys** (held), and **left-button drag** (also middle-button): dragging grabs the board. A press that moves less than ~10 px is a click and acts on release (move, cast, place, pin); beyond it, it is a pan and triggers nothing. Pan follows the screen, not the board, so it stays right after rotating | Left drag is what touch screens do, so Android stays possible; the threshold keeps board clicks working | touch is built (two-finger pan, pinch zoom) |
| Pan limits | The focus point stays inside the board plus a one-cell margin: the board can't leave the screen | No lost camera | — |
| Focus from the order | A row of the full-order overlay (Tab) closes it and moves the camera to that unit, like a timeline chip | Units beyond the next 5 are reachable | — |
| XP on the floor-cleared screen | Under each hero's gold bar: "XP 30 / 50 (+12)", and a **two-tone bar**: XP from before the fight in full gold, extended by a **lighter gold** segment for what was gained. On a level-up the bar shows full and the text reads "Level up!". No animation | Makes the gold bar readable; the animation belongs with the art and audio pass | milestone 6 |
| Drop a rune | A **Drop** button on each stash row turns that row into "Drop *rune*?" with **Yes** / **No** buttons (inline, no popup). A dropped rune is **gone for good**: no undo, no refund | Fixes the pile-up with no economy; a currency is undecided | a currency exists |

## Open / deferred
- Currency, selling, fusing or salvaging runes, a stash cap — backlog (`docs/roadmap.md`).
- Two-finger pan and pinch zoom on touch — when touch is built.
- Level-up animation — milestone 6.
