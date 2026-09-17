# Exploration interaction and ability landings

Desktop and mobile native checks, required suites and full preflight pass.
The original exploration checkpoint receipt is
`build/qa/session-sept10/exploration-checkpoint-validation.json`.

## Player behavior

Hunt signs respond to E, controller A and the touch Act button throughout their
own interaction range. Direct sign taps already used this range. The common
selector formerly initialized its nearest-distance search to the default 80px,
silently capping signs that advertise 160px. It now starts at infinity, then
uses each entry's existing strict distance limit. The closest eligible entry
still wins; tighter prop hotspots, default reach and disabled entries keep
their rules. No interaction radius or content table changed.

Shield Bash, Shadow Dash, Blink and Tumble check the space needed by the hero at their
destination. A clear destination preserves the requested movement, including
crossing intervening scenery. An occupied destination retreats along the same
approach until the hero's body fits. This removes landings inside props and the
following unwanted push out of them. Movement input chooses direction; with
no movement held, the hero uses their facing. Codex › Field notes › Combat
explains this behavior under **Land on clear ground**.

## Collision and combat contract

`scripts/dash_landing.gd` reads the actual enabled collision shapes, their
transforms and offsets, the body's collision mask and safe margin. Queries
ignore areas, the body's own RID and explicit collision exceptions. The
ordinary player scans terrain and enemy bodies. Open endpoints return exactly;
occupied endpoints search backward in steps no larger than one world pixel.
The helper never extends the requested segment or shifts it sideways.

This is destination clearance, not swept walking or pathfinding. It does not
repair an already blocked starting position. If no sampled position is clear,
the hero keeps the original position. A clear pocket narrower than the sampling
step can be skipped. Query count depends on the actual room-clamped segment
length and active shape count; the longest nominal ability distance is not a
universal bound because existing room clamping can also shift an edge position.

The shared strike keeps its former room-clamped attack corridor, hit order and
rider/refund logic. Large enemy bodies can stop the hero outside the existing
55px center-based blade reach; shortening that corridor would lose an intended
hit. Thus a shortened movement can still strike along its intended corridor.
The visual trail, hit direction and landing-centered effects use the actual
arrival position. Knockback directions can therefore change when movement is
shortened; the paired damage checks compare ordered amounts and HP debits,
not every field of the recorded damage calls.
Warrior Earth slams and Assassin mist/Mirrorstep geometry can consequently move
when a destination is blocked; this change does not promise identical positions
for every themed follow-up. Coefficients and eligibility rules are unchanged.

The accepted original checkpoint left Archer Tumble, Paladin Judgment,
Assassin execution flanks, ordinary walking, spawns and capital arrival
placement on their separate paths. No protected artwork, save schema or RPC
format was modified.

## Death Mark extension — September 17

The final execution now sends its existing room-clamped 46px far-side request
through the same body-footprint landing resolver. `DEATH_MARK_FAR_SIDE_OFFSET`
names that unchanged distance in `balance.gd`. Clear endpoints stay exact;
occupied endpoints retreat along the original approach. In particular, a large
boss can force arrival onto the approach side rather than behind it. This is
not a sideways search, overlap repair, or a guarantee to arrive behind a target.
The existing chapter-lifetime guard, two crossing hits, delays and coefficients
remain intact. Unlike the shared dash corridor, this final stab originates at
the actual landing. Representative pairs preserve all three hits, but an
arbitrarily long retreat cannot guarantee every possible target remains in range.
The class ability description and Combat field note explain the blocked landing.
Paladin Judgment, ordinary movement and spawn placement remain separate paths.

Evidence under `build/qa/session-sept17/`:

- `deathmark-baseline/`: 295 checks, zero unexpected failures and exactly 18
  expected findings: initial overlap and subsequent recovery drift across eight
  factory-boulder directions and one production-sized Vargoth. Root opened all
  three native frames. No production landing changes were applied in this run.
- `deathmark-after/`: 295 checks, zero failures/findings, all six contact/settled
  frames opened by root. Eight clear-versus-blocked wolf pairs and a scanned /
  unscanned large-boss pair preserve all three positive player-sourced damage
  calls and exact HP removal. All nondegenerate arrivals are clear; twelve
  subsequent zero-input movement steps produce zero drift. The already-overlapped
  coincident start remains finite and unchanged, with no clearance promise.
- `deathmark-hunt/`: L1 base Assassin wins the ordinary live quarry in 24.235s,
  HP 95 -> minimum 64.4118 -> 95, earning 120 gold. No god mode, resource grants
  or injected combat damage. Optional ultimate-first keyboard strategy observes
  activation and a 204.5px rendered jump with the final stance, then resumes
  the existing full-kit fight. All nine native images opened by root. Hunt sign
  teleports and deferred terrain events are setup controls; this is not a chapter
  playthrough. Render-frame sampling is not instantaneous collision proof.

`shot.bat exploration_friction --deathmark --field-notes --timeout=180` runs the
controlled matrix and actual Codex reading. Baseline omits `--field-notes` and
requires exactly the 18 named findings. Direct effect fixtures freeze hero/AI,
raise target HP, and temporarily mask other bodies. Contact FX and boss artwork
can obscure the hero despite clear colliders; frozen unrelated NPC prompts can
remain stale. These frames do not establish every world-UI or art arrangement.
The normal-input hunt uses `shot.bat hunt_combat --class=assassin
--deathmark-observe --trace --timeout=180` with a fresh isolated profile.

Final desktop quick/full pass (145/225). The two-reader local ENet Death Mark
mode passes 68 checks and four root/independently reviewed native images. It
uses real native ultimate input, then holds guest physics through the delayed
arrival query. Clear and factory-boulder cases retain identical raw hits
10.15/10.15/18.85 and host HP debits 15.225/15.225/28.275, including exactly one
application of the mark's vulnerability. Guest attribution and ordinary movement
and HP snapshots converge; host hero and both economies remain unchanged.
This is manually admitted local transport with stationary actors and matched
scenery, not a moving fight, latency/loss test or full world-snapshot proof.
Mobile import/compile/strict quick (145), exact ten-path sync, final desktop and
mobile matrix/Codex reading (305 each) and mobile ENet (68) pass. The unchanged
default guest Blink adapter passes 47 checks. Root opened all 44 native frames
across the baseline, iterations, hunt and final runs, including the complete
Codex paragraph on both renderers. Compatibility shadows differ from desktop;
the source fixture disables touch controls. This is host-rendered mobile-source
validation, not physical-device or touch-input validation. Full strict preflight
passes. `deathmark-checkpoint-validation.json` records source/evidence hashes,
the resulting commit, exact owned paths and preservation audit. Root reviewed
all 44 native frames; independent reviewers opened thirty of them.

## Tumble extension

The Archer change computes the same 130px room-clamped request once, using
`Balance.TUMBLE_DISTANCE`, then passes it through the existing landing resolver before the ordinary,
Frostfall Ranger and Voidwraith presentation branches. The behavior
is the same destination-clearance rule described above: preserve a clear
endpoint across intervening obstacles, or retreat an occupied endpoint along
the requested segment. The helper's sampling and invalid-origin limits still
apply. This does not add a swept path or change ordinary walking.

Base Tumble has no damage strike and does not use the shared strike corridor.
The existing perfect-dodge/heavy window, evasion, Windrunner DR, Hart's Breath
arming and theme riders remain in place. Storm/Venom departure effects retain
their origin; landing presentation receives the resolved arrival. This does
not promise identical position-dependent combat results or skin animation
quality. No ability cost, cooldown formula, arrow path, save schema or network
protocol is changed by the movement edit.

The accepted baseline records 1,043 checks: 1,029 pass, fourteen expected
Tumble findings and no unexpected failures or skips. Eleven occupied terrain
landings and the scanned-actor checks expose the old overlap. Zero-input
recovery moves the hero 23.66–37.66px and becomes clear by the final observation;
this is unwanted displacement, not a permanently stuck hero. All eight open
Tumble endpoints preserve the full movement across the boulder. The older
interaction and terrain controls pass.

The final constant-form desktop and mobile **after2** runs each pass 1,053 checks with no
findings, failures or skips and 42 captures. Their 25 interaction, 54 terrain, nine actor and four
damage-pair rows include nineteen Tumble terrain cases, the two actual
Frostfall/Voidwraith branches and scanned/unscanned actor controls. Every
terrain landing and all 162 recovery observations are clear, with zero
recovery displacement. The four damage pairs retain the original three
classes' damage amounts and zero immediate base-Tumble damage. The ten Codex
checks expose the complete updated four-line paragraph through real clicks,
wheel input and Escape cleanup. Root reviewed all twelve Tumble captures, four
older class/input controls and the Codex page on each project; independent
review covers all 41 baseline and all 42 originals from each after run.
The same final source passes desktop quick/full 143/223, mobile import,
ordinary compile 253, strict quick 143, native compile 255 and all seven strict
preflight categories. Six mirrored source paths, 26 frozen source files per
project and all 46 preserved unrelated/unfinished paths remain exact. The
15-path checkpoint receipt is `build/qa/session-sept10/tumble-after2-checkpoint-validation.json`.

Run `shot.bat exploration_friction --tumble --endpoint-contracts --field-notes
--timeout=300` with isolated APPDATA. This uses posed/frozen actors and existing
input controls. Recovery consists of twelve calls to the zero-input movement
primitive, not twelve complete Player updates. Old trails and floating damage
labels can persist; the actual damage ledger establishes the current cast's
effect. Voidwraith's portal and temporary invisibility limit visible-foot
claims. These runs do not establish moving combat, skin animation fidelity,
physical-device behavior or Tumble co-op replication; the earlier guest Blink
receipt proves only its own scope.

With `--baseline --tumble`, the runner retains its historical nine reach
exemptions but makes the old terrain cases strict. The accepted baseline's
separate exact fourteen-finding whitelist rejects any unexpected old reach
finding. After runs have no baseline exemptions. The interrupted combined
runner passed desktop quick/full 143/223 and strict native validation, then
stopped at a read-only whole-tree mobile drift report before mobile execution.
That failure is preserved; it is not a passed overall pipeline. A separate
continuation passes the read-only five-path sync check, mobile import,
ordinary compile (253), strict quick (143), native compile (255) and final
source continuity. Its preflight completes with zero failures and one warning:
the existing literal travel distance moved onto a changed line. That unchanged
130px tuning value is now in Balance; the separate final constant-form runner
passes fresh desktop/mobile validation and all seven strict preflight checks clean.
Both earlier literal-form runs also passed 1,053 native checks and received full
independent review of their 42 images, but remain evidence for that earlier source.
The global drift consists
of 33 older sprite PNG differences, eight UID-only import differences and 41
older mobile-only files. Exact initial/current Git comparisons, including raw
PNG bytes, are recorded under
`archer-tumble-candidate/checkpoint-mobile-continuation-b07cbb6` in the session
QA directory. This checkpoint does not declare the entire mobile tree clean.

## Evidence and reproduction

Use the muted, compile-gated single-engine runner with isolated APPDATA:

```powershell
.\shot.bat exploration_friction --competition --endpoint-contracts --field-notes --timeout=300
```

Add `--mobile --renderer=gl_compatibility` for the mobile project. This renders
the mobile source on the Windows host; it is not a physical-device test.

The base scenario uses a posed hero, a real hunt sign, synthetic production
keyboard/pad/touch input, frozen enemy AI and explicit camera framing. Its 25
interaction rows bracket long, default, tight and disabled reaches. Six optional
competition rows reverse registration order around a harmless recorder entry.
The 35 terrain rows cover three class examples against an authored signpost,
three classes in eight directions against a production-factory boulder, and eight clear-endpoint Blink
controls. First landing observations occur after the real Player physics
callback. Recovery calls the production zero-input move primitive 12 times;
these are not 12 complete Player updates or an ordinary combat playthrough.

Accepted baseline **before4**: 549 checks, zero unexpected failures and 36
expected findings. Nine E/pad/Act reads miss at 81/120/159px; 27 landings overlap
terrain. The latter move 23.49–37.91px during zero-input recovery and become clear
by the last observation. This demonstrates unwanted displacement, not a
permanently stuck hero. All eight clear-endpoint Blink controls remain clear.
All 22 full frames have root and independent review. Earlier compile failures
and the before2 HUD-intercepted run remain rejected artifacts.

Strict desktop **after1**: all 620 checks pass, including six competition rows.
All 35 landings are clear and every recorded recovery displacement is zero.
All 25 full frames were reviewed. Before4 and after1 use independently generated
world seeds and checked geometry; they are not pixel-aligned image comparisons.
The frozen fixture can retain old clue toasts, trails and prompt/card text;
actual entry distances and activation ledgers govern the interaction checks.

Final desktop **after5** and mobile **after1** each pass **796 checks**, with
25 interaction, six competition, 35 terrain and seven full-mask actor rows.
The actor matrix pairs unscanned/scanned Vargoth bodies for all three classes,
plus an open-endpoint Blink across that body. All landings are clear; terrain
recovery displacement remains zero. Warrior/Assassin/Mage make respectively
2/4/1 actual damage calls, including the boss's crowd-control concussion calls.
The three pairs preserve ordered damage amounts, exact HP debits, mana and
cooldown. Real physics observations check the posed server origin, self-RID
exclusion, first cast tick, cached walking motion and nearest contact bounds.
This uses a stationary posed boss with deterministic combat controls. Frozen
hit flashes and accumulated trails obscure parts of the hero; the collider
ledger establishes physical clearance, not complete artistic separation.

The actual Codex entry opens through three clicks, exposes its complete heading
and three-line paragraph with two wheel inputs, then returns through Escape.
All ten reading/cleanup checks pass. All 33 full frames per project received
independent review; root additionally reviewed the seven actor frames, Codex
page and four representative input/terrain frames on each project.

The focused guest Blink rig also passes **47 checks per project**, with two
actual-input cases and four full frames each. It uses two readers and real ENet
in one engine, manually admitted peer bookkeeping, a stationary ordinary wolf
and the production replicated enemy body. Each cast applies one host damage
call attributed to the guest, and ordinary position snapshots and the exact
8-bit HP fraction converge. Host resources and both economies stay unchanged;
the actor remains alive. All eight frames have root and independent review.
These are scoped transport/ownership checks, not moving combat, admission,
latency, physical devices or security validation. A coalesced damage-meter
display can lag the exact host ledger in a capture. Run with isolated APPDATA
inside `guest-blink-enet-candidate` using `shot.bat guest_blink_enet --timeout=180`.

Desktop quick/full and mobile strict quick pass **143/223/143**, including 16
isolated physics contracts for actual shapes, offsets/rotation, layers,
exceptions, disabled collision, open endpoints and nearest-clear retreat.
All seven preflight categories pass. Final native compile gates include all
254 installed scripts; mobile import and explicit compile/strict quick pass.

Expanded intermediate runs remain rejected. After2 used a post-teleport getter
to reconstruct earlier walking; after3 sampled a posed body's server footprint
too early; after4 timed out in the Codex probe and crashed at shutdown, leaving
no final ledger. The Codex correction fixes an impossible inset-width scroll
condition and replaces unbounded redraw waits with the established paused-menu
capture path. The old log cannot identify which wait stalled. Network desktop1
reached its case checks but failed on a freed observer reference during cleanup;
its HUD-obscured framing was also corrected before the accepted runs.

Exact source, report, log and full-frame hashes live under
`build/qa/session-sept10/exploration-before4-validation.json` and
`exploration-after1-validation.json`, final `exploration-after5-validation.json`
and `exploration-mobile-after1-validation.json`, plus the guest Blink desktop2 /
mobile1 receipts. The established renderer shutdown texture diagnostics remain
visible and are handled by the unchanged strict runner.
