# Status effects and unit inspection (milestone 1) — decisions

Milestone 1 of [`docs/roadmap.md`](../roadmap.md). Builds on the slice decisions in [`2026-09-27-tactical-rpg-slice.md`](2026-09-27-tactical-rpg-slice.md) (single-player, 3D, GDScript, content as `.tres`, rules separate from display) and the status design notes in the slice plan ("After the slice", item 1).

| Decision | Choice | Why | Revisit when |
|---|---|---|---|
| Scope | A system later features build on (new status kinds, dispel, design tools, loot affixes) | The roadmap depends on it | — |
| Catalogue (this milestone) | Damage over time, heal over time, AP / MP up or down, damage taken up or down (%) | Covers harm, healing, tempo and defense without the stats model (milestone 2) | more statuses are wanted |
| Extensibility | A status is a resource holding **tick effects** (reusing `EffectData`: damage, heal, …) and **modifiers** (AP, MP, damage taken, …); new kinds are new subclasses, battle code unchanged. Shield, stun, damage dealt are expected later | Designed to grow; the skill designer and loot will reuse it | — |
| Category | Every status is **positive or negative** | A later dispel can target "enemy buffs" / "ally debuffs" | dispel is designed |
| Mixed spells | A spell can both deal damage and apply statuses (its effect list mixes both) | Wanted by design (e.g. Fireball + Burn, Poison Arrow) | — |
| Effect targets | Each effect in a spell has a **target filter**: everyone in the area (default, today's behavior), allies only, enemies only, caster only | Area heals / buffs that skip enemies, leech-style spells; cheap now, the skill designer and the AI use it | — |
| Reapplying | Refreshes the duration; the new strength replaces the old (a weaker recast can downgrade a status). Different statuses combine | Easy to read and balance | stacking builds are wanted, or downgrades bother players ("keep the stronger, refresh the duration") |
| Timing | Ticks and AP / MP refill at the **affected unit's turn start**; countdown and expiry at **its turn end**: "N turns" = N ticks and N refills, and the status stays visible through every turn it affects. Several statuses tick in application order | Predictable ("3 turns" = 3 ticks); matches "DoT at the beginning of the unit's turn"; no status silently gone while its effect still applies | — |
| Caster death | A status keeps running for its full duration after its caster dies (positive and negative alike); ticks still act as if cast by that caster | Clearest rule: what's on a unit stays on it | playtests want more counterplay (remove a dead caster's statuses in the death check) |
| AP / MP modifiers | Apply **immediately** to current points when the status lands, and again at each turn-start refill while active | Casting Haste then moving further feels right; self-buffs stay useful (Dofus-like) | — |
| Tick rolls | DoT / HoT roll each tick from their min–max, like direct effects; the AI uses the average | Consistent with direct damage and AI scoring | — |
| Damage taken | Percent modifiers add up (+25 % and −25 % cancel), total clamped at ≥ 0 %, applied to all damage including DoT | Simple, readable | stats (milestone 2) change the damage formula |
| Deaths at turn start | A tick can kill the unit whose turn starts: report the death, check the outcome, move on to the next unit (looping) | Already designed in the slice plan | — |
| AI | Values statuses by their expected total effect over the remaining duration, signed by who benefits, minus the value of the status it replaces, weighted per `AIProfile` (`status_weight`, `ap_value`, `mp_value`, `incoming_damage_per_turn`) | A pure status spell must score above 0 to ever be cast; no pointless re-casts or downgrades | smarter AI (milestone 4) |
| Removal | Statuses only expire this milestone; the model allows removal later | Dispel / cleanse wanted later, not now | dispel is designed |
| Showcase content | Up to 4 spells per unit (was 2–3); each unit gets one status spell, with a HoT and a buff on the player side: Archer **Poison Arrow** (2–3 + Poison 2/turn × 3); Mage **Regeneration** (4 AP, allies-only area, heals 4–5 × 3); Brute **Crippling Blow** (4–6 + Crippled: −1 AP, −1 MP, +25 % damage taken, 2 turns); Knight **Guard** (3 AP, **self only**, −30 % damage taken, +1 MP, 1 turn). Archer 28 HP, Brute 42 HP | Every status kind exercised in real play; tuned to 10–10 over 20 AI-vs-AI seeds (Guard on allies every turn and a cheap Regeneration made players win 20–0) | balancing pass |
| Architecture | Modifier stack read on demand: statuses carry tick effects and stat modifiers; `UnitState` never overwrites base values, rules query `max_ap()` / `max_mp()` / `damage_taken_percent()`. Spells resolve effect by effect over pre-fixed targets | Nothing to undo on expiry, clones stay exact; milestone 2 stats and items reuse `StatModifier` | milestone 2 needs formulas beyond summed modifiers |
| HUD refresh | After each playback; unit views show HP, status tags and floating numbers live | The battle state is already final while events play, so a per-event HUD refresh ran ahead of the animations | event-driven HUD (milestone 5) |
| Status display (first version) | Small colored icons with a turns-left number above each unit's HP label; full list with durations in the unit panel; tick damage / heal shown as floating numbers at turn start | Cheap, consistent with hit numbers; **to be revamped** in the milestone 5 UI and model pass | UI polish (milestone 5) |
| Unit inspection (first version) | Hovering any unit shows a **second panel** (HP, AP / MP, statuses, spells); the active unit's panel stays | Compare with the target while aiming; never lose whose turn it is; **to be revamped** in milestone 5 | UI polish (milestone 5) |

## Open / deferred
- Dispel / cleanse spells — later; the positive / negative category is there for it.
- Shield, stun, damage dealt modifiers — later status kinds on the same model.
- Stacking rules — only refresh-and-replace for now.
- Statuses from sources other than spells (terrain, passives, items) — not in this milestone.
