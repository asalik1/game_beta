# Confirmation layout

September 21, 2026 checkpoint: shared confirmations fit their rendered copy.
Short decisions use a compact panel, 18px body text and a single row of 190×48
buttons, with Cancel on the left. Longer messages scroll inside a bounded body;
the actions and dismissal hint stay visible. The existing theme supplies the
fonts, colors and panel. No new artwork is involved.

The dialog measures its actual attached, themed controls at their final width,
including a reserved scrollbar gutter, then fits the existing shell synchronously.
The shared shell still owns input, pause, HUD visibility, animation and closing.
Caller messages, transaction callbacks and cancellation destinations are preserved.
A replaced dialog cannot invoke its actions against the next screen. Yes receives
no automatic focus, and Enter before choosing does not accept the confirmation.

## Reproduction and validation

Run `shot.bat menu_navigation --confirm-layout --timeout=300` with fresh APPDATA
under `build/qa`. Add `--mobile --renderer=gl_compatibility` for mobile sources on
the development host. This exclusive mode requires captures and rejects baseline
waivers. It exercises actual mail-delete, Pause-exit and both endgame rule
confirmations; measures complete glyphs, first/settled geometry and action bounds;
and uses native mouse, keyboard, controller Back, wheel and touch events. The
long-copy touch case enables and restores the same host touchscreen-capability
emulation used by Settings QA. It is not a physical-device test.

`shot.bat brewing_persistence --ui-only --timeout=300`, with APPDATA inside
`brewing-persistence-candidate`, additionally opens the actual solo-trial gate on
a real paired ENet guest. A positive ability-intent control precedes confirmation;
movement and ability intent are blocked under the overlay while physics and the
world clock continue. Native touch and controller cancellation preserve the
session, world and economy. This UI-only run does not prove persistence roundtrips.
Its separate child-scene disconnect experiment remains explicitly unaccepted.

All 19 final validation stages pass: desktop compile/quick/full, scoped mobile
sync/import/compile/strict quick, ten native episodes and strict preflight (all
seven categories). Per project: confirmation 147/147, navigation 158/158,
Alchemy 391/391, paired ENet UI 28/28 and chest interaction 37/37. Actual Claude
opened all 76 final originals; root independently inspected 12 key originals
and reviewed/disposed every provider finding. These are scoped visual results,
not whole-game visual approval.
Final evidence is recorded in `build/qa/session-sept20/confirmation-layout/checkpoint-validation.json`;
the `commit-receipt.json` beside it records the resulting HEAD and local state.

These are controlled characters, mail/resources and synthetic stress copy, with
actual production callers and native input. They do not establish ordinary earned
progression or physical-device usability. Failed evidence is retained: the old
layout fails 17/102 checks, and pilot 1 fails touch dragging because its desktop
fixture omitted the required capability emulation. The corrected fixture reaches
the tail in three native gestures, with no production workaround. The native
runner retains its established renderer shutdown diagnostic classification.

Actual Claude Fable supplied the first sizing proposal, rejected for estimated
font/line metrics; its revision exhausted Fable credits. Authorized Claude Opus
supplied the measured candidate. Actual DeepSeek supplied QA and evidence-collector
drafts; independent review corrected their geometry, fixture and report assumptions.
Raw prompts, provider outputs, rejected drafts and source pins remain under the
same private evidence directory. Final acceptance requires independent source,
original-image and runtime review, not provider claims alone.

The first final chest attempt used an invalid isolated-profile location and
stopped before gameplay or captures. Its failure is preserved separately; the
corrected profile passed without changing game sources. Earlier passing stages
remain bound to the same frozen sources. One visual provider nested its overall
summary and empty blockers inside its image row; a documented structural-only
copy corrected the schema while retaining every raw image finding unchanged.

Existing generic confirmation labels and technical online trial wording remain
unchanged here. A separate private contextual-wording candidate is unfinished.
Alchemy disclosure state, tight metadata placement, compact controls, faint
secondary text and other world/HUD findings remain explicit follow-up. No
physical-device, separate unbroken-word or native gamepad-scroll proof is claimed.
