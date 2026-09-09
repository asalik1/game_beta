# Guardian discovery and completion — pass 31 in progress

The journal, field atlas and corner HUD read campaign boss completion for
optional guardians that reuse the same combat kit. This produces both false
victories before a fight and stale undefeated status after its real victory.
The Progress page also reveals unvisited guardians and merges separate named
encounters into the campaign boss's row.

## Actual baseline

Starting production commit: `a74fdfe`. The shared ShotRig baseline entered
real seeded rooms for the Molten Court in chapter four and Old Greymantle in
chapter three, with the campaign kit mark false and true for each. It used
real pocket portal actions and actual Boss damage/death dispatch, returned
and re-entered, and captured the journal, HUD and field atlas. God mode,
positioning and overkill isolate state/UI behavior; this is not a normal
combat or network reward claim. The pocket source was naturally calm; frozen
trial clocks explicitly refreshed their display after death.

`build/qa/optional-discovery-baseline1.log` records four complete cases,
155 checks and 43 reproduced failures, with 32 Forward+ captures. Actual
spawning, original completion writers, real death, no-respawn behavior and
campaign-mark preservation passed. No script errors occurred. The failure
exit is the intended negative control; familiar renderer shutdown diagnostics
remain. All saves are isolated and disabled for this probe.

## Current implementation scope

Use the encounter's existing completion state consistently in room safety,
the corner HUD and atlas. Record charted guardians under their own names and
completion state; keep unknown guardians hidden. Make the discovered record
useful for map inspection while preserving all actual graph connections,
travel eligibility and story locks. Refresh open views when these states
change. Waking remains solo-only. No reward or save-schema changes in this
pass; the separate Unlisted co-op reward audit remains follow-up work.

The implementation is now present in desktop and mobile. Journal → Progress
records each charted guardian separately, with an explicit name, encounter
family and victory state. Show on map opens that recorded room without
changing the world or setting a route. A detached pocket gets its own map
component; Your position restores the current area. Main trail also restores
that component before selecting a known, unvisited frontier. Open journal and
atlas views refresh independent banks and Waking week changes while retaining
selection, scroll and focus. The Codex explains this behavior.

The new regression checks independent campaign/pocket/Unlisted/Waking marks,
previous-week Waking state, hidden names/counts, stale callbacks, live reader
state, separated map components, existing travel and story locks, and ward
boards remaining stable. Strict mobile quick2 passed 124 checks including
this module after import and compile. Quick1 caught a fixture-only untyped
empty array assigned to the typed route path; that abort skipped restoration
and caused a secondary save assertion. Root corrected it to `Array[int]`;
both logs are retained under `build/qa/guardian-potion-mobile-*`.

The updated ShotRig keeps the four actual seeded baseline cases and adds
ordinary mouse/ScreenTouch journal map actions and departed-pocket inspection.
Desktop passed 209 checks across all four cases with 44 captures. Every image
was reviewed: no unknown-name leakage, merged campaign marks, stale victory
state or incorrect map destination. Evidence is under
`build/qa/optional-discovery-desktop1*` and `optional-discovery-desktop-review.md`.
The mobile-source rig also passed 209 checks and all four cases in 154 seconds,
with 44 native captures reviewed without blocking findings. Actual ScreenTouch
press/release events exercised ten Journal map actions and two Your position
resets: independent names/completion and fog remained correct, the departed
pocket stayed disconnected, and inspection granted no movement, route or
travel. Evidence is under `build/qa/optional-discovery-mobile1*` and
`optional-discovery-mobile-review.md`. This is host Compatibility rendering
with synthetic touch input, not physical Android/iOS device validation.
Final integrated desktop compile224/full205 and mobile compile224/strictquick125
passed; full preflight reported no findings. The source freeze, explicit paths,
logs and checkpoint identity use the `checkpoint31-` prefix under `build/qa/`,
including `checkpoint31-validation.json`.
