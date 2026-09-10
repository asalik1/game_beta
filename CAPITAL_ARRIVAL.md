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

## Fountain prompt and the location tracker

The selected fountain prompt now stays clear of Crown Plaza's location tracker.
Each marked landmark retains its authored anchor and station X. Immediately
before drawing, only the selected prompt moves down when its complete bounds
intersect the visible tracker, leaving a 4px screen gap. It returns to the
authored anchor when clear. The accepted arrival origin y=832, fountain art,
hotspot reach, nearest selection, prompt visibility, hero physics and camera
behavior are unchanged.

The accepted before2 baseline has 64 observations: 63 passes, one tracker
intersection finding and zero failures, with all four originals reviewed.
Real S/S/W movement sampled hero y=832, y=840.5, y=866 and back to y=832. At
y=866 the hero remained 58px from the 70px hotspot, so the obscured prompt was
still legitimately selected. The earlier before1 remains rejected: render
polling released a movement hold too late, producing S/W/W; its 50 rows
(47 passes, three failures) and three images are diagnostic only. The corrected
QA releases held keys from completed physics steps without posing body/camera.

Use the existing isolated rig as two separate runs:

```powershell
shot.bat capital_arrival --fountain-prompt --fountain-after --timeout=180
shot.bat capital_arrival --arrival-consumers --timeout=180
```

The original-HUD baseline uses `--fountain-prompt --baseline`; do not combine
that flag with the after-only observer. The after extension retains all 64
checks and adds four settled anchor checks plus one aggregate of observations
after completed draws. Both desktop and host Compatibility mobile runs passed
all 69 fountain rows with four originals each. The separate arrival-consumer
regression passed all 61 rows with six originals on each project. Root and the
independent reviewer viewed all 20 after originals.

Desktop recorded 149 draw samples: 31 adjusted, 118 clear, zero invalid. Mobile
recorded 91: 24 adjusted, 67 clear, zero invalid. Each S/S/W leg included both a
rendered body-position transition and separate released-body camera easing.
The checks bind the same authored anchor, unchanged station X, minimal downward
adjustment, complete prompt bounds and observer disconnection. They do not
claim continuously held motion throughout every sample.

All 16 stages passed: desktop/mobile compile 262, desktop quick 144/full 224,
mobile import and quick 144, both native routes and all seven strict preflight
categories. Closing source checks preserved 1,254 source pins, 409/410 UIDs,
235 material controls and both preservation inventories. The preserved evidence
lives under
`build/qa/session-sept10/capital-arrival-native-candidate/fountain-before2/`
and `fountain-after1/`; the rejected first lane remains `fountain-before1/`.
The accepted root review is `fountain-after1/root-review.json`; the accepted
independent review is `build/qa/session-sept10/fountain-prompt-independent-review/after1.json`.
These tests used pre-commit source based on `91287e90b7cd0c69c0156e8c20c6babe14bd75f3`;
the separate post-commit receipt is `fountain-prompt-checkpoint-validation.json`.

The fountain episode covers normal solo travel, real keyboard movement and
the visible prompt. The separate default map/Recall/respawn legs retain their
existing controlled consumer setup; they are not evidence of ordinary death
or scroll use. Mobile means the host Compatibility renderer with desktop
keyboard input. There is no physical-device, controller, ENet, interaction-reward,
ordinary-combat, alternate-landmark, boss-HUD or long-quest claim. The original
32 preserved files and current authorized 14 journey files remain separate
preservation inventories. Settled frames and recorded movement/camera easing
do not cover every rapid title or teleport transition.

## NPC prompt draw order

Shared NPC interaction pills now paint above base character bodies and carried
weapons. The earlier Fountain after1 `02_keyboard_escape.png` originals show
real A movement leaving the mage just south of Clerk Voss: the hero covers the
beginning of the pill and its interaction key. The label previously shared its
parent's world Y-sort position. This was a pre-existing rendering issue in both
projects, despite the arrival checks passing.

The two-line correction introduces `Balance.INTERACT_PROMPT_Z = 2` and assigns
it to the Label created by `_make_npc`. Base bodies remain at z0 and the carried
weapon at z1. This shared factory also supplies prop hotspots. The change
preserves authored anchors, landmark lift, the Fountain tracker adjustment,
nearest eligible selection, reach, actions, visibility gates, actor sorting,
physics, camera and artwork. It does not guarantee priority over higher world
effects or HUD CanvasLayers.

The unchanged arrival-consumer route passed all 61 checks and six images per
project; the separate Fountain route passed all 69 checks and four images per
project, with zero findings or failures. Root and the independent reviewer
inspected all 20 full originals. Direct before/after `02_keyboard_escape.png`
comparison shows the complete E prefix, left pill and Voss text painting
readably over the mage. The desktop stop matches the historical (796.75,832);
the mobile stop is (792.5,832), versus historical (796.75,832), from ordinary
frame-timed A input without forced coordinates. This is a visual comparison
at those observed positions. The 61 numeric rows do not prove text paint order,
and no new assertion merely checks the assigned z value.

The Fountain regression retained strict clearance and anchor behavior across
129 desktop draw samples (32 adjusted, 97 authored-clear) and 92 mobile samples
(24 adjusted, 68 authored-clear). Every sample passed; the unchanged observer
also checked rendered body movement and released-body camera easing. These are
this checkpoint's samples, separate from the earlier Fountain totals above.

The serial pipeline completed all 32 stages with zero exit codes: explicit
compile 263, desktop quick 144/full 224, mobile quick 144, four exact GD sync
controls and seven clean preflight categories. Source-before, post-import and
source-after are byte-identical, binding 1,262 source pins and the unchanged
410 desktop/411 mobile UID census. The original 32/current authorized 14
preserved files remain exact. No QA or UID was added; the two unchanged QA
files are sync controls alongside the two production paths.

Both projects ran on the Windows host with actual keyboard/mouse input; the
mobile project used the Compatibility renderer. This does not establish
physical-device, touch, controller, ENet, every NPC/effect or ordinary-combat
behavior. Map returns use actual map clicks; Recall and respawn remain direct
landing calls, not consumable-use, combat-death or delayed-respawn tests. The
existing rapid-map transient-title qualification remains unchanged.

Evidence is under
`build/qa/session-sept10/npc-prompt-after-candidate/capital-arrival-native-candidate/runs/42598087534a09651fb518783c07d97cd52cd16e/after-1/`,
against Reward commit `42598087534a09651fb518783c07d97cd52cd16e`.
Final acceptance is recorded in that lane's `root-review.json`
(SHA256 `37dc3b275033821d47ff6bcfc23864e5f6ddbd3b1f0edb26f065c0a0739d092d`) and
`build/qa/session-sept10/npc-prompt-independent-review/after1.json`
(SHA256 `0a23b916eb7e473c2d3261f68236eaef9056bc89edaf1e192989d1b67481d529`).
