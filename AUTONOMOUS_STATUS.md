# Active session — September 9–10, 2026

The owner explicitly authorized this new session at 17:32 UTC September 9.
Continue improving the game in this worktree through September 10, 13:00 UTC
(09:00 America/New_York). Stop starting features/art at 12:00 UTC; reserve the
last hour for validation, fixes, documentation and committed handoff. This
supersedes historical pause instructions for this session only. Older paused
automations and tasks remain untouched. An active goal carries this task; no
new heartbeat has been created.

Worktree: `C:/Users/asali/Projects/MMO/.codex/worktrees/crownless-wayfinder`.
Branch `codex/crownless-wayfinder`; initial HEAD `a47809b0f238efe5a94620bb1f2ead0a121810b1`.
Index initially empty. All 32 preserved unrelated hashes match the prior
inventory; current receipt: `build/qa/session-sept10/initial-preservation.json`.
Root owns the single Godot engine and serialized explicit-path commits.
The first accepted checkpoint fixes menu return paths, confirmation
cancellation, focused text entry, pending remaps and touch/wheel dismissal.
Desktop and mobile native acceptance each pass 158/158; the existing controller
rig and online-menu regressions (67/67 each project) pass. All 37 accepted
native frames were reviewed. Desktop quick/full (126/206), mobile import /
compile / strict quick (126), scoped sync and full preflight pass. All 32
unrelated file hashes remain unchanged. See MENU_NAVIGATION.md and the exact
commit/source receipt at `build/qa/session-sept10/menu-checkpoint-validation.json`.

The second accepted checkpoint reduces fauna crowding in compact village and
darkwood rooms. Pictured Outskirts seed 17 changes from 16 animals to 6 while
full-room recipes/seeded assignments remain exact. Desktop and mobile native
each pass 509 checks across 20 population/control cases; all 16 after frames were
reviewed, alongside 8 baseline frames. An independent reviewer accepts the
before/after comparison. The existing level 1 normal-health mage caravan rig
wins before and after; all 14 combat frames were reviewed. Desktop quick/full
(126/206), mobile import/compile/strict quick (126), scoped sync and full
preflight pass. All 32 preserved unrelated hashes remain intact. Details and
limitations: AMBIENT_LIFE.md; exact commit/source receipt:
`build/qa/session-sept10/ambient-checkpoint-validation.json`.

The third accepted checkpoint paints three F-grade material UI pilots:
Wilted Sprig, Foul Residue and Rusted Scrap. Desktop and mobile native each pass
90 checks; the baseline records 20 expected presentation findings. Root reviewed
all 18 full native images and an independent agent accepted the desktop
before/after comparison. Source archives and a portable exporter reproduce the
approved PNGs. Desktop compile/quick/full (235/126/206), mobile import/compile/
strict quick (235/126), scoped sync and all preflight categories pass. All 35
legacy material hashes, world pickup sizes and 32 preserved unrelated files
remain intact. See MATERIAL_UI.md and the exact commit/source receipt at
`build/qa/session-sept10/material-checkpoint-validation.json`.

The fourth accepted checkpoint adds Alchemy: 39 clean F–A potion recipes, exact herb/reagent and
fee previews, B/A recipe knowledge and a live Kesh bench. Professions now
rejects retired action callbacks and keeps active-trade captions readable.
Desktop quick/full pass 127/207, with the final full rerun also passing 207.
The mobile source passes explicit import/compile/strict quick 127. Six native
acceptance runs pass on each project: Professions 347, Alchemy 389, actual-file
ENet persistence seven milestones, live ENet UI 24, production network admission
34 and menu returns 158. Root reviewed all 30 final native frames per project;
Alchemy's seven final desktop views also have independent visual acceptance.
The 39-price/27-route economy audit passes; 25,000 boss packs preserve the
existing gear-recipe draw prefix. Network protocol is 0.3.16 for recipe awards.

The paired save fixture restores every isolated file and proves solo/guest
brew/learn, overflow recovery, award fanout, travel and reconnect ownership.
Its home-file boundary is the last own-chapter save before the first host
snapshot, with an exact SHA256 write chain. Empty caller stacks do not identify
the upstream write trigger. The live UI fixture's child-scene disconnect
observation is excluded from strict acceptance; it does not model actual
current-scene replacement. The production admission fixture passes with clean
shutdown after correcting its own observer reference cycle. Mobile native
runs use Windows Compatibility rendering, not physical-device execution.

Ordinary-input brewing samples remain incomplete. A posed level-6/chapter-2
mage cleared Mills and collected its loot, then fell in Howling Fields; it
bypassed normal character progression and is not balance evidence. A fresh
level-1/chapter-1 route uses real earned skill/attribute spending and Auto-equip.
Its first attempt missed a polled Skills hotkey; a QA-only held-key correction
allowed the second run to clear/loot three rooms and complete four upkeep steps.
The mage then fell in Fangmaw's Hollow at 161.522 seconds. All five frames have
root and independent review; this strict failure never reached brewing. The
optional opening chest is omitted and no-save mode suppresses skippable tutorials.
The 14 journey source/scene/UID files remain uncommitted experiments, preserved
in `build/qa/session-sept10/brewing-journey-experiment-preservation.json`.
Final mobile import/compile (245)/strict quick (127) and all seven preflight
categories pass. Alchemy's explicit source/commit receipt is
`build/qa/session-sept10/alchemy-checkpoint-validation.json`; ALCHEMY.md records
behavior, test scope and remaining limitations.

The fifth accepted checkpoint keeps Crown Plaza arrivals visible on the south
approach to the fountain at player origin (1056,832). The narrow explicit-arrival
helper covers map travel, Recall, respawn and network arrivals while geometric
room centers, valid saved positions and protocol remain unchanged. Generator
synchronization preserves all 31 existing prose fields, including Kesh's copy.
The expanded baseline records 53 checks: 42 pass, 11 expected visibility /
placement / fountain-only body findings and zero unexpected failures. Desktop
and mobile after runs each pass 61/61; all 12 full frames and 30 body/visibility
samples are accepted. Independent desktop/source review confirms the corrected
+22px painted-feet model and vault clearance. Earlier y864 proposals remain
uninstalled. Real ENet persistence on each project passes seven milestones and
both snapshot/reconnect placement rows; all eight paired frames were reviewed
and isolated files restored. Its disabled local physics and colocated posed
peers are not peer-separation evidence. Mobile runs are host-rendered Windows
Compatibility checks, not physical devices. Desktop quick/full pass 127/207;
mobile explicit import/compile246/strict quick127 and all preflight categories
pass. The 32 original unrelated files and 14 unfinished journey files remain
unchanged. See CAPITAL_ARRIVAL.md and the exact commit/source receipt at
`build/qa/session-sept10/capital-checkpoint-validation.json`.

The sixth accepted checkpoint respects each interaction entry's reach and keeps
Shield Bash, Shadow Dash and Blink destinations clear of terrain/enemy bodies.
The nearest eligible interaction still wins. Open destinations preserve travel
across intervening scenery; blocked destinations retreat along the approach.
The nominal strike corridor remains intact, while hit direction and landing
follow-ups use the actual arrival. Codex Combat notes explain the behavior.

The strict before4 baseline records 549 checks and 36 expected findings: nine
long-range reads miss and 27 landings overlap scenery before unwanted recovery
movement. Final desktop after5 and mobile after1 each pass 796 checks across
25 interaction, six competition, 35 terrain and seven actor rows. All landings
are clear; every terrain recovery displacement is zero. Three actor pairs
preserve ordered damage amounts, HP debits, mana and cooldown. All ten Codex
reading/cleanup checks pass through actual clicks, wheel input and Escape.
All 33 full frames per project have independent review; root reviewed the seven
actor views, Codex page and four representative input/terrain frames per project.

Real ENet guest Blink checks pass 47/47 on both projects, with two actual-input
casts, one guest-attributed host hit each and converged position/quantized HP.
All eight frames have root and independent review. The fixture manually admits
its readers and uses a stationary enemy; it does not model moving combat,
latency, admission or security. Exploration uses posed/frozen geometry and
12 direct recovery move calls, not an ordinary playthrough or 12 complete Player
ticks. Boss art and frozen trails can overlap the hero despite clear bodies.
Mobile checks render the mobile project on the Windows host, not a device.

Desktop quick/full pass 143/223, mobile import/compile/strict quick pass 143,
final native compile gates pass 254 scripts and all seven preflight categories
pass. Intermediate after2/3/4 and network desktop1 remain rejected evidence:
QA motion reconstruction, body-setup timing, Codex capture and cleanup errors
were corrected before acceptance. Exact scopes and source/artifact hashes:
EXPLORATION_RELIABILITY.md and
`build/qa/session-sept10/exploration-checkpoint-validation.json`.
All 32 original and 14 unfinished journey hashes remain unchanged.

The seventh accepted checkpoint makes Settings-family touch targets 44px
with scrolling bodies and pinned Back /
exit hints. Desktop Settings, Controller and Keybind layouts stay compact;
Comfort now also scrolls on desktop to contain its overflowing hint. The
corrected baseline passes 223 checks with 38 expected findings and 0 failures.
An added desktop Comfort baseline records exactly one hint overflow among 255
checks. Final desktop after3 and mobile after1 each pass 255/255 with all nine
full images per project reviewed by root and independently. The broader
desktop menu regression passes 158/158; root reviewed all eight images.
Desktop serial quick/full pass 143/223; mobile import/compile253/explicit
strict quick143, native compile255 and all seven preflight categories pass.
Native before1 lacks the Windows touch capability flag
and remains rejected; after1 was stopped before images/report because root
mistakenly launched it while quick1 still ran. Final serial gates supersede
that overlap. The fixtures restore live settings, bindings and emulation;
they do not establish physical-device, controller coexistence, disk persistence
or ordinary gameplay results. All 32 original and 14 unfinished journey hashes
remain unchanged. See SETTINGS_TOUCH.md and the exact commit/source receipt
at `build/qa/session-sept10/settings-touch-checkpoint-validation.json`.

The eighth accepted checkpoint fixes the owner's reported Team/Settings
misalignment in
desktop/mobile source. Team's independent x300 anchor was 8px right of the
gear; it now derives x292 from the same utility-column expression. Size44,
y80/y128, gap4 and callbacks stay unchanged. The native baseline records521
checks:512 pass, nine expected alignment observations, zero failures and22 images.
Desktop/mobile native each pass557/557 with zero findings/failures. All22 full
images per project and all22 baseline images have independent review; root
reviewed three before and six per after project. Other utility/label positions
remain exact, all36 text-target clearances pass, and actual mouse/ScreenTouch
Team/Settings access works. Desktop quick/full143/223, mobile import/compile253/
explicit strict quick143, native compile255 and all seven preflight categories
pass. No physical-device or real remote-client claim is made. The pre-existing
mobile Party “tapSC” footer is under separate source review. All32 original,
14 journey and four paused material-QA hashes remain intact. See HUD_ALIGNMENT.md
and `build/qa/session-sept10/party-column-checkpoint-validation.json`.

Material sibling QA is installed but kept separate from that HUD fix. Its
strict before1 baseline passes212 checks:196 pass,16 expected absent-art
presentation findings, zero failures, nine full images reviewed by root and
independently. Four inventory-filter findings extend the original12-count
prediction because missing32px overrides keep inherited filtering. No new
art has been generated. Four QA source/mirror hashes are preserved in
`build/qa/session-sept10/material-followup-interruption-preservation.json`.

Guest quest refresh, save feedback and material sibling artwork candidates
remain separate under `build/qa/session-sept10/`. Source review identified and
proposed a fix for a private Maren objective overwritten by a new host-counter
fanout in the quest candidate; no party-quest code is installed. The ordinary
brewing journey remains incomplete and uncommitted as described above.
Two rejected checkerboard scrap generations are preserved separately in
`build/qa/session-sept10/material-rejected/`. Protected art and chromas stay excluded.

# Crownless — September 9, 2026 checkpoint

**Validated owner follow-up, September 9 at 16:35 UTC:** the requested HUD
alignment, quest overlap and blocky ground-warning fixes are complete. Gold's
fallback coin now has a separate label so the numbers share a baseline with CR
and Resonance. The complete quest tracker wraps beside the vitals and moves
target/cast readouts beneath it. Analytic comet warnings replace the thick
segmented border and scaled fill edge; intact terrain props have a quiet orbit.
See HUD_ALIGNMENT.md for behavior, reproduction and evidence boundaries.

Desktop compile 232/quick 126/full 206, mobile compile 232/strict quick 126,
all 26 screenshot-verdict fixtures and full preflight pass. The shared HUD
regression checks include shaped numeric baselines, containment, complete text,
clearance, deliberate misalignment and exact restoration. Fifty accepted full
native screenshots plus 81 native orbit crops were reviewed, with 810 numbered
native HUD/comet checks and no failures. The existing reactive-terrain rig also
passes real melee/projectile priming, damage/chill, chain-fuse, pause, touch and
production ENet request/state checks. Mobile rendering uses the mobile project
on this host; no physical-device performance claim is made.

The first full run exposed a process-frame timing assumption in Vargoth's
enrage test. A bounded wall-clock observation retains the real damage and cast
path, verifies the living health threshold and records timing. The accepted
full run observed enrage after 1.722 seconds with a real cast initially active.
Earlier failed probes and the rejected faint ring revision remain excluded.
The final 81-frame native GIF preserves the full 5.4-second orbit.

This checkpoint selects 44 explicit paths. Its actual commit identity, source
hashes, gate logs and native receipts live in
build/qa/hud-comet-fix1/checkpoint-validation.json. All 42 frozen source/tool/UID
hashes, 15 source/mobile pairs, four independent UID pairs and the 32 preserved
unrelated scratch/future-QA hashes are checked. The original checkout and
unrelated road-hunt/unlisted/vow/art work remain untouched. No push or merge
was performed. This was a later owner-requested follow-up; the earlier
overnight heartbeat remains PAUSED and its historical checkpoint follows.

**Final validated checkpoint, September 9 at 14:54 UTC:** development is stopped
and this task's `crownless-overnight-improvements` heartbeat is PAUSED. The
continuation resumed at14:43UTC after the13:00UTC deadline with an interrupted
mobile gate. The deadline was missed. Recovery performed only required
validation, documentation and the commit of code already installed before12:00.
No production or QA code changed after the11:35UTC source freeze. Optional
additional final-hour HUD/combat runs were never started and are not claimed.

Pass37 completes truthful online-menu pause copy, removes retired Wardrobe
Chroma offers, and clarifies Renown spending on skins, pets and the existing
weekly cache. Eight isolated native before/after runs passed; all40 full native
images were reviewed. There are416 logged checks:338 strict plus78 before-only
probes,18 expected baseline presentation findings and zero after findings.
Desktop/mobile imports, desktop compile229/quick125/full205, recovery mobile
compile229/strictquick125 and full preflight all passed. The original mobile
quick log stops after8 checks without a completion marker; it is preserved and
excluded. Known native renderer shutdown diagnostics and the full suite's
intentional invalid-base64 test/ObjectDB warning remain documented.

This resume delivers eight improvement passes (30–37): correct capital ward
boards/rewards; painted potion and grounded prop shadows; quieter environments
and compact HUD; floor-mounted doorway torches and clearer dialogue controls;
quieter grass; clearer pocket HUD/Renown notices; reusable hero texture geometry;
and the menu/retired-offering cleanup. Feature evidence is in POTION_HUD.md,
PROP_SHADOWS.md, TORCH_MOUNTS.md, VISUAL_FOCUS.md, GRASS_FOCUS.md,
DIALOGUE_CLARITY.md, POCKET_UI_CLARITY.md, HERO_GEOMETRY.md and MENU_CLARITY.md.
Mobile is synchronized; physical-device testing and whole-game FPS claims
are outside the evidence. Smaller existing Codex targets remain documented debt.

The final commit selects15 explicit paths. Its actual commit identity, all
selected-file hashes, gate logs and immutable native reviews are recorded in
build/qa/checkpoint37-validation.json; the requirement audit is
build/qa/final-completion-audit.json. All16 frozen source hashes and32 inventoried
unrelated scratch/future-QA hashes match. The index was empty before staging.
Unrelated road-hunt/unlisted/vow QA and art scratch are deliberately preserved
and excluded. Restricted skin artwork and older tasks/automations were not
changed. No push or merge was performed. Resume only on new owner instruction.

Pass36 remains `f834ea5116b6ff5dd2b264a30491d9512d9afaa6`; the historical
checkpoints below describe earlier states and do not override this final pause.

**Validated pass 36, 11:19 UTC:** hero raw geometry reuse passed four isolated
desktop phases150/296/174/325 checks and mobile Compatibility174 checks, all
with zero failures and the exact same six-class geometry signature. All125 PNGs
were decoded; all75 clean desktop/mobile images were reviewed. Six clean world
crops are byte-identical. Across139 matched setup phases, actual image reads
fell1433→425 and alpha scans1008→400, counting400 moved seed scans. One clean
pair measured six repeated class calls1917.589→11.616ms; no FPS/whole-boot claim.
Clean production was restored after instrumentation;967 art/import/tuning
hashes are unchanged. Seven source/scene pairs match mobile, and six new QA
UIDs are independent. Desktop import/compile228/quick125/full205 and mobile
import/compile228/strictquick125 passed. Full preflight passed without findings.
The23 explicit paths, native reviews, logs and actual commit identity are in
build/qa/checkpoint36-validation.json. Source/QA/UID freeze stayed exact.
Pass35 is `cfcdb7cf4bcac07b664ef50e80b8ad8a6a1f4f6c`.
Next: truthful online-menu copy and minimal Wardrobe Chroma UI retirement.
The narrow patches and combined QA are reviewed and remain unpublished;
apply to the newer Menus code after QA-first before captures. Preserve scratch.
Continue to12:00UTC feature cutoff and13:00UTC final stable checkpoint.

**Validated pass 35, 10:36 UTC:** the pocket HUD and Renown notice changes
passed desktop compile226/quick125/full205 and mobile import/compile226/
strictquick125. Six accepted native runs passed: focused before161/0 and
after197/0 on both renderers with23images each, and broader discovery209/0
with44images each. All180images were reviewed. Twelve focused actual returns
passed; six baseline Renown/portal overlaps became zero in corresponding
after snapshots, with exact +15 and guardian feed retained and the new short
hint visible on first award only. The corrected QA helper70741980 stayed exact
across accepted before/after runs; two earlier readiness failures are retained.
Five reviewed functions changed across four runtime files, mirrored to mobile.
Final imports preserved the 16-source freeze and independent helper UIDs.
Full preflight passed without findings. The 17 explicit paths and actual
commit identity are recorded in build/qa/checkpoint35-validation.json.
Pass34 remains `eba4b041ab82eea4bcc583edf40975e2f78635bc`.
Next: the frozen hero geometry quartet, followed by reviewed online-menu and
minimal Wardrobe retirement candidates if validated before the cutoffs.
All future candidates remain unpublished. Continue to12:00/13:00UTC.

**Validated pass 34, 09:40 UTC:** quieter V3 grass is installed byte-for-byte
from its preserved generated master on desktop and mobile. All 117 image
artifacts from 16 native runs were reviewed: 28 external comparisons, 60
before/after world views, eight Fangmoot views, 12 terrain/Codex views and nine
normal starting-kit hunt views. Warrior and mage hunts both won without god
mode. The 44-path source freeze changed only the two runtime grass PNGs;
existing imports, production rendering math and historical master remain.
Desktop/mobile imports, scoped art verification, desktop compile225/quick125/
full205, mobile compile225/strictquick125 and full preflight passed. The
initial art checker lacked numpy in default Python; the unchanged check
passed under the bundled runtime. Reviewed floorfield material receipts and
the optional Fangmoot probe are mirrored; both rigs explicitly compiled.
Checkpoint metadata in build/qa records the 16 exact paths and actual commit
identity after commit. Checkpoint 33 remains
`5fb54c46ab862d256d4c8496ac482bf905c4a486`.
Next is QA-first pocket HUD clarity, followed by the reviewed hero geometry
candidate and truthful online-menu copy if validated in time. Those candidates
remain unpublished. Continue until the existing 12:00/13:00 cutoffs.

**Current authorization, September 9, 01:20 UTC:** the owner explicitly resumed
autonomous work in this task and this worktree, superseding the historical
pause below. Continue until **September 9, 13:00 UTC (09:00 America/New_York)**.
Stop new features at **12:00 UTC** and reserve the final hour for validation
and a stable documented checkpoint. Multiple meaningful improvements and
coherent validated checkpoint commits are authorized. No push or merge.

Verified starting branch `codex/crownless-wayfinder`, HEAD
`1ed08314e2dbf5c380cff8b033b5a21e0a53df22`; tracked files and index clean.
Existing untracked art scratch/rejected outputs are preserved. Work only in
`C:/Users/asali/Projects/MMO/.codex/worktrees/crownless-wayfinder`.

This task's continuation is **crownless-overnight-improvements** (20-minute
heartbeat). Pause only that automation at the deadline. The previous tasks
and their paused automations remain untouched. Active goal is attached to
this task. Chromas remain scrapped; all owner artwork restrictions remain.

Pass 30, capital ward boards, is validated. The checkpoint is titled **Open
capital ward boards with accurate rewards**; exact identity/status is recorded
in `build/qa/ward-desks-checkpoint.json`. All four old destinations were
reproduced through actual hotspots. Desktop and strict mobile quick suites
passed (123 checks each); full desktop passed 203 checks and full preflight
had no findings. Desktop and mobile ward/real-ENet rigs passed; mobile tapped
Act, selectors and claim with actual touch events. Existing Activities
regression passed including travel and disconnect ownership. Forty-one
relevant final images were reviewed. Read WARD_DESKS.md and
`build/qa/ward-desks-*` for the 34 explicit paths, frozen source, twelve exact
mobile mirrors, three independent UID pairs, logs and visual reviews.
Root alone owns engine runs, integration and commits. Ward agents have
finished production edits. Continue the authorized work after this checkpoint.

**Committed checkpoint 31:** `c0b685127fa1986959681a28c4c4a9a09d9dc3e5`,
**Ground prop shadows and refine HUD, guardian records and audio startup**.
At that checkpoint, all 76 intended paths matched the commit, the index was
empty, and only the excluded future road-hunt hook remained modified among
tracked source. The list is
`build/qa/checkpoint31-paths.json` (76 paths); the 70 code/scene/UID hashes live
in `checkpoint31-source-freeze.json`. Twenty-eight source/scene mobile mirrors
are byte-identical and seven UID pairs were independently minted. Final desktop
compile224/full205 and mobile compile224/strictquick125 passed. Full preflight
reported no findings. Logs use the `checkpoint31-` prefix under `build/qa/`;
the final identity is recorded in `checkpoint31-validation.json`.

The owner's potion-HUD request uses the existing painted 128px bottle and a
lower-right stock count; touch counts the selected potion. Desktop keyboard
passed 79 checks/six states and final mobile touch passed 81/six states. All
eighteen images from each final run were reviewed. Read `POTION_HUD.md`.
Optional guardian discovery passed 209 checks/44 captures on both desktop and
mobile, including real mobile map taps and detached pocket inspection without
movement. All 88 desktop/mobile guardian images passed visual review.
Read `GUARDIAN_DISCOVERY.md`. Audio startup skips replaced synthesis while
retaining all 72 fallback PCM hashes and recorded-bank/menu contracts. Desktop
and mobile each passed 60 checks/three captures against the clean baseline.
The measured skipped work is not a controlled total-boot timing claim.
Read `AUDIO_STARTUP.md`.

The owner's exact mirrored `tombstone3` shadow defect was reproduced through
the real factory. The shared scenery helper now measures the bottom quarter,
anchors narrow projections to the opaque foot, and fits broad contact rims
to the full source transform. Atlas frames, margins and flipped footprints
have regression coverage. Redundant generic ovals no longer float below broad
props. Interactive gravestones/shrines/chests stay still when addressed.
Final desktop2 and mobile1 each passed 129 checks, 19 fullframes and 18 native
crops; all 74 images were reviewed. Read `PROP_SHADOWS.md`. No artwork changed.
The final integrated full and mobile quick checks include the oval cleanup.
The prior checkpoint is `a74fdfe` (ward boards).

Future baseline preparation remains outside checkpoint 31: the `--unlisted`
hook in `shot_road_hunt.gd`, `tests/unlisted_party_live.gd` and `shot_vow_guard.*`,
including mobile mirrors and independently minted UIDs. No associated gameplay
fix is implemented. Run the negative controls before production changes.
The hero-geometry candidate remains only in `build/qa/hero-geometry-candidate`;
it is reviewed source, not an engine-validated performance result. Read the
Unlisted party, Vow Sentinel and hero-measurement audits under `build/qa/`.
Keep one muted engine at a time and stage only validated explicit paths.

**Latest owner priority:** elevate the overall visuals and clean up remaining
UI/HUD clutter. The owner explicitly requested a subagent research/planning
pass using strong 2D games as references. Three bounded reviews are complete:
`visual-elevation-research.md`, `hud-cleanliness-audit.md` and
`world-visual-feasibility.md` under `build/qa/`. Official remote media could
not be viewed as pixels in this runtime; reference interpretations are labeled,
while the actual Crownless source/assets/native captures were inspected.
After checkpoint 31, prioritize a compact fixed dossier, quieter painted
grave-earth and a deliberate Vigil Gate gathering composition over the queued
Unlisted/performance/combat candidates. Preserve touch targets, skill-point
visibility and vital/action geometry. Root has read the imagegen skill for a
single environmental-material candidate. The first built-in output is preserved
at `art_src/ground_focus_2026-09-09/packed_earth_v1.png` (1254px square), with
the exact prompt and provenance. Native candidate trials
passed on desktop Forward+ and mobile-source Compatibility, including actual
horizontal and vertical camera displacement. Seven final frames per renderer
were reviewed. The untouched master is now installed as
`ground_field_gravedirt_painterly.png` in both projects, with independently
minted import UIDs, mipmaps and a 512px world period. Actual chapter material-only
runs passed 68 checks/nine views on each renderer; all 18 frames were reviewed.
Later ordinary movement and combat evidence is recorded below.
No other generator was used. Read `build/qa/grave-earth-v1-visual-review.md`.
Research is preparation; implement, playtest and compare actual game frames.

Pass 32 is validated for its checkpoint, titled **Refine world presentation,
compact HUD and shadow callback safety**. Exact commit identity and all 59
explicit paths are recorded in `build/qa/checkpoint32-validation.json`. Frozen desktop and
mobile HUD baselines each passed 321 checks, zero fixture failures, 65 old-layout
observations and 19 native frames; all 38 were reviewed. Actual mouse/touch
opened all eight utilities and both stat popovers. Actual-world baselines each
passed 68/nine views including Ilse, Fenna and a stone control; all 18 reviewed.
See `build/qa/visual32-baseline-final-source.json` and the baseline reviews.

Root applied the exact four-piece Vigil grouping from `vigil-gathering-plan.md`,
reduced its scatter budgets, and mapped only the logical ground pebble's static
visual to existing `rock2`. Art's direct pebble/ambient path remains unchanged.
The initial desktop composition run passed 68/nine views with the old HUD.
The reviewed compact HUD candidate (SHA256 `8623071cf405465554ef44f00fb43eb12ffd0d52b06a2c927dc8f613771cd0ea`)
is now copied and synchronized. It has a 104px dossier, fixed 44px utility
targets, Skills badge, separate Party header target and exact portrait details.
The HUD clearance QA now observes the live panel rectangle. Root's first native
compact HUD and enhanced checks are complete: desktop/mobile each passed 503
checks with zero failures/findings and 22 captures, all 44 reviewed. Both ordinary
Vigil walk runs passed 49 checks/31 continuous legs/12 captures; all 24 reviewed,
with actual E dialogue and the blocked gate intact. Mobile walk uses keyboard,
while the HUD rig uses actual ScreenTouch. Both HUD-clearance runs passed all
body/target/touch/menu ownership checks with 12 frames each. The first clearance
fixture missed the shortened panel; its corrected setup maps the actual panel
and body through the canvas transform, retaining the original overlap guard.
Final settled-lighting pebble checks, ordinary combat and combined world
captures are now complete, with results and limits below. Source and capture
reviews remain under `build/qa/`; `VISUAL_FOCUS.md` records bounded evidence.
Final desktop quick/full and mobile import/compile224/strictquick125 passed;
21 exact mirror pairs and five independent UID pairs are verified. Full preflight
passed without findings. Root owns all engines and production
publication. No engines run beside image generation.

**New owner defect, 06:04 UTC:** freestanding stone-pedestal torches overhang
wall edges and look unsupported. The shared `_door_torches()` uses a legacy
40px inset against a 48px wall cap and a mismatched procedural ground line.
The source-reviewed candidate supplies measured floor placement for all four doorway directions,
including ground sorting/shadows and matching light translation, under
`build/qa/wall-torch-mount-candidate`. Checkpoint32 is committed; this is the
active next implementation.
The completed dialogue baselines and reviewed HUD correction are under
`build/qa/dialogue-clarity-candidate` and `dialogue-clarity-fix`. The current
installed state and pending validation are recorded in the Pass 33 block below.

Pass 32 final combined world runs passed 68 checks/nine frames each, and
settled pebble runs passed 258 checks/seven frames each, on both renderers;
all 32 images were reviewed. The ordinary warrior hunt with `--observe=6` and
mage with standard attack timing both won with normal starting health and no
injected damage. The separate six-second-delay mage run **failed its win
requirement: the hero died**. Its six captures remain preserved; the standard
mage win does not erase that failure or establish its cause. Both installed
floorfield/color/mipmap checks passed six frames each, all 12 reviewed; the
opened Codex selected Village, so no graveyard-detail screenshot is claimed.

The first full suite failed the old HUD identity comma-chain assertion; source
review also found the conditional-reflow expectation. The replacement checks
retained identity/title/level/points, fixed nonoverlapping 44px targets and both
explicit Daily/Party visibility states, with restoration before failure.
The pre-existing freed-shadow lambda diagnostic occurs in checkpoint 31 and
the initial pass-32 logs. A new replacement-frame assertion rejected the first
static-bound callback candidate because Godot treated its connections as
duplicates. The corrected per-attachment closure holds only WeakRefs and a
float, resolving live objects on dispatch; shadow geometry is unchanged.

Final desktop gates are **compile224 / quick125 / full205, passed**:
`build/qa/checkpoint32-desktop-quick4.log` and
`build/qa/checkpoint32-desktop-full2.log`. Keep the failed attempts distinct:
initial quick printed a pass marker despite its freed-capture error; the first
full failed the old identity check; quick2 failed replacement-frame following
with duplicate signal errors; quick3 stopped at compile on inferred Variant
warnings, before the suite ran. Quick4/full2 follow the explicit type correction
and contain no freed-capture or script/parse errors. Full2 still contains the
intentional invalid-base64 negative control and bare ObjectDB exit warning;
this is not a clean-stderr claim.

`suite_verdict.ps1` now rejects freed-capture errors. All four log-only fixtures
have matching expected/actual exits in
`build/qa/suite-verdict-lambda-fixtures/results.json`, including the preserved
invalid-base64 negative control. **Final mobile import / compile224 / strictquick125 passed. Source parity
verified 21 exact content pairs and five independent UID pairs; 53 project/verdict
files are frozen. Full preflight passed without findings.**
The 59-path checkpoint excludes all future road-hunt/Vow fixtures and original
art scratch. Root continues with the separate torch and dialogue baselines.

**Committed checkpoint32:** `006ecc196478d7d156105175d7a1d9efae86b9d4`.
All 59 intended files match the commit; the index was empty after commit.
Final full preflight had no findings. Continue the authorized work.

**Pass 33 validated checkpoint, 08:22 UTC:** the torch floor/depth correction and
dialogue clarity patch are installed and canonically mirrored. Final source
`build/qa/checkpoint33-source-freeze.json` contains 22 files, eight exact
content pairs and three independent UID pairs. The 26 explicit checkpoint
paths are in `checkpoint33-paths.json`; none of the excluded future fixtures
or original art scratch are included. Root owns the sole engine.

Torch chapter 1 desktop/mobile passed 112/118 checks, zero failures/findings,
15/16 unique native captures and five ordinary keyboard legs each. Chapter 3
passed 112/142 with 15/20 images and five legs each. All 66 images were
independently reviewed. Close feet offsets -3/+3 correctly switch drawing
order and clipped outlines. Before/after chapter 1 wall/gate/body/light
receipts match, and chapter 3 cross-renderer receipts match. Its secondary
material view repeats Vigil east; no second chapter 3 material is claimed.
Read TORCH_MOUNTS.md and the three `wall-torch-*-review.md` reports.

The original torch frame-window failure and QA-only boolean compile failure
are preserved. Corrected QA gives every natural-frame capture a unique name
and keeps strict bounded all-frame and ordinary-movement checks. No torch
art, collision, wall/gate rule, light budget or hero sizing changed.

Dialogue desktop/mobile baselines had 22 expected defects and 16 images each;
all 32 were reviewed. The final patch measures complete wrapped height,
extends only the necessary footer, places LOG/SKIP/AUTO above choices and
blocks hidden choice activation under the backlog. Final desktop/mobile
runs passed 192/193 checks with zero failures/findings and ten images each.
All 20 final images were reviewed and match the prior corrected captures
byte-for-byte. Actual Fenna, unchanged long text/four options, short reset,
mouse/ScreenTouch, solo and unpaused empty-host behavior are covered. This
is host renderer QA, not physical-device or guest replication proof.

The first corrected desktop dialogue run passed solo probes but could not
bind its derived UDP port; its failed receipt and five images remain. Exact
cause was not recorded. Explicit-port reruns passed; the final QA defaults
to OS-assigned port 0 and records actual ports (59627/61091 in accepted runs).
Production networking is unchanged. Read DIALOGUE_CLARITY.md and
`dialogue-final-native-review.md`. Installed byte hashes are recorded because
Windows line-ending normalization differs from some candidate byte hashes;
normalized reviewed source text is identical.

Desktop compile225/quick125/full205 and mobile import/compile225/strictquick125
passed. Known intentional invalid-base64/full-suite ObjectDB and established
shot renderer shutdown diagnostics remain documented; no new script/freed
callback diagnostics occur. All 86 final native receipts match final source.
Full repository preflight passed without findings. The checkpoint is titled
**Ground doorway torches and clarify dialogue controls**. Exact commit identity,
status and explicit paths are recorded in `build/qa/checkpoint33-validation.json`.

Next candidates remain unpublished: pocket UI clarity, raw hero geometry
reuse and a quieter grass comparison with actual Codex/Fangmoot consumers.
No new grass art has been generated. Continue after this checkpoint until
12:00 feature cutoff / 13:00 deadline, preserving all excluded future work.

## Historical pause — superseded by the resume above

**Latest instruction, September 9, 2026:** "once you are done with your current
feature/work commit it then pause". The current feature is complete. Do not
resume development or start another feature without new owner authorization.
This supersedes the earlier September 9, 09:00 America/New_York deadline.

The completed checkpoint is titled **Improve activity rewards and caravan
reliability**, following `5dbbe54` on `codex/crownless-wayfinder`. Use `git log -1`
for its exact commit ID; the final local verification record is
`build/qa/checkpoint-commit-activity-caravan.json`. It includes passes 28 and 29,
with all earlier passes already covered by `99668d4` and `5dbbe54`. No push was
requested. Existing untracked art scratch/rejected outputs remain preserved.

After this requested commit, pause only this task's continuation,
`continue-crownless-wayfinder-through-september-9`. Leave the older task and its
already-paused `improve-crownless-until-september-9` automation untouched.
The final verification record confirms the continuation's paused state.

**Pass 28 — activity rewards, validated.** Read ACTIVITY_REWARDS.md. Existing
host credit now advances the guest's own board; expired/detached claims are
rejected, gold quotes match payouts, and the journal provides ready-reward
badges and live board updates. Personal save ownership and the existing
four-choices-per-hero daily allowance are preserved. Baseline real ENet/UI
reproduced missing guest credit, 80 quoted versus 262 paid at level 20, and an
expired callback paying 262 while consuming a new day's choice.

Desktop compile214 / quick120 / full200 and mobile compile214 / strictquick120
passed before staging. Thirteen desktop and thirteen mobile real ENet/UI
captures passed and were inspected. Twelve source mirrors and four independent
UID pairs were verified; full preflight had no findings. Source/path/evidence
records: `build/qa/activities-{source-freeze,stage-paths,visual-validation}.json`.
Earlier failed logs remain; the save fixture was corrected for JSON float
representation without changing real ownership.

**Pass 29 — caravan visibility and placement, validated.** Read
CARAVAN_VISIBILITY.md. The real opaque cart now reveals covered heroes and
selected enemies through the existing animated silhouette system. Readers
reject foreign scenery/targets and release old-world masks. A safe-interior
fallback finds usable cart positions missed by the original circle. Offers
explain/disable unavailable placement and recover when space is restored.

The baseline failed on seeds17,19,25; all32 real offers now start on desktop
and mobile. Blocked/restored UI was inspected. Normal starting-kit warlock
combat on seed17 wins in37.749s, minimum51.39/95HP and57.1%load, using ordinary
keyboard attacks/movement/pulling with no injected combat damage. Earlier
normal caravan runs cover all six classes. No new balance or artwork changes.

Final desktop import / compile218 / quick122 / full202 and mobile import /
compile218 / strictquick122 pass. Eight live runs total57 passing captures:
desktop/mobile caravan visibility11+11, placement UI2+2 and real ENet caravan
8+8; desktop ordinary combat7 and existing target-cover8. Thirteen unchanged
representative captures were retained after inspection. Ten source mirrors,
four independent UID pairs and the original cart PNG hash are verified.
Full preflight: no findings. Exact logs, images, limits and frozen paths live
in CARAVAN_VISIBILITY.md and `build/qa/cart-*` records. The explicit pass29 list
has33paths; staging preserves the earlier36-path activity checkpoint.

Evidence limits: mobile captures run the mobile source through Compatibility
on the development host, not physical Android/iOS hardware. The established
full-suite malformed-base64 fixture/bare ObjectDB exit warning and allowed
windowed renderer shutdown diagnostics remain. No new script errors. The
network disconnect harness verifies cleanup and home saves while skipping
actual scene reload; its screenshot does not prove the title transition.

**Possible follow-up, NOT STARTED:** the four capital contract desks still
route to the generic quest-log page instead of their ward board. Source audit
only: `build/qa/ward-desks-audit.md`. No production implementation or live
baseline was started after the owner requested this pause. A future authorized
session can reproduce that issue before choosing a fix. Chromas remain
scrapped; existing pet movement/previews and co-op pet/skin replication are
already complete. No hero-skin art edits are needed.

Worktree: `C:/Users/asali/Projects/MMO/.codex/worktrees/crownless-wayfinder`.
Stay here and preserve all files. Read CLAUDE.md for mobile synchronization,
testing order, muted windowed QA and the one-engine rule. The original Claude
worktree remains untouched.

## Historical checkpoints (superseded by the pause above)

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
