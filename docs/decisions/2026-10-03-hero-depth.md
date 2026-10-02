# Hero depth (milestone 8) — decisions

Settled with the owner in three grill rounds. "Sound and animation leftovers" left this milestone (the owner can't test sound for now) and stays in the backlog.

| Decision | Choice | Why | Revisit when |
|---|---|---|---|
| Scope | The 5-spell loadout, three new spells per hero (what the raised level cap still waited for), movement spells, free repositioning (instead of undo), spell cooldowns, three new enemies replacing the Archer | Deepens the tactics before content scales up | — |
| Movement kinds | **Teleport, jump, charge, push, pull**, plus **Backslash** (damage, then a leap back). Swap places waits for a role that needs it | Push and pull share one rule; charge is a move then a hit | a role needs swapping |
| Teleport | Any free walkable cell in range; no path, no line of sight, any height | — | — |
| Jump | A free walkable cell in range; passes over units, obstacles and holes; climbs at most **2** levels (walking: 1), any drop | Clears what a walk can't | — |
| Charge | Toward a unit in a **straight line** (same row or column) with every cell between free and walkable by the step rules; the caster stops next to it, then the spell's damage lands | Dofus / Disgaea charge | — |
| Push / pull | The target slides N cells straight away from / toward the caster (dominant axis), step by step with the walking rules (climb 1, drop 2); it **stops at the first blocked cell** (obstacle, unit, edge, hole, a too-high climb). **No collision damage**, nobody falls into holes | Owner: no collision damage; ring-outs would be frustrating against the AI | pushes feel weak |
| Backslash | Damage to an adjacent enemy, then the caster jumps straight back (away from the target) up to 3 cells, stopping at the last cell it can land on (free, walkable, climb ≤ 2) | Owner's hit-and-run for the Ranger | — |
| Cooldowns | `SpellData.cooldown` (turns, 0 = none; 1 = once per turn): after a cast the spell waits that many of the caster's turns; the spell bar shows the turns left; the AI respects it | A 2-AP teleport could otherwise be cast three times a turn | — |
| New hero spells | Three per hero, at **levels 5, 9 and 14** (7 known, 5 active). Knight: **Charge**, **Shield Bash** (damage + push 2), **Smite** (Holy). Mage: **Blink** (teleport), **Repulse** (pushes every adjacent unit away), **Frost Lance** (a line, Frost, −MP). Ranger: **Backslash**, **Grapple Shot** (damage + pull), **Hunter's Mark** (+damage taken for 2 turns) | Each hero gets one or two movement spells and one answer to the Ghost | playtests |
| New damage types | **Holy** (Smite) and **Frost** (Frost Lance, the Ghost's Chill Touch) | A physical-only party must still hurt the Ghost | — |
| Loadout | **5 slots** per hero, chosen on the party screen (hub, and between floors through Party; never in a fight). Click a slot, then a known spell: an active spell swaps slots, an inactive one replaces the slot's spell. **No removing**: a hero always has min(5, known) active spells; while it knows fewer than 5, the remaining slots are empty (and stay at the end). A newly learned spell takes the first empty slot. The battle spell bar follows the slot order (key *n* = slot *n*). Saved per hero | Owner: the spell he wants in the slot he wants, no removal | a reorder by drag is wanted |
| Repositioning (instead of undo) | Until it casts, the acting unit may move **as often as it likes inside the zone its MP reached at the start of the segment**; the cost always counts from the segment's start cell (moving back refunds). **A cast commits** the position: the new zone is what the remaining MP reaches from there, and free repositioning starts again. Movement spells are casts. Same rule for every unit | Owner's alternative to undo: cheaper and more forgiving | — |
| AI and repositioning | The AI **decides once per segment**: it never moves twice before a cast (no rethinking), but can still move after a cast with its MP left, as today | Owner; also guarantees the AI's turn ends | — |
| AI and movement spells | **Enemies get no movement spells.** The AI doesn't value positions; a spell that also moves (Charge, Backslash, Shield Bash, Grapple Shot) is scored on its damage only (the balance lab's hero AI never casts Blink) | Owner: no movement spells for enemies | enemy roles (milestone 9) |
| Resistance cap | **75 % for heroes, 100 % for enemies** (was 50 % for all); 100 % is immunity | Owner; immunity without a special rule | — |
| New enemies | **Archer retired** (deleted). **Skeleton Archer** (ranged, fragile, physical; Bone Arrow, Pinning Shot: damage + Crippled, Bone Rain: small area). **Ghoul** (2 MP, tough; Rend: damage + Crippled, Devour: a heavy hit that heals it). **Ghost** (low HP, **100 % physical resistance**; Chill Touch: Frost, Wail: −1 AP for a turn on heroes around it). Brute unchanged. No poison anywhere on enemies | Owner: fed up with the enemy archer and poison | milestone 9 roles |
| Ghost limits (assumed) | At most **one Ghost per floor**, never a boss | A physical-heavy party never faces a wall of immune enemies | playtests |
| Models | Quaternius, CC0, from poly.pizza: [Skeleton](https://poly.pizza/m/yq5ATpujSt), [Zombie](https://poly.pizza/m/VlXjG0N8Eg) (Ghoul), [Ghost](https://poly.pizza/m/Iip30bDHmu). The animation lookup also matches any `\|` segment (the Skeleton's names are mangled) and learns `Sword`, `Attack`, `HitReact`, `Flying_Idle`, `Fast_Flying` | Same cartoon style as the heroes; owner approved | — |
| Sounds | None added: new spells use their damage type's cast sound, else the generic `cast` | The owner can't test sound now | the sound leftovers |

## Saves
Beta: no backward compatibility. A save without loadouts gets the default one (the first known spells in learning order).

## Open / deferred
- Swap places, a pure Jump spell on a hero, hole ring-outs: not in this milestone (the Jump rule exists for Backslash's landing and tests).
- AI valuing positions (fleeing, high ground, using Blink): with the enemy roles of milestone 9.
- A hint when a hero learns a spell that doesn't fit the loadout: later, if players miss it.
