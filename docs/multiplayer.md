# Multiplayer (PvP) — how it works

A fight between human players, up to 4 against 4, one hero each, from a static web page. Everything the page needs
to work without a server is in `scripts/net/` (rules, session, network) and `scripts/game/net/` (screens).

## The idea: everyone replays the same log

The battle rules are deterministic (a seeded random generator, no clock), so players do not send each other game
states, only *what was decided*:

- The match is a **log of entries**: a player joined, a hero was picked, the host chose the map, the match started,
  a hero was placed, a hero moved or cast, a turn ended, the AI took over a hero...
- One peer, the **host**, numbers each entry, checks it (is it your hero, is it your turn, is it legal) and sends it
  to everyone. Every peer applies the entries in order with the same rules, so everyone holds the same battle.
- Each entry that changes the battle carries a **fingerprint** of the state after it; a peer whose state differs stops
  with a clear "desync" message instead of playing on a wrong board.
- The screen of each player keeps its own copy of the battle and animates what the log brings; a click only becomes a
  *proposal* to the host, and nothing changes on screen until the host's entry comes back.

Code: `MatchState` (the replicated state and every entry kind), `MatchSession` (numbering, checking, host swap,
timers, AI, reconnect), `ActionCodec` and `StateHash`, `NetBattleController` (the fight screen).

## Host swap

The host is the lowest seat id still reachable. When it disappears, each peer computes the new host the same way; the
new host asks the others how far their logs go, completes its own from whoever has most (an entry the old host sent to
only some of them is not lost), brings the others up to date, and carries on numbering. Proposals that were in flight
are sent again to the new host (each carries a nonce, so none is applied twice).

## A player who leaves: the AI, and coming back

After the grace time (host setting, 20 s by default) the host puts an entry in the log that gives the player's hero to
the AI; from then on the host plays that hero's turns (the AI's moves are entries too, so every peer sees the same).
The players panel tags "(AI)" and "(away)". A player can also hand their own hero to the AI, or ask for it back.

A player who comes back opens the room again with the same browser: a token kept in the browser (and sent sealed) gets
their seat back. They replay the log, then the host returns the hero at a moment that is not its turn. A player whose
tab was only paused (the host stopped hearing it) is asked by the host to say hello again as soon as it speaks, and gets
the seat back the same way; the game also keeps its loop running while its tab is hidden, so a host looking at another
tab still answers joiners. A player who is the last one connected is told so ("Nobody else is connected").

## Connecting without a server

WebRTC data channels connect players directly; the only thing missing is a way to pass the first messages (an *offer*
and an *answer*) between two browsers. Two ways, the same links behind them:

1. **Room code (automatic).** The host's room is a code of 12 characters. A joiner puts a WebRTC offer, **sealed with a
   key made from the code**, into that room on public WebTorrent trackers (`tracker.openwebtorrent.com`,
   `tracker.webtorrent.dev`, both at once); the host is in the same room, answers it the same way, and the link opens.
   The trackers carry a few kilobytes and never see anything readable.
2. **Invite link (manual, always works).** The host makes an invite (a link or code), sends it by any means, the
   joiner opens it and gets a reply to send back; the host pastes it. No third party at all.

After the first link to a newcomer, the rest of the **mesh** builds itself: the newcomer asks each player its first
contact knows for a link, the setup messages passing through that contact. Two players that cannot link directly still
talk through a player both can reach.

### What the public trackers can and cannot see

- The room is named on the tracker by a hash of the code; the code itself never leaves the players.
- Offers and answers (with the addresses in them) are sealed with AES-256-CBC and an HMAC-SHA256 (keys from
  PBKDF2-HMAC-SHA256 of the code); a message that was altered, or sealed with another code, is dropped. Anyone who does
  not know the code can neither read the setup messages nor produce valid ones.
- The code is about 59 bits: share it like a password. Anyone who has it can join the lobby (the host can see who is in).
- WebRTC itself is encrypted (DTLS), and players see each other's IP addresses (inherent to WebRTC).
- Public STUN servers (Google, Cloudflare) help two players behind home routers find each other. There is no relay (TURN):
  a few strict networks will not connect directly; the mesh then relays through a player that reaches both, and the
  invite link is the fallback.
- Reliability: two trackers are used at once, a tracker that drops is retried with a growing pause (no hammering), and the
  trackers are only needed to *connect* (and to let someone back in): a fight in progress does not depend on them.
  They are community services with no guarantee; if both are down, use invite links.

## Security: what is and is not protected

**Your computer and your data.** The game runs inside the browser's sandbox. Nothing a player sends is ever run as code:
messages are JSON read with strict type checks (anything malformed is dropped, never a crash), no engine object or
resource is loaded from the network, names are length-limited and shown as plain text, and the page reads or writes no
file outside the browser's own storage (saves, a name, a rejoin token). Opening an invite or room link only opens this
same page. That makes the game a low risk for a laptop, but "100 % safe" is not a promise anyone can make: the browser, the
engine and WebRTC themselves can have flaws, and a lookalike site could imitate a link, so open links only when they start
with the game's own address.

**What other people learn.** WebRTC shows each player's IP address to the others, and the STUN servers and the trackers
see the IP address of anyone who connects (and nothing readable: see above). The trackers also see the hashed room name,
random peer ids and message sizes. Players see names and hero choices.

**What a player (or the host) can do to the others.** The match is only as trustworthy as the people in it:
- The **host** is the authority: it numbers and checks the entries, but it could also write entries that favour it, and
  the other players would apply them as long as the rules allow them. Play with people you would trust as host.
- A player cannot act for another player's hero (the host refuses it), cannot push entries to the others (only the
  host's entries, or entries I asked for while catching up, are taken), cannot refuse or evict anyone (a "refused"
  message counts only from the host a joiner contacted, and an "elected" message only if the receiver would have chosen
  that player too, with the old host gone), and cannot read or use another player's rejoin token (the shared log keeps
  only a hash of it). What a player proposes is rebuilt by the host field by field for its kind (a peer's hash, padding
  or flags never reach the log), with a limit on the rate of proposals per player.
- A message on a **direct** link speaks only for the player at the other end. A message **relayed** by a third player
  does not have that protection when the receiver has no direct link to the claimed sender: a relay can then lie about
  who a message came from (there are no signatures). The worst it can do to a state-changing message is make the
  victim stop with a "desync" message (the host's entries carry a fingerprint); it cannot make them play a different
  game unnoticed, but it can spam them with fake emotes. Players who cannot link directly are the ones exposed.
- The host's **Remove** bans the player's token for that match only: someone who removed browser storage or uses another
  browser gets a new token and can come back with the room code. It is a courtesy tool, not access control.
- Anyone who has the room code can also answer a joiner's offer on the trackers (an answer is sealed with the room
  key, which every holder has): a holder who races the host can connect a joiner to a fake lobby. Share the code only
  with people you would let into the room.
- Any player can disrupt: send a lot of messages, leave at a bad moment, hand their hero to the AI. Anyone who knows
  the room code can join the lobby (an invite link carries the code too, so share links like passwords).
- The room code is about 59 bits and its tracker name comes out of the same slow key derivation as the encryption keys
  (PBKDF2, 3000 rounds), so guessing it is out of reach, but a code posted publicly is of course public.

## Fairness and rules

- Heroes: the roster's three heroes at level 30 with the default five-spell loadout, no runes; their level is never shown.
- Maps: the same shapes as the tower's (open field, mountain, crater, islands, canyon, ruins), made *symmetric under a
  half turn* with a 3 x 3 start zone for each side (`PvpMap`), so neither side is favoured; the map is drawn again on every
  peer from three numbers (shape, size, seed), and the lobby previews it with the QA map preview.
- Turns: initiative order over all heroes; a turn timer (host setting, 30 s by default) ends an idle player's turn.
- Sudden death from round 40 (every hero loses 10 % of max HP at its turn start) so a stalled fight always ends.

## Hosting

The game is a static web export (`tools/export_web.sh`); `tools/export_web.sh --publish` commits it to the local
`gh-pages` branch, `git push origin gh-pages` publishes it, and Settings → Pages → `gh-pages` / root serves it. Saves
and settings live in the browser, separate from the original game's.

## Tests

- `tests/test_pvp_basics.gd`, `test_match_session.gd` (lobby, start, placement, turns, timer, host swap with a partly
  delivered log, AI takeover, rejoin, desync), `test_net_battle.gd`, `test_net_screens.gd`: the logic on a fake network.
- `test_mesh_transport.gd`, `test_room_signaling.gd`, `test_room_join.gd`, `test_room_crypto.gd`, `test_invite_codec.gd`:
  the connection layers with fake links and fake trackers.
- `tools/e2e/`: real Chrome tabs and real WebRTC (and, for `tracker.mjs`, the real public trackers). See its README.

## Known limits

- Up to 8 players (4 per side); no spectators; no chat (quick emotes only).
- Placement has no timer: a connected player who never presses Ready blocks the start of the fight (the host can hand
  their hero to the AI only once the fight has started).
- A match needs a human host in a visible tab (browsers slow down background tabs); if the host leaves, another player takes over.
- Without TURN some networks cannot connect (use another player as host, or an invite from someone who can reach both).
- If every human leaves, the match is over: the log only lives in the players' browsers.
