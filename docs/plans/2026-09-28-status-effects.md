# Status effects and unit inspection (milestone 1) — implementation plan

Decisions: [`docs/decisions/2026-09-28-status-effects.md`](../decisions/2026-09-28-status-effects.md). Roadmap: [`docs/roadmap.md`](../roadmap.md), milestone 1.
Architecture: **modifier stack, read on demand** (approach A) — statuses carry tick effects and stat modifiers; units never overwrite base values, rules query `max_ap()` / `max_mp()` / `damage_taken_percent()`.

## Design summary

### Data (`scripts/data/`, `.tres` content)
- `StatModifier` — `stat: Stat { AP, MP, DAMAGE_TAKEN_PERCENT }` (milestone 2 adds more), `amount: int`.
- `StatusData` — `display_name`, `short_label` (icon text), `color`, `is_positive`, `duration` (≥ 1, in the affected unit's turns), `tick_effects: Array[EffectData]`, `modifiers: Array[StatModifier]`; `describe()`, validation.
- `ApplyStatusEffect extends EffectData` — `status: StatusData`.
- `EffectData.target_filter: TargetFilter { ALL, ALLIES, ENEMIES, CASTER }` (default ALL). CASTER effects apply once to the caster, in or out of the area.

### State and rules (`scripts/battle/`)
- `StatusInstance` — `data`, `turns_left`, `caster_id`; `clone()`.
- `UnitState.statuses`; `add_status(data, caster_id)` (refresh + replace; returns the AP / MP shift to apply now), `stat_bonus(stat)`, `max_ap()`, `max_mp()`, `damage_taken_percent()` (100 + bonuses, ≥ 0); `start_turn()` refills from the maxima; `clone()` copies statuses.
- `DamageEffect` scales its roll by `damage_taken_percent()` (rounded, capped at HP). Heals unaffected.
- Spell resolution: targets fixed first, then **effect by effect**, each effect on the targets its filter keeps; dead targets skipped.
- Events: `StatusApplied(unit_id, status, turns_left)`, `StatusTicked(unit_id, status)`, `StatusExpired(unit_id, status)`; `Event.subject_id()` (the unit an event is about, or −1).
- `Battle`: shared death check (UnitDied, turn order removal, BattleEnded); turn end = statuses count down, expired ones removed (`StatusExpired`), then `TurnEnded`; turn start = loop { advance → `TurnStarted` → ticks (`StatusTicked` + effect events; effects act as if cast by the status's caster, even a dead one) → death check → next unit if it died, else refill }.

### AI
- Status value = expected total effect over the remaining duration (tick damage × damage-taken % × turns capped at HP; tick heal × turns capped at missing HP; AP / MP amount × turns × `ap_value` / `mp_value`; damage-taken % × turns × `incoming_damage_per_turn`), signed by who benefits, **minus the value of what it replaces**, times `status_weight`. New `AIProfile` weights.

### Display
- `EventPlayer`: one dispatch point via `subject_id()`; status applied (floating label, icons update), ticked (icon pulse; tick numbers come from the following damage / heal events), expired (icon fades).
- `UnitView`: status icon row (`Label3D` tags like `P2` on a camera-facing row node) above the HP label; re-synced from state after playback.
- `Hud`: status list in the unit panel (swatch, name, turns, tooltip); modified AP / MP tinted; **hover panel** for any other unit (HP, AP / MP, statuses, spells); `UnitInfo` gains status and spell entries; spell tooltips describe statuses and filters. Controller refreshes the HUD after each playback (a per-event refresh was tried and dropped: the state is already final while events play) and drives the hover panel.

## Tasks

Each task ends with: `--check-only` on edited scripts, headless tests green (plus mutation checks on new tests), and a commit of explicit paths. If unsure of a Godot 4.7 API, check the official docs first.

### Rules

- [x] **Task 1: Status data model** — `StatModifier`, `StatusData`, `ApplyStatusEffect` (`apply` can return no events until Task 2 wires state), `EffectData.target_filter`; `describe()` for statuses, status effects and filters ("allies only").
  Pattern: data-only `Resource` classes with typed `@export`s and `get_validation_errors()` (as in the slice); strategy pattern for effects.
  Tests: validation (duration ≥ 1, empty effect / modifier slots, a status with neither ticks nor modifiers), describe texts, content validation picks up statuses.

- [x] **Task 2: Statuses on units** — `StatusInstance`; `UnitState.statuses`, `add_status`, `stat_bonus`, `max_ap` / `max_mp` / `damage_taken_percent`, refill from maxima, `clone()`; `ApplyStatusEffect.apply` (refresh / replace, immediate AP / MP shift by the difference, `StatusApplied`); `DamageEffect` uses damage taken.
  Pattern: modifier stack read on demand (no stored derived values); plain-data `RefCounted` state with deep `clone()`.
  Tests: apply / refresh / replace; recasting Haste doesn't shift AP twice; modifiers never push points or percent below 0; ±25 % cancel out; DoT-style damage scaled; clones copy statuses and are independent.

- [x] **Task 3: Effect-by-effect resolution with target filters** — `CastSpell.apply` resolves effect by effect over pre-fixed targets; ALL / ALLIES / ENEMIES / CASTER.
  Pattern: command pattern unchanged; filter as data on the effect (no per-spell code).
  Tests: allies-only heal skips enemies in the area; enemies-only damage skips allies; caster-only applies once, even outside the area; a target killed by effect 1 is skipped by effect 2; update existing event-order expectations.

- [x] **Task 4: Turn flow — ticks, expiry, deaths at turn start** — `Event.subject_id()`; `StatusTicked`, `StatusExpired`; shared death check extracted from `perform()`; turn-end countdown; turn-start loop used by `start()` and `perform()`.
  Pattern: single mutation entry point (`Battle.perform`) producing an ordered event list; loop until a living unit's turn starts or the battle ends.
  Done: a status only counts down on turns that *started* with it on (`StatusInstance.counting`), so a self-buff cast during its carrier's own turn doesn't lose that turn — keeps "N turns = N of its turn starts" exact. Events got a `UnitEvent` base with `unit_id` / `subject_id()`.
  Tests: DoT damages at the affected unit's turn start; "N turns" = N ticks, visible through the last affected turn, expires at its turn end; a DoT kill skips to the next unit (no TurnEnded for it); the battle ends on a DoT kill (incl. the last unit of a team); several units dying to DoT in a row; a status keeps ticking after its caster dies; AP / MP modifiers apply on refill during the duration only; seeded ticks are deterministic.

### AI and content

- [x] **Task 5: AI status scoring** — status valuation (expected value, signed, gain over the replaced instance, `status_weight`); `AIProfile` weights `status_weight`, `ap_value`, `mp_value`, `incoming_damage_per_turn`.
  Pattern: greedy utility AI unchanged; utility term added to the scorer, weights as data.
  Tests: a pure DoT spell is cast; HoT goes to the injured ally, not a full-HP one; no re-poisoning a freshly poisoned unit; slows an enemy, never an ally; a mixed spell outscores its damage-only version; AI never mutates the real state (existing test extended to statuses).

- [x] **Task 6: Showcase content** — status `.tres` files (`data/statuses/`) and one status spell per unit (up to 4 spells): Archer **Poison Arrow** (damage + Poison DoT — a mixed spell); Mage **Regeneration** (HoT, allies only); Brute **Crippling Blow** (damage + Crippled: −2 MP, +25 % damage taken); Knight **Guard** (self or ally: −30 % damage taken, +1 MP — covers AP / MP up). Numbers tuned by AI-vs-AI runs.
  Pattern: data-only `.tres` (generated once with `ResourceSaver`, like the slice content); no code changes.
  Tests: content validates; AI-vs-AI slice battles still end; every status spell gets cast at least once over the seeds.
  Done: statuses Poison (3–4 per turn, 3 turns), Regeneration (heals 4–5, 3 turns), Crippled (−2 MP, +25 % damage taken, 2 turns), Guarded (−30 % damage taken, +1 MP, 2 turns). Spells: Poison Arrow (3 AP, range 2–6, sight, 1–2 damage + Poison), Regeneration (3 AP, range 0–4, circle 1, allies only), Crippling Blow (3 AP, melee, 4–6 + Crippled), Guard (2 AP, range 0–2, allies only). The status attacks first cost 4 AP: the greedy AI then cast them and couldn't afford a basic attack, and players won 10/10; at 3 AP they combo with a basic attack and AI-vs-AI is back to 7–3. Choosing the best *combination* of casts per turn belongs to milestone 4's smarter AI.

### Display

- [x] **Task 7: Event playback and status icons** — `EventPlayer` single dispatch via `subject_id()`; `UnitView` status row (tags, camera-facing row node), `play_status_applied` / `play_status_ticked` / `play_status_expired`, icons in `sync()`.
  Pattern: sequential awaited playback (as in the slice); views re-read state after playback.
  Tests: each new event plays and returns; icons appear, update turns left, disappear on expiry; `sync()` rebuilds icons from state; render check at 4 camera turns.

- [x] **Task 8: HUD statuses, hover panel, live refresh** — unit panel status list and tinted AP / MP; hover panel; `UnitInfo` status and spell entries; spell tooltips for statuses and filters; controller: HUD refresh on each played event, hover inspection on the hovered unit.
  Pattern: Control containers; HUD updated by calls down with plain info values, signals up; never reads state.
  Tests: status rows and tooltips; AP / MP tint; hover panel shows for another unit, hides otherwise; HUD values change mid-playback; render check.

### Wrap-up

- [x] **Task 9: Review and playtest** — `godot-code-review` subagent over the milestone; fix findings; README (hover panel, statuses in "Playing", "adding a status" in "Adding content"); decision record kept current; hand playtest.
  Pattern: code review checklist; decision record kept current.
  Done (review fixes): the AI undervalued a status by one turn once its carrier had played (`counting` stayed set; now cleared by the countdown, with a real-flow test); the per-event HUD refresh read the already-final state and jumped ahead of the animations, so the HUD refreshes after each playback again (unit views still show HP live; an event-driven HUD is milestone 5) and the false-positive test was replaced; the hover panel hid as soon as the mouse reached it (hover now sticks over the panel, so its tooltips work); explicit stat descriptions and AI warnings for kinds it can't value; no "+0" / "-0" numbers; tag rows only process while tags exist; `short_label` at most 2 characters. Balance over 20 AI-vs-AI seeds (was 16–4, then 20–0 after the first fixes): Guard is 3 AP, self only, 1 turn; Poison 2 per turn; Poison Arrow hits 2–3; Crippled is −1 AP, −1 MP, +25 % damage taken (an AP modifier in play); Regeneration costs 4 AP; Archer 28 HP, Brute 42 HP → 10–10, every status spell and basic attack cast. The slice test now runs 20 seeds and asserts both sides win sometimes.
  Deferred from the review: per-kind AI value hooks for new tick / stat kinds → milestone 4; an event-driven HUD (events carrying "after" values, a countdown event so tags update mid-playback), and the self-buff turns wording → milestone 5; a symmetric `remove_status` + `StatusRemoved` → dispel; a central `UnitState.take_damage()` → shield; an AI simulation where the actor dies to its own cast runs the next turn's ticks (rare) → milestone 4.
  Remaining: hand playtest.