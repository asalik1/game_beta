# Crown Plaza arrival visibility

Crownfall arrivals now place the hero on the south approach to the fountain.
The old authored origin `(1056,596)` sat behind its tall artwork. Normal travel
was physically escapable, but the hero was almost entirely hidden while idle.
Map return, Recall and respawn used geometric center `(1056,624)`; Recall and
respawn also overlapped the fountain body in the native baseline.

The authored player origin is now `(1056,832)`. `Game.room_arrival_pos` selects
that point only for capital room zero; all other rooms keep their geometric
center. Explicit map, Recall, respawn, network snapshot and remote re-home
consumers use the helper. It performs no physics query during chapter rebuilds.
The existing temporary remote offset remains `(40*(peer_id%5),30)`.

`room_center` remains geometric. Existing valid saved coordinates still load
as saved, including an old capital position; this change is not a save migration.
Encounter placement, loot positions, protocol and save format are unchanged.
`tools/content/gen_capital.py` also carries the 31 current prose fields that
had drifted into generated content, including Kesh's Alchemy dialogue. With
that synchronization, regeneration changes only the authored arrival point.

The hero's node origin is not its painted feet. The normal render anchor is
22 pixels below the origin. A source-only idle bounds check includes existing
class sizes, frame-zero normalization, directional idles and breathing. The
sampled painted bounds leave at least 46.880 pixels above the conservative vault
canvas for the main origin, or 16.880 for existing temporary remote offsets.
Transparent frame padding and floor shadows are reported separately. This is
placement analysis, not an artwork change or proof for every action/effect.

## Native evidence and limits

Run `shot.bat capital_arrival --arrival-consumers --timeout=180` with APPDATA
inside an isolated `capital-arrival-native-candidate` directory. The normal
solo fixture waits for the real opening cinematic to finish, then uses one
Escape event, the Pause Travel button and the normal capital welcome. It
observes actual body physics, camera smoothing, one second idle and one second
left movement followed by release. The optional consumer leg opens the map
through its public method and clicks real destinations; Recall and respawn
are direct production landing calls. It does not claim scroll consumption,
lethal combat, death tithe or the respawn delay.

The expanded desktop baseline records 53 checks: 42 pass, 11 expected placement,
visibility or fountain-only collision findings, zero unexpected failures.
All six baseline frames were reviewed. The first rejected boot fixture and
its incomplete report remain separate; the readiness correction observes the
cinematic completion and does not force gameplay state.

The desktop after run passes 61/61, including eight other-ward center controls.
All 15 samples are free of fountain covering and body collisions. Root and an
independent reviewer inspected all six full frames. The hero is visible on
paving above the vault. Rapid return captures retain the normal settling camera
and fading prior zone title; those effects are also present in the baseline.

`shot.bat brewing_persistence --capital-arrivals --timeout=300` adds snapshot
and reconnect placement checks to the existing real-file/ENet fixture. The
desktop run passes all seven persistence milestones and both new arrival rows;
all four full frames were reviewed and isolated save bytes restored. The
local body's physics is disabled in this controlled pair, and the posed host
and guest share one landing position. It proves production placement and
structure visibility, not peer separation or transient shell convergence.

The synchronized mobile project also passes 61/61 native arrival checks and
all seven paired milestones plus both arrival rows. All ten full mobile frames
were reviewed. These are Windows Compatibility renders, not physical-device
tests. Desktop and mobile quick suites pass 127 checks; explicit mobile import
and compile pass. The desktop full suite passes 207 checks and all seven preflight categories
pass. Exact
source/log/image hashes and the independent reviews are retained under
`build/qa/session-sept10/capital-arrival-*`; the explicit source and commit
receipt is `capital-checkpoint-validation.json`. Known renderer shutdown diagnostics
remain in those logs; no new diagnostic whitelist was added.
