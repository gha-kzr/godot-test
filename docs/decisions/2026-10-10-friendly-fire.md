# Friendly fire

Decided 2026-10-10.

## Decision

- **Solo has no friendly fire.** Damage and harmful statuses only hit enemies, even from an area that holds allies or the
  caster. Heals, buffs, pushes and pulls still reach allies; an effect aimed at the caster alone (a self-inflicted cost)
  still hits it; a spell aimed at an ally on purpose (`target_unit` ALLY, the boss Ghoul's Feast) still hurts it.
- **Multiplayer has a lobby rule**, `friendly_fire`, chosen by the host and replicated like the other settings. It is
  **on by default**: that is how PvP always played, and the class numbers were balanced with it.

## How

- `EffectData.is_harmful()`: true for `DamageEffect` and for an `ApplyStatusEffect` whose status is not positive.
- `BattleState.friendly_fire` (default false; copied by `clone()`), read in one place: `CastSpell._targets_of`. The damage
  preview, the AI's simulations and the hover marks all play the cast through the same action, so they follow the rule
  without changes. Status ticks (a poison already on someone) are not casts and are untouched.
- `PvpBattle.create` turns it on (the balance tools keep the old rules); `MatchState` sets it from the lobby rule.

## Not done

- The AI's `friendly_fire_weight` still exists; it only matters where friendly fire is on.
- Spell descriptions do not mention the rule.
