# Alchemy detail readability

Checkpoint 13 validated September 21, 2026.
Checkpoint 11 established fixed recipe metadata/actions; checkpoint 12 added
readable gold grouping and ordinary confirmation colors. Both remain preserved.

Ingredient sources now has a dedicated reading view in the left rail. The rail
shows either recipe filters/list or the complete sources text for the selected
recipe and grade. A persistent 44px action explicitly switches between
Ingredient sources and Back to recipes. The right recipe, effect, requirements,
learning explanation, ingredient counts, fee, Learn/Brew and result stay in place.
The footer return action follows the rail width and column gap, keeping its
caption centered and the adjacent usage note aligned with the recipe column.

The reader uses 16px prose, native wrapping and a reserved scrollbar gutter.
Both rail views have matching content minimum widths. Fitting paragraphs should
be visible in full; genuinely overflowing content keeps native wheel/touch
scrolling. No estimated line-height solver or artificial overflow is used.
Source facts, prices, mastery rewards and transaction guards are unchanged.

Recipe selection, grade, filter and list position survive reading and returning.
Reader position survives quote refresh while the reader remains open. Switching
between recipes and sources resets the source reading position to the top.

## Validation

Use the existing muted, compile-gated `shot.bat alchemy --timeout=300` with fresh
isolated APPDATA. Add `--mobile --renderer=gl_compatibility` for mobile sources
rendered on the development host. Keep the original paid ledgers, stale-order
rejection, mail overflow, blueprint confirmation and native input checks.
Paired real ENet UI coverage uses `shot.bat brewing_persistence --ui-only
--timeout=300` with APPDATA inside a `brewing-persistence-candidate` directory.

The existing rig checks the actual reader/list partition and full subject text,
restores the real recipe caption/list offset on return, and samples right-column
geometry before toggling and in first/settled frames after release. Its source
label contrast and essential-glyph clipping checks remain. Full sources glyphs
must fit when the native viewport fits them; overflow requires positive native
wheel/touch movement from the top and a complete reachable tail. Input over
fitting content must be reported as no scrolling proof.

These are controlled resource/mastery loans and native input, not ordinary earned
progression. Compatibility rendering and emulated touch on Windows are not
physical-device testing. ENet UI-only does not establish persistence roundtrips.
Original screenshots require actual review; passing logs do not accept quality.

Actual Claude implemented the private reader and actual DeepSeek adapted the
existing QA. Independent review corrected equal-width allocation, pre-toggle
sampling, caption types, hidden-list memory and fit-mode evidence. Raw drafts,
timeouts and corrections remain under
`build/qa/session-sept20/alchemy-source-reading-candidate/`. Current validation
belongs under `build/qa/session-sept20/alchemy-source-reading/`.

## Checkpoint 13 acceptance

All 13 serial stages passed against the frozen final source, including desktop
compile/quick/full, mobile scoped sync/import/compile/strict quick, both strict
preflights and native Alchemy/paired ENet UI on both renderers. Alchemy passes
658/658 per renderer; ENet UI passes 64/64. All eight first/settled frame pairs
and cross-view recipe-column comparisons show zero displacement. Both source
examples fit completely in their 374px reader; no positive source-scroll claim.

Root inspected 26 final originals and the independent peer inspected all 40
Alchemy originals. Their union covers all 54 emitted final originals. The footer
now follows the actual rail width and recipe column guide. Actual Claude's four
pilot-image reviews preceded that footer adjustment and are retained separately;
final acceptance uses the new originals and frozen source. Provider timeouts,
raw drafts and corrections remain preserved. Existing small secondary/disabled
text and partial unselected recipe-list edges remain limits, not new regressions.
Known engine shutdown diagnostics remain handled by the existing strict runners.
The older child-scene disconnect experiment is not accepted by these UI checks.

Exact hashes, gates, review scope and preservation audit are in
`build/qa/session-sept20/alchemy-source-reading/checkpoint-validation.json`;
`commit-receipt.json` there records the resulting commit and local state.

## Checkpoint 11 history

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

At checkpoint 11, optional source prose could still clip at a scroll edge; its
complete tail was reachable. Small secondary text, disabled-label contrast, thin scrollbars,
uneven footer alignment and ungrouped prices remain follow-up work. This
checkpoint does not claim that the entire UI is polished. Strict acceptance
evidence is in `checkpoint-validation.json` under the evidence directory below.

Runtime evidence and current phase are under
`build/qa/session-sept20/alchemy-detail-readability/`.
