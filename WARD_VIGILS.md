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
