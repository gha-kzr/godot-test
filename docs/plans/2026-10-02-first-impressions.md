# Milestone 7: first impressions — plan

Decisions: [`docs/decisions/2026-10-02-first-impressions.md`](../decisions/2026-10-02-first-impressions.md). Branch `milestone-7`; one commit per task; tests with mutation checks; renders; `godot-code-review` at the end; new texts through `tr()` with French entries (`tools/extract_strings.gd`). The game is in beta: no save migrations.

1. **Battle speed**: `Settings.battle_speed` and `auto_end_turn` (store, applier, settings rows); `EventPlayer.instant` and a speed that scales waits (Engine time scale during a battle for fast; direct sync for instant); a HUD toggle; auto end turn in the controller when nothing can be done. Pattern: settings resource + applier, no change to the rules.
2. **Web "Click to start"**: a `Screen` shown first when `OS.has_feature("web")`; the click goes to the title.
3. **Tutorial and tooltips**: a `Spotlight` overlay (four dimming rects around a target rect, so clicks inside the hole pass through to the board), `TutorialStep` data (id, text, target resolver, awaited action), a `Tutorial` director fed by the controller's actions (ready, placed, moved, cast, ended turn, equipped), key blocking outside the allowed action, Skip link, persistence in the dismissed hints; the starter rune (config field, profile flag); contextual tips; glossary tooltips.
4. **Best floor and achievements**: `AchievementData` resources, `Achievements` rules on events and profile changes, profile storage, toast, screen, title and hub best floor.
5. **Result poses**: `UnitView` victory animation on the result screen.
6. **Rename and branding**: title, project name, custom user dir, docs, web page; branding slots.
7. **Docs and review.**
