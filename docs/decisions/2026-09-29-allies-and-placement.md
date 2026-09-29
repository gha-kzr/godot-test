# Walking through allies and choosing starting positions (milestone 4.5) — decisions

Milestone 4.5 of [`docs/roadmap.md`](../roadmap.md) (its "Future features"). Reopens the slice's blocking rule ([`2026-09-27-tactical-rpg-slice.md`](2026-09-27-tactical-rpg-slice.md): "every living unit blocks its cell, allies included") and builds on the run loop's generated maps and deterministic floors ([`2026-09-29-run-loop.md`](2026-09-29-run-loop.md)).

| Decision | Choice | Why | Revisit when |
|---|---|---|---|
| Walking through allies | Units walk **through allied units**, both teams; enemies still block. A move can't end on an occupied cell | Removes the frustration of your own heroes walling each other; one rule for both teams, the AI swarms better too | — |
| Cost | No extra cost: a step through an ally costs its normal terrain cost; statuses don't change it | Simplest rule; no new frustration | a "rooted" or "heavy" status wants to block |
| Line of sight | Unchanged: every unit, allies included, still blocks line of sight | Movement-only change; body-blocking for the archers stays tactical (Dofus) | — |
| Placement model | **Dofus-style start zone, pre-filled**: before the first turn, heroes stand on a default placement; the player may rearrange them in the zone, then **Ready** | Dofus's tactical choice at the cost of one click when the default is fine; Disgaea deployment would change battle flow, AI and balance | playtests |
| Zone shape | A **3 × 3 square**: a start point and the 8 cells around it (9 cells for 3 heroes) | Narrow, readable, still a real choice (front / back, left / right, high ground) | maps want other shapes |
| Zone generation | The map generator picks the start point from the floor's seed (same for everyone): all 9 cells walkable, connected to the enemies, and at least 5 MP of walking from every enemy spawn (a buffer before melee contact; ranged enemies may still shoot on their first turn, as in Dofus) | Deterministic floors; fair starts | — |
| Zone layouts | Seeded layouts per floor, with weights in the tower data: mostly **facing edges**, sometimes **corner vs corner**, rarely an **ambush** (party in the centre, enemies on 2–3 sides; not before the first floors, e.g. from floor 6) | Variety across an endless tower, cheaply | playtests |
| Enemies | Fixed spawns from the encounter, **visible during placement** | Floors stay identical for everyone; seeing the enemy is what makes placement tactical | — |
| Default placement | **By role**: melee heroes (short spell ranges) on the zone cells closest to the enemies (walking distance), ranged heroes on the farthest; the same rule places the lab's and AI-played parties | Good enough on any layout, ambushes included ("front" = toward the enemies, not the screen bottom) | — |
| Hand-made maps | The existing `p` tokens: more `p` cells than heroes form the zone (any shape) | No format change for hand-made maps | — |

## Open / deferred
- A "remember my last placement" option — not wanted for now (maps differ every floor).
- Enemy placement zones — no (floors stay deterministic).
