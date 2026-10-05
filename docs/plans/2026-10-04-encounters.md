# Milestone 9a: encounters — plan

Decisions: [`docs/decisions/2026-10-04-encounters.md`](../decisions/2026-10-04-encounters.md). Branch `milestone-9a`; one commit per task; rules tested headless first; `godot-code-review` at the end; French texts through `tools/extract_strings.gd`; renders through the battle camera for the models.

1. **First stage gate**: a stage is available only once the tower's floor 10 has been cleared at least once (`Profile.best_depth`); the hub says why it's locked.
2. **Roles**: `EnemyData.role` (enum Tank, Bruiser, Ranged, Support, Skirmisher) on the shipped enemies; the role reaches `UnitState` (from the build) and the HUD's unit card shows a role tag with a tooltip.
3. **Positioning AI**: `AIProfile.preferred_distance` (min / max distance to the nearest opponent, with a weight) and `ally_cohesion`; `EnemyAI` adds a position score for the cell a plan ends on and may pick a pure repositioning move; one profile per role (`data/ai/role_*.tres`), chosen by the role unless a preset sets one. Kiting tests: a melee hero catches a ranged enemy on an open map within a few turns; AI-vs-AI fights against ranged-heavy teams stay winnable.
4. **New enemies**: models (Quaternius CC0, Poly Pizza, hashed and credited), units, spells (Shield Wall, Shield Bash, Dark Mend, Hex, Pounce, Hook, Smash and a bite), statuses, loot, roles.
5. **Compositions**: `CompositionData` (slots: a role or a fixed enemy, a level offset; boss or not), `FloorBand.compositions` (weighted), the floor generator fills spawns from a composition (elite on elite floors, the boss slot on boss floors), the Ghost cap; about ten compositions; tower bands rewired; the stages use boss compositions.
6. **Docs, translations, review, balance check** (one AI tower run from floor 1, light).
