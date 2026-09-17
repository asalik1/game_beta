# A Light on the Road

The Collapsed Tower now offers a deliberate, optional defense encounter.
After clearing the residents, approach its brazier and choose to stand watch.
Three authored waves answer the flame. Mara, a lamplighter in Emberfall,
offers the quest, but finding and restoring the ward before meeting her works too.

- Stay within the 280-unit amber ring. An unattended ward loses 5 integrity/s.
- Creatures within the 125-unit heart drain 3 integrity/s each, capped at three.
- The ward starts with 100 integrity and mends 15 between waves.
- Four-second arrival warnings show the next spawn points. Waves contain
  two skeletons, two wolves and a skeleton, then a cultist and two skeletons,
  all level 7 with ordinary party scaling.
- Snuff the brazier to stop. Failure, a deserted room or a wipe cleans the
  wave actors and allows a fresh attempt. Solo pause freezes the encounter;
  online menus leave the shared world running.
- Victory unlocks **the Lamplighter**, restores the light across chapter
  rebuilds/replays, and leads to a three-beat recognition scene with Mara.
  The encounter pays no gold, XP, materials or gear. The quest's reward is
  its kept promise; the title is earned at the defense itself.

The world ring uses different sizes and inward marks as well as color.
A fixed HUD card keeps wave, integrity and instructions visible while the
camera follows a target. The invitation has 48/44-pixel action buttons.
The Journal and map route to the ward only after its room has been charted.

## Ownership and persistence

The host owns waves, integrity, transitions and `ward_tower_lit`. Guests send
only start/stop intent; the host checks peer admission, chapter, live character,
room and reach. Reliable state updates run at 5 Hz while active; the join
refresh carries the current wave, integrity and arrival points. Guest mirrors
cannot spawn waves or decide victory. Protocol version is **0.3.8**.

`sq_kept_ward_tower` remembers the restored light per character;
`sq_kept_tower_light` remembers Mara's completed promise. No active timer or
wave actor is saved. An interrupted save resumes with a retryable brazier.
Mara's completed story stays out of available-quest discovery on chapter replay;
her final conversation remains available as recognition.

## Related reward fix

Loose quest quarry were described as paying no rewards, but their death handler
still rolled chest/material drops and decremented the normal room counter.
Those spawns now advance their quest without rolling loot, granting elite
credit, advancing the chapter purge or closing a guest's cleared-room exits.
The host spawn description carries the quarry marker to guest mirrors.
Other zero-XP/zero-gold mood spawns also skip the ordinary loot roll.

## Reward feedback

Achievements now share the discovery/quest announcement queue. They no longer
stack over the message explaining what was just accomplished, and incidental
overflow preserves earned notices first. The event feed hides and pauses its
reading clock under menus/dialogue; long lines stay within its left-hand column.
Zero and negative XP awards are ignored before replay-cap logic, eliminating
`+0 XP` noise and false "outgrown this road" notices from event creatures.

`test_reward_feedback.gd` exercises queue sharing/deduplication, overflow,
overlay clocks, fixed-width text, and nonpositive XP. The live Mara capture
also asserts that queued rewards and the event feed cannot cover her dialogue.

### Boss readout follow-up

Shared large announcements now wait while the boss readout is visible. A card
already on screen hides and pauses its reading clock, then resumes when the
readout clears. Queued cards retain their order. The immediate compact event
log, stored messages, achievement/reward delivery and existing menu, dialogue,
arrival-title and cast-readout gates are unchanged.

The controlled baseline has 67 checks: 62 passes, five expected observations
and zero unexpected failures, with all six originals reviewed by root and
independently. Three findings expose the missing boss gate; two measure overlap
of larger Control rectangles. Both authored quest captions fit one line, and
the actual level/HP glyphs remain readable above the card. The change reduces
competing large card presentation; the baseline does not reproduce covered
glyphs, wrapped long-tracker copy or an ordinary earned boss achievement.

```powershell
shot.bat hud_dossier --reward-plaques --timeout=180
```

Use fresh isolated APPDATA and the frozen checkpoint runner. The original HUD
baseline adds `--baseline`; strict after omits it. The after contract has 61
rows and six images: hiding cards in captures 02 and 06 removes their six
conditional panel/title/detail rows. Explicit visibility, paused/resumed
clocks, queue/log retention, cast/title controls, natural completion and
restoration remain strict. There is no padding or baseline waiver after.

Default `hud_dossier` is a separate 558-row/22-image Team/readout regression;
`--alignment` selects another fixture. Mobile reward uses `--mobile
--renderer=gl_compatibility` with desktop controls, while mobile default also
uses `--touch`. The reward fixture poses a paused world with production HUD
builders and real UI clocks; it awards no achievement. Default dossier checks
use synthetic HUD states, real GUI actions and loopback host synthetic allies.
Neither establishes ordinary combat, remote reward delivery or physical-device
behavior. Stored message equality is checked separately.

Desktop and mobile each passed all 61 reward and 558 default dossier checks, with zero findings/failures.
Root and independent reviewers inspected all 56 after originals.
All 32 stages passed: compile 263, quick 144/full 224/mobile quick 144 and all seven strict preflight categories.
Closing checks retained 1,259 source pins, 410/411 UIDs, the original 32 preserved files and current authorized 14 journey files.
The [observed baseline](build/qa/session-sept10/reward-plaque-baseline-candidate/runs/842fbdab6b433c6e3bcb3d65a39f2f24fc65508f/baseline-1/observed-contract.json) and [independent baseline](build/qa/session-sept10/reward-plaque-independent-review/baseline1.json) retain 67 checks/62 passes/five expected observations.
The [root after review](build/qa/session-sept10/reward-plaque-after-candidate/runs/842fbdab6b433c6e3bcb3d65a39f2f24fc65508f/after-1/root-review.json) and [independent after review](build/qa/session-sept10/reward-plaque-independent-review/after1.json) bind the tested source and image hashes.

### Plaque entrance readability

THE BLIGHT BREAKS now remains inside its fitted plaque during entrance. Titles
use settled letter spacing when wider entrance spacing would overflow the
available text width. Short titles with room retain their tracking animation.
The settled plaque dimensions, intentional wrapping, detail text, sweep,
scale/fade, hold/exit, queue and existing overlay gates retain their rules.

The current focused mode extends the original six boss/cast/title/queue
controls with entrance and settled captures for authored blight, short VICTORY,
and disclosed synthetic wrapped title/detail stress copy: twelve originals.
Its baseline permits only `reward/07_blight/entrance_text_contained`.
Other titles and every settled frame remain strict. Every sampled draw checks
actual shaped Label character bounds and line counts, independently of the
production font-width calculation. Early captures must occur between 0.18 and
0.55 actual tween seconds; late captures fail rather than stand in for entrance
evidence. The new samples do not freeze, seek or replace the production tween.
The original six captures retain their established disclosed photography policy.

Validated desktop quick 147/full 227 and mobile quick 147; focused native checks 74/74, default dossier 560/560 (desktop/host mobile), all strict. Twelve baseline originals reproduce exactly one blight entrance finding; all 68 final originals were actually reviewed with no remaining blocker. Source sync, compile gates and strict preflight passed.

These are paused-world production HUD fixtures, not an earned achievement or
combat victory. Mobile focused reward uses host Compatibility without touch;
mobile default includes touch. No physical-device or ordinary remote reward
delivery is established. Default dossier synthetic-party/empty-loopback limits
remain. Shaped character bounds do not replace inspection of rendered ink.
The original Warrior expedition's gold/save audit stopped after a combat clear;
it is retained as partial evidence with no return-home or reload claim.
The separate green purge-flash observation is unchanged.

The original September 10 boss-gate counts above remain historical. The earlier
new QA proposal incorrectly described Reaper's Tally as a wrapped stress case;
its source is preserved, and the accepted stress fixture uses explicit
synthetic multiline copy. Codex authored and independently reviewed the
bounded production/helper changes; no generated art or progression change is
included. A separate pre-runtime review caught a corrupted separator in the full QA-v2
helper; QA-v3 removes that codepoint without changing any assertion. The
applied production patch preserves fourteen pre-existing mixed line endings;
a refused pre-runtime hash check and the explicit pin correction are retained.
Exact sources, receipts, original-image review hashes, project-specific
unchanged UIDs, preserved files and serialized commit are recorded in
`build/qa/session-sept17/plaque-entrance-checkpoint-validation.json`.

## Verification

`test_ward_vigil.gd` checks invalid snapshots, caller validation, content
registration, and real ward/quarry death handlers with reward-stream and
room-counter assertions. `test_vigil_network.gd` uses two real ENet peers in one
engine to exercise production requests, state, late-join refresh, completion
forgery rejection, guest authority and reach.

`shot.bat ward_vigil --timeout=240` exercises the live opt-in button, arrival
warnings, all waves, failure/retry, snuffing, pause, death reset, quest routing,
title, touch presentation, object-first Mara recognition and persistent rebuild.
It captures 13 states, including the fixed HUD and dialogue.

Validation logs live under `build/qa/vigil-*`; desktop/mobile status is recorded
in the ongoing work checkpoint after the full suites finish.
