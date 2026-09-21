# Alchemy detail readability

Validated checkpoint 11, September 21, 2026. Commit and local-state receipt:
`build/qa/session-sept20/alchemy-detail-readability/commit-receipt.json`.

The brewing bench keeps the selected bottle, effect, grade, mastery requirement
and blueprint status above optional source help. Collapsing help removes its
empty viewport instead of separating the recipe from its ingredients. Ingredients,
fee, Learn blueprint, Brew and the result remain outside help scrolling. The
learning explanation is fixed below the mastery requirement, and the two actions
share a row. Expanding or collapsing help may change their position; scrolling help must not move the action area.

The existing named detail scroller retains its remembered position. Its viewport
uses the native container's remaining height, with a reserved scrollbar gutter
and bottom clearance. An empty viewport is hidden; no custom height solver is used. Source disclosure
uses the shared tab style with a readable normal label and accurate Show/Hide
tooltips. No art, recipe prices, mastery rewards,
transaction callbacks, watcher signatures or trade rules are changed.

## Validation

Use the existing muted, compile-gated `shot.bat alchemy --timeout=300` with fresh
isolated APPDATA. Add `--mobile --renderer=gl_compatibility` for mobile sources
rendered on the development host. The original recipe previews, exact paid
transactions, stale-order rejection, mail overflow and callback/input checks stay
required. Paired real ENet UI coverage uses the existing
`shot.bat brewing_persistence --ui-only --timeout=300`, with APPDATA inside a
`brewing-persistence-candidate` directory.

The native Alchemy rig additionally toggles actual Sources controls for an
unknown A-grade Renewal blueprint and an E-grade Mana Tonic. It checks essential
shaped glyphs against clipping ancestors, compact collapsed spacing and fixed
Learn/Brew bounds while scrolling. The Sources normal-font contrast is checked
against a native rendered background sample, alongside original-image review.
Wheel and touch must reach the optional content's
last glyph. An overflowing touch case must move from zero to a positive offset;
a fitting viewport is explicitly recorded as no scroll proof.

First and settled originals and numeric observations expose any change after
native toggle release. Passing functional checks alone do not accept visible
layout movement, scroll restoration or focus changes. Root must review those
originals and bind its disposition to the report and source hashes.

These are controlled resource/mastery loans and native input, not ordinary earned
progression. Compatibility rendering and emulated touch on Windows are not
physical-device testing. ENet UI-only does not establish persistence roundtrips.

## Candidate history

Actual DeepSeek supplied the initial private implementation. Independent review
corrected state identity, ownership guards, stale node references and clipping/
touch observations before the first pilot. V1/V2 and provider raw outputs remain
under `build/qa/session-sept20/alchemy-detail-readability-candidate/`.

Compile and quick passed. The first native pilot failed seven target-size checks:
shared tab styling reset Sources from 44px to 38px. Its first frames also revealed
late recipe-rail restoration and a 4px collapsed-blueprint layout movement.
That pilot is rejected and retained. Actual Claude timed out after 480 seconds
without a completed patch; its raw partial output is not accepted implementation.
A deferred fitting experiment then collapsed help to zero height (35 failed
checks); a signal-driven fitting experiment caused minimum-height feedback and
panel overflow (6 failed checks). Both are rejected and preserved.

The fourth pilot uses native container allocation and hides empty optional help.
It passes all 530 checks, including zero first/settled movement in four cases,
positive touch scrolling in both help examples, and exact saved rail/detail
offsets after brewing. Final desktop and host-mobile Alchemy runs each pass
530 checks; paired ENet UI
runs each pass 64. All 13 serial validation stages pass, including desktop full,
mobile import/compile/quick and strict preflight. Root directly inspected 28
originals. Actual Claude image review then identified Learn disappearing below
optional help when expanded, and weaker active Sources contrast. That final-v1
candidate is superseded, with its passed gates and raw critical reviews preserved.
A corrected candidate keeps Learn beside Brew and brightens the Sources label;
its fifth pilot passes all 563 native checks. Root inspected five pilot originals;
Learn is visible in both disclosure states and normal Sources text measures
7.46:1 against its selected fill. Fresh final desktop and host-mobile Alchemy
each pass 563/563, and paired
local ENet UI each passes 64/64. All 13 serial stages pass, including full campaign
validation, mobile import/compile/quick and strict preflight. Root separately
opened 25 final originals and accepted all eight zero-movement frame pairs.
Actual Claude reviewed all 54 fresh originals across 12 bounded batches; root
reviewed every advisory and independently resolved three batch findings using
the originals and exact fixture behavior. Sources has a visible active fill;
disclosure reflow is intentional, while first-to-settled movement is zero. The
ENet footer variation follows deliberate touch-capability setup. All raw
findings remain retained. No acceptance is transferred from superseded source.

Optional source prose can still clip at a scroll edge; the complete tail is
reachable. Small secondary text, disabled-label contrast, thin scrollbars,
uneven footer alignment and ungrouped prices remain follow-up work. This
checkpoint does not claim that the entire UI is polished. Strict acceptance
evidence is in `checkpoint-validation.json` under the evidence directory below.

Runtime evidence and current phase are under
`build/qa/session-sept20/alchemy-detail-readability/`.
