# Exploration interaction and dash landings

Desktop and mobile native checks, required suites and full preflight pass.
The exact checkpoint receipt is
`build/qa/session-sept10/exploration-checkpoint-validation.json`.

## Player behavior

Hunt signs respond to E, controller A and the touch Act button throughout their
own interaction range. Direct sign taps already used this range. The common
selector formerly initialized its nearest-distance search to the default 80px,
silently capping signs that advertise 160px. It now starts at infinity, then
uses each entry's existing strict distance limit. The closest eligible entry
still wins; tighter prop hotspots, default reach and disabled entries keep
their rules. No interaction radius or content table changed.

Shield Bash, Shadow Dash and Blink check the space needed by the hero at their
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

Archer Tumble, Paladin Judgment, Assassin execution flanks, ordinary walking,
spawns and capital arrival placement are separate paths and are not changed.
No protected artwork, save schema or RPC format is modified.

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
