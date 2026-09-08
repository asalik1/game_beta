# The Crooked Trail — pass 24

Validated September 8, 2026. Adds a fourth Road Deck encounter: accept a
hunter's offer, follow three painted paw trails, read each sign with the normal
interaction, and choose when to flush an elite quarry. A 2.2-second arrival
warning gives the party room to move. No tracking timer or extra failure cost.
The offer shows the quarry's level and the personal gold reward in advance.

Quarry strength follows the nearest authored pack through the actual room
graph, with the normal species floor and NG+ offset. A starting village hunt
therefore produces a level2 elite instead of the prototype's level7 enemy.
Existing wolf, blightwolf and duneprowler art/combat are reused. The objective
sits above the center action bar, clear of party health and touch controls.

The host owns progression, spawn, actual enemy death and participant selection.
Reliable snapshots support guest interaction, current-state late joins and
travel. Guest mirrors retire on disconnect; they never become offline hunt
authorities. Ordered steps, range, incapacity, chapter/seed/world/token and
sender guards reject invalid or stale actions. Inactive signs have no interaction
reach, and warnings use the same obstacle-adjusted point as the actual spawn.

Heroes present at victory, including downed allies but excluding ghosts,
dead or absent heroes, receive their own level-scaled purse. A saved personal
receipt prevents duplicate settlement and is excluded from host world flags.
Late completed snapshots and returning after victory pay nothing. No XP,
ordinary kill loot, purge, kill-quest or loot-RNG credit is generated. Only an
actual defeat consumes the room's road flag/count. Abandonment clears the enemy
and signs without claiming victory.

The retry promise also exposed an older Road Deck bug: offers were considered
only on the first visit. Unresolved offers now reuse the seeded draw on
re-entry, with the consumption and duplicate-actor guards intact. Rooms still
in combat do not offer a decision; they can be revisited after clearing.
The in-game Codex now reads RoadDeck.field_notes() directly, removing its
separate stale copy of encounter prose. Network build: 0.3.14.

The live hunt found and reproduced a pre-existing home-save regression twice:
joining rebuilt the host's world and autosaved its seed before guest routing
was enabled. The snapshot restore now establishes character-only routing and
suppresses writes for the whole world/character transaction. It banks the
completed character after restoration. The live assertion compares the entire
home world at the actual join boundary and after reward settlement. Details:
build/qa/road-hunt-join-save-regression.md. No real user save was touched.

## Validation

- Desktop compile197, quick117 and full197 pass on the final frozen source.
- Mobile import/compile197 and strict quick117 pass. Mobile import retains the
  existing missing Android build-tools notice; no device build is claimed.
- Eight desktop Forward+ and eight mobile Compatibility captures pass the
  two-game, single-engine ENet rig: real offer/steps, late world snapshot,
  guest flush and damage, once-only personal payment/home save, absence,
  return-after-victory, abandonment, re-entry, travel and disconnect.
- Final visuals inspected: painted tracks, explicit offer/level, arrival
  warning, quarry and reward states. The rig checks every touch-action
  rectangle against the objective. Its kill uses QA damage; ordinary class-kit
  combat assessment is a follow-up, not a claimed manual fight.
- Existing personal-history live regression: seven captures pass. Existing
  loot-travel regression: six captures pass, including production host loss,
  home preservation, portable overflow and mailbox claims.
- Preflight: zero failures, twelve established source warnings; engine-backed
  Codex data gate passes. The full suite retains the known malformed Fangmoot
  code diagnostic and bare ObjectDB shutdown warning, with no script or
  resource-leak failures.
- Sixteen frozen source mirrors and four independent UID pairs verified.
  Forty-seven explicit checkpoint paths: build/qa/road-hunt-stage-paths.json.

The new track decal was generated with the built-in image tool. Original
1254px RGBA copied unchanged to game/assets/sprites/road_hunt_track.png and
rendered at 28px with mipmaps. Source and prompt: art_src/road_hunt_2026-09-08/.
verify_art reports zero failures and one expected soft-alpha warning. It was
inspected in-game in both renderer paths. No hero skin art or chromas changed.

Evidence: build/qa/road-hunt-*.log, road-hunt-source-freeze.json and
road-hunt-uids.json. Final capture logs: road-hunt-balanced-live.log (desktop)
and road-hunt-mobile-live.log (mobile). All windowed QA was muted and used
isolated APPDATA; save fixtures restore their files on failure as well as success.

Next audit: build/qa/encounter-readability-audit.md — older escort/ward HUD
placement, shared discovery feedback, optional-encounter overlap and normal
combat playtesting. Accumulated changes remain uncommitted.
