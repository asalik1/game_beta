# Autonomous work checkpoint — RESUMED

**New session authorized September 8, 2026 at 14:40 UTC.** Continue in this
existing worktree until September 9 at 09:00 America/New_York (13:00 UTC),
reserving the final hour for validation and documentation. Preserve all work
and leave the previous task and its paused
automation alone. This task has a separate active heartbeat,
`continue-crownless-wayfinder-through-september-9`, ending at that deadline.

**Latest user instruction: commit the work so far on this branch.** The
validated caravan and HUD passes are included in the checkpoint titled
`Add caravan defense and improve HUD visibility`, following `99668d4`.
Use `git log -1` for its exact ID. All 27 completed passes are now covered by
these two requested commits. Earlier staged/uncommitted notes are historical.
Further development remains stage-only unless the user requests another commit.
The next ward-activity work has only an audit; no implementation is included.

**September 8, 19:31 UTC: the user requested "whatever is staged commit".**
Committed all 25 validated passes (703 files) as `99668d4`,
`Improve Crownless exploration, combat, companions, and co-op`.
The commit tree exactly matches the pre-commit index
(`a2c40f6a6d19b3e3bfb7c3b84159fb883f8ee0b9`). That commit emptied the index;
the working checkpoint and unfinished caravan prototype were preserved outside
that commit. Pass26 is now validated and staged, uncommitted. Earlier
"staged/uncommitted" statements below describe historical
checkpoints. Further work remains stage-only unless the user requests a commit.

Passes22–25 are included in commit99668d4: Party Appearance, Road Choices,
The Crooked Trail and Encounter Company. Their feature notes remain the
validation reference: PARTY_APPEARANCE.md, ROAD_CHOICES.md, ROAD_HUNT.md and
ENCOUNTER_COMPANY.md. Pet movement/previews are already complete. Chromas
remain scrapped; no chroma content, replication or hero-skin art edits.

**September8,20:52UTC: pass26 A Wheel in the Mud is validated and staged, uncommitted.**
See CARAVAN.md. Two warned attacks and twelve Interact pulls free a loaded
cart; nearby attackers damage its load and block work. Victory requires all
actual enemy deaths and gives the shared chapter/run road a20% stock discount.
Host authority, late join, live quotes, travel and home-save ownership are
preserved. Protocol0.3.15. The original generated cart was inspected in-game
on desktop and mobile, including normal combat and touch interaction.

Validation: desktop import / compile208 / quick119 / full199; mobile import /
compile208 / strict quick119. Eleven desktop plus eleven mobile purchase
captures; eight plus eight real ENet caravan captures; nine plus nine shared
encounter captures; twelve existing escort and thirteen ward captures pass.
Final normal starting-kit combat: mobile warrior36.3s,minimum119/130HP,
load78%; desktop mage30.6s,no damage,load84%. Earlier normal warrior/mage runs
also passed. All use real keyboard combat without injected damage. Preflight
0fail/1existing warning and Codex data pass;27source mirrors and8independent
UID pairs verified. Established renderer shutdown diagnostics and the full
suite's existing malformed-code fixture/bare ObjectDB warning remain in logs.
No new script errors and no physical mobile-device claim.

The final source freeze and77explicit staged paths are recorded under
build/qa/caravan-source-freeze.json and caravan-stage-paths.json. Detailed
capture paths and combat metrics: build/qa/caravan-visual-validation.json.
Final logs: caravan-final2-desktop-{quick,full}.log, caravan-mobile-{import,
compile,quick,verdict}.log, caravan-final-preflight.log and the named live logs.
Failed earlier logs remain for traceability. Actual play fixed a freed trader
sprite reference, NPC interception of the cart handle, paused-dialogue HUD
leakage and objective overlap with ability notices/buffs. The final objective
slot isy446; the art width is240px. Original cart master/prompt/provenance:
art_src/caravan_2026-09-08. The installed PNG is unchanged from its master.

**September 8, 22:38 UTC: pass 27 HUD clearance is validated and staged,
uncommitted.** Read HUD_CLEARANCE.md. The upper-left secondary information
fades when it covers the local hero or visible target; vitals, party health
and controls remain clear. Readable menus/settings restore the information.
Objective y428, notice y534 and buffs y578 now occupy separate slots.

Desktop import/compile210/quick119/full199 and mobile import/compile210/strict
quick119 pass. Twelve plus twelve HUD captures and nine plus nine real-ENet
company captures pass. Starting-kit archer41.1s and paladin35.8s combat both
win, seven captures each. Their respective minimum HP was22/100 and61/125;
minimum cart load64% and51%. The images were inspected. Full preflight0fail/
1existing warning; ten frozen source mirrors and three independent UID pairs
verified. HUD_CLEARANCE.md records logs, limitations and unchanged screenshot
copies. No art changes or physical-mobile-device claim. Existing allowed
shutdown diagnostics remain. The29explicit path list and source hashes live
under build/qa/hud-clearance-{stage-paths,source-freeze}.json. The pass26 index
was preserved and extended; no further commit was made.

Next: finish normal-combat coverage with assassin and warlock (existing
shot_caravan keyboard fixture). Reproduce the ward activity defects documented
in build/qa/ward-activity-audit.md: guests receive no contract credit; old board
callbacks can pay after a day refresh; ready contracts lack a persistent HUD
indicator; displayed gold is unscaled. Keep the hero's own board/save and ward
choice. No production edits for this follow-up yet. Q8's old onboarding heading
is stale; talent/gear beats and Auto-equip already exist.

Continue through September9,09:00America/New_York (13:00UTC), reserving the
final hour for a stable checkpoint. The older task and its paused automation
improve-crownless-until-september-9 remain untouched. This resumed task has
its own heartbeat named at the top of this file.

Branch: codex/crownless-wayfinder.
Worktree: C:/Users/asali/Projects/MMO/.codex/worktrees/crownless-wayfinder.
Launcher: run_game.bat in that worktree. Preserve all accumulated work and
stay here. The original Claude worktree remains untouched. Read CLAUDE.md;
one Godot engine at a time, muted windowed QA, game/ source with scoped mobile
sync, compile → quick → full before explicit staging. No unasked commits.

## Accumulated work

Twenty-five validated passes are committed in `99668d4`: Wayfinder,
combat/equipment care, ground warnings, combat framing, fishing, controller
support, boss interrupts, reactive terrain, connected exploration/sanctuary,
ward vigils, refracting-crystal/companion-motion, One More Mile, Pocket Trials, Recovered Spoils, Painted Terrains, Loot Travel, Rescue History, Target Visibility, Personal History, Companion Previews, Co-op Closers, Party Appearance, Road Choices, The Crooked Trail, and Encounter Company.
Feature notes live in WAYFINDER.md, AUTONOMY.md, QUALITY_PASS.md,
COMBAT_FRAMING.md, FISHING.md, CONTROLLER.md, BOSS_INTERRUPTS.md,
REACTIVE_TERRAIN.md, SMALL_MERCIES.md, WARD_VIGILS.md,
REFRACTING_CRYSTALS.md, COMPANION_MOTION.md, ONE_MORE_MILE.md, POCKET_TRIALS.md, RECOVERED_SPOILS.md, PAINTED_TERRAINS.md, LOOT_TRAVEL.md, RESCUE_HISTORY.md, TARGET_VISIBILITY.md, PERSONAL_HISTORY.md, COOP_CLOSERS.md, PARTY_APPEARANCE.md, ROAD_CHOICES.md, ROAD_HUNT.md and ENCOUNTER_COMPANY.md.

## Previous checkpoint: September 08, 14:32 UTC

MP-24 Co-op Closers is validated and staged. Each reader sees their own
class's chapter art, after rewards/records are safely banked. Real ENet QA
caught a same-frame first-clear regression (deferred reward versus immediate
completion); victory now joins the ordered reward queue before recording and
autosaving. Menu/choice/chat waits, pending and active NPC claim cancellation,
final fades, duplicate messages/records, party travel and home preservation
pass. Per-page generation guards prevent stale narration over a new opener.
Party markers and unfinished boss entrance splashes no longer cover the art.
Readers cannot be injured or bleed out behind their ending; the live test
disables god mode and sends a real owner-side damage RPC to prove protection.

Desktop compile190/quick114/full194;
mobile import/compile190/quick114. Ten plus ten
two-reader screenshots, five plus five solo boss captures and seven original
ENet history/reconnect captures pass. 19 frozen source mirrors, three
independent UID pairs, source preflight0fail/12known warnings, Codex data pass.
Network build0.3.12; no art regeneration, hardware claims or commits.

The existing multiplayer suite's stage-8 guest now reads its own ending
before checking its results card. That exact guest reader setup is exercised
inside the one-engine live rig; the multi-process runner was not launched.

The strict screenshot-runner verdict and eleven fixture tests are also
staged: runtime/script errors fail even after a rig prints DONE exit0.
The original pet motion report is fixed in both the world and menus.

Archived audit (superseded by Party Appearance): build/qa/next-road-and-companion-audit.md
recorded the following gaps at the previous pause. Remote
companions currently do not exist: net_session's character block carries no
equipped_pet, and game.gd only draws the local follower. Q16 explicitly wants
friends to see equipped companions. Reuse the six animated PetVisual assets,
replicate validated cosmetic identity, keep remote ownership/home saves local,
and verify live equip, join/rejoin, teleports and disconnect. Also investigate
skin identity, absent from the current join block, within the same
cosmetic-only scope; do not touch off-limits skin art. Richer Road Deck
encounters remain another strong follow-up after this parity gap.

The owner confirmed on 2026-09-08 that the chroma system is scrapped. It is
excluded from all follow-up work; existing code and older proposals are legacy
remnants. This ruling is recorded in CLAUDE.md and DESIGN.md. The obsolete
appearance code drafts were removed; the revised plan covers pets and skins.

The appearance gap described above was the previous session's audit and is
now fixed, validated and staged as pass 22. Road Choices is pass 23; see
ROAD_CHOICES.md for its complete validation and gameplay fixes. The next
encounter is The Crooked Trail (build/qa/road-hunt-plan.md).

## Current follow-up — ward activities and class combat audit

Passes 26 and 27 are included in the user-requested checkpoint. The current source
matches its documented freeze; no engine remains from the HUD gate pipeline.
Read the near-top checkpoint and build/qa/ward-activity-audit.md before the
next change. Continue autonomously with one muted engine at a time.
