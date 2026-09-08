# One More Mile

Tovin waits beside the road in Village Outskirts. Talking to him accepts a
small promise; speaking again offers an explicit start. Walk him to the fire,
keep close, and protect him through two clearly announced groups of pursuers.
His actual six-frame walk settles into a planted stance when he waits.

Tovin moves only while someone is near. Players can ask him to wait, resume,
or fall back. Pursuers fight the party using the normal combat system; enemies
inside his circle and being left alone drain his resolve. He stops for each
encounter, regains some resolve afterward, and retreats safely if overwhelmed.
Stopping, death and leaving the room clean up the active encounter. It is
retryable, with no recurring loot, XP, kill counters or room-purge credit.

Reaching the fire earns **the Road Companion** title. A short recognition
conversation completes the Journal promise and leaves a persistent personal
mark. Tovin settles by the fire on later visits, with new dialogue about
leaving a kettle ready for the next traveler. His quest retires from discovery
once permanently finished. The Journal finds his live position during the walk.

The host owns travel, orders, warnings, enemies, resolve and arrival. Guests
request actions with player/room/reach validation and interpolate the host's
position. Late joins receive the current encounter; guests cannot submit its
completion flag. Network version **0.3.9**. Solo menus pause; co-op keeps the
shared encounter running and gates local input through the existing overlays.

## Art and visual corrections

The existing traveler portrait supplied identity for a new built-in ImageGen
walking sheet. Two attempts with repeated leading feet were rejected. A
targeted revision added clear passing poses. The six complete figures retain
one scale and a stable feet line; the original NPC portrait is unchanged.
Masters, prompts and reproduction instructions are in
`art_src/wayfarer_2026-09-08/`. The installed strip is `wayfarer_walk.png`.

Live review also caught oversized crops in the outskirts: the old native-pixel
scale made a painted carrot 516 pixels tall. Seven garden-detail families now
have authored world sizes, with their roots anchored to the ground. A renderer
regression checks the largest jittered instance stays below an adult's height.
Fences now span 150 pixels with a matching shallow rectangular collider,
instead of a 960-pixel fence and a small circular blocker.
Freed quest-giver markers are safely retired when room scenery disappears.
Tovin's prompts relocate when the fixed HUD would cover them near room edges.

## Validation

`test_wayfarer.gd` checks actual crop render sizes, physical quest-giver
discovery, completed-quest retirement, snapshot bounds and arrival prerequisites.
`shot.bat wayfarer --timeout=240` runs the real conversation/buttons, complete
escort, wait/follow/distance, pause, failure/retry, stop/death, physical clear
road, real enemy deaths, quest guidance, recognition, title and touch display.
It also runs two real ENet peers for requests, interpolation, join state and
completion/reach rejection. Final gate results live in `AUTONOMOUS_STATUS.md`.
