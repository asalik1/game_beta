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

## Contextual choices (checkpoint 10)

Production prompts now name the decision in their title and affirmative action:
Delete letter, Learn blueprint, Accept the curse, Offer gold, Restart chapter,
Cash out, Abandon run, Return to title, Enter trial, Remove player, Buy skin and
Begin challenge. Warning text still states the cost, losses and retained progress.
Ordinary Cancel and existing caller return destinations remain unchanged.

The online trial restriction is a single-action **Solo trials** notice with
**Back to game**. It explains that trials are solo and that the current party can
keep playing; dismissing it neither leaves the session nor enters a trial. All
native dismissal routes share the existing cancellation lifecycle. Generic
internal fixtures retain their existing default confirmation labels.

All 19 source-bound final stages pass: desktop compile/quick/full, scoped mobile
sync/import/compile/strict quick, ten native episodes and strict preflight.
Per project: confirmation 260/260, navigation 158/158, Alchemy 397/397, paired
ENet UI 64/64 and chest 48/48. Actual Claude opened all 100 final originals;
root directly inspected 17 and reviewed every finding across 24 batches.
Exact sources, runtime receipts, image proofs and scoped root dispositions are
bound in `build/qa/session-sept20/contextual-confirmations/checkpoint-validation.json`;
`commit-receipt.json` beside it records the resulting HEAD and local state.
One final review needed a pinned syntax-only derivative removing six malformed
JSON boundary tokens. Raw output and initial failure remain unchanged. A private
queue wrapper later failed on a file glob after its final providers finished;
their existing output was verified without launching another provider.

Host kick, shrine offering, skin purchase and weekly challenge have source review
only. Restart/cash-out/abandon fixtures exercise cancellation, not actual reward
payout or resets. Actual Alchemy learning preserves exact transaction checks.
The first hot-chest pilot lost native held input before the dialog and is rejected;
its cause is unproven. Isolated rerun and final desktop/mobile episodes pass the
unchanged strict guard with focus/physics diagnostics. The earlier Claude source
review timed out and remains incomplete, separate from final visual reviews.
Shared coral styling on ordinary actions and the inherited abandon warning's
saved-progress wording remain explicit follow-up, not additional accepted changes.

## Reproduction and validation

Run `shot.bat menu_navigation --confirm-layout --timeout=300` with fresh APPDATA
under `build/qa`. Add `--mobile --renderer=gl_compatibility` for mobile sources on
the development host. This exclusive mode requires captures and rejects baseline
waivers. It exercises actual mail-delete, Pause-exit and both endgame rule
confirmations; measures complete glyphs, first/settled geometry and action bounds;
and uses native mouse, keyboard, controller Back, wheel and touch events. The
complete long-copy fixture, including its wheel captures, enables and restores
the same host touchscreen-capability emulation used by Settings QA. Its dismissal
hint therefore describes touch on those wheel views too. It is not a physical-device test.

`shot.bat brewing_persistence --ui-only --timeout=300`, with APPDATA inside
`brewing-persistence-candidate`, additionally opens the actual solo-trial gate on
a real paired ENet guest. A positive ability-intent control precedes confirmation;
movement and ability intent are blocked under the overlay while physics and the
world clock continue. Native touch and controller cancellation preserve the
session, world and economy. This UI-only run does not prove persistence roundtrips.
Its separate child-scene disconnect experiment remains explicitly unaccepted.

Checkpoint 9 reference: all 19 final validation stages pass: desktop compile/quick/full, scoped mobile
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

The generic labels and technical online trial wording were unchanged in
checkpoint 9. Checkpoint 10 replaces those production labels and online copy;
its scoped validation is recorded above.
Alchemy disclosure state, tight metadata placement, compact controls, faint
secondary text and other world/HUD findings remain explicit follow-up. No
physical-device, separate unbroken-word or native gamepad-scroll proof is claimed.
