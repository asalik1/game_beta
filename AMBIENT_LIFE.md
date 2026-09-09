# Ambient life in compact rooms

## Player-facing change

Small village and darkwood rooms have fewer birds and butterflies. In the
seed-17 Village Outskirts baseline, 16 animals moved around the quest giver and
activity label in only 36.5% of a full room's playable area. Several bright
silhouettes repeatedly competed with the people and encounter information.

`Ambience.populate` scales the three flock populations by playable-area
fraction when that fraction is below 0.65. Each flock keeps at least two
members; the optional second sparrow group also becomes less frequent.
The real Outskirts recipe aims for six to nine animals across the three
groups. This is a population adjustment, with existing art and movement.

Full-sized rooms keep their original counts and seeded homes. Ordinary combat
room sizing bottoms out at 0.85 per axis (0.7225 area), above the compact
threshold. Other biomes retain their existing recipes. Omitted flock members
still consume their original placement rolls, preserving the retained
members' homes and the placement of later groups. Optional groups can disappear
as intended. The local population RNG does not change gameplay loot rolls.

## Implementation

- `game/scripts/ambience.gd`: area-aware flock population, preserving placement
  roll order, social pairs, sprite scales, shadows and landing exclusions.
- `game/scripts/balance.gd`: compact threshold, minimum group size and optional
  second-flock chance.
- `game/shot_ambient_life.gd` and `scripts/tests/ambient_life_live.gd`: isolated
  real-engine census, placement controls and posed native motion views.

This does not change collision, rewards, creature AI, enemy spawns or authored
story. The Codex describes no fauna population rule and needs no content entry.
The existing soaring implementation does not use all assigned shared-flight
fields; this change does not claim synchronized flock flight.

## Validation

Evidence lives in `build/qa/session-sept10/`. The accepted baseline
`ambient-before2` has 704 checks, zero fixture failures and six expected
population findings; all eight native images were reviewed. Its posed camera
explicitly refreshes the real location label and allows the arrival banner and
lighting to settle. An earlier baseline with stale fixture presentation is
retained separately and is not the accepted visual comparison.

Desktop quick/full pass with 126/206 named checks. Scoped mobile sync copied
the five canonical files; mobile import, compile and the strict quick verdict
pass (126 checks). The projects generate their own script UIDs.

Both `ambient-after1` (Forward+) and `ambient-mobile-native` (Compatibility,
touch HUD) pass all 509 checks, with no findings, across 20 population/control
cases. The assertion count depends on the number of spawned animals. All eight
images from each run were reviewed at native size. Seeded Outskirts populations
for 17/41/203 change from 16/16/13 to 6/9/6; corresponding full-room populations
remain 14/13/11 with exact original assignments. The additional controls cover
actual ordinary combat geometry, its declared minimum area, either side of the
compact threshold and the unchanged storm recipe in a quarter-sized room.

The camera/actor poses and darkwood/threshold/storm overrides are explicit QA
fixtures. A four-second sequence at simulation speed 1 verifies actual bird and
butterfly movement, scale, strips and shadows; it does not establish a whole
foraging/flight cycle or identical motion phases between runs. Mobile evidence
uses the mobile project on this development host, not a physical device.

The existing `caravan --combat --class=mage --seed=17` rig also passes before
and after: level 1, starting equipment, normal 90 HP, keyboard movement,
abilities and pulling, with no injected combat damage. Both runs win. The
after run lasts 39.421 seconds, ends at 36.67 HP and reaches 32.04 minimum HP
(load minimum 64.35%); the baseline lasts 33.911 seconds and ends at 72.20 HP.
These are individual automated combat observations, not a difficulty or
performance comparison. All seven after frames and seven baseline frames were
reviewed. Encounter setup is a seeded fixture, not ordinary exploration.

An independent reviewer also inspected all 16 desktop before/after population
images and the report: the quest-giver region is clearer, sprite scale and
shadows are intact, and the 23 compact/75 full non-fauna geometry entries match
exactly. Full preflight passes all seven categories with no findings.
The exact source/commit and evidence hashes are recorded in
`build/qa/session-sept10/ambient-checkpoint-validation.json`. All 32 unrelated
preserved files still match their initial hashes. No art assets changed.
