# Activity rewards — pass 28 validated

Included with pass 29 in the owner-requested checkpoint titled
`Improve activity rewards and caravan reliability`, following `5dbbe54`.
Development is paused after that commit; see AUTONOMOUS_STATUS.md. Earlier
staging notes below describe the pre-commit validation.

A real two-game ENet/journal check reproduced three defects: an eligible guest
received no ward-contract credit, a level-20 card quoted80 gold for an actual
262-gold reward, and a retained callback paid262 gold after its daily board
had refreshed, consuming one of the new day's choices.

The first implementation forwards existing authority credit into the owner's
own contract board, requires current entry identity when claiming, refreshes
the board before progress/claims and uses the exact payout formula in contract
and bounty cards. It preserves the existing per-character save and four-choice
allowance; misleading account-wide comments are corrected, without moving
boards or rewards between characters.

The journal icon shows claimable ward/vault rewards and opens Activities when
one waits. The Activities tab counts them; ready ward choices appear first,
with44px claim controls and explicit ward names. The board updates while open
in co-op or across a daily refresh, retaining scroll position. Unready boards
keep the sanctuary collection first. The Codex has Activities & rewards field
notes. No art changes or protocol payload changes.

Final desktop compile 214 / quick 120 / full 200 pass. Thirteen real ENet/UI captures
pass, including touch layout/claim controls, one chosen ward, live quote and
scroll refresh, daily rollover, the Codex link, party travel and home saves.
Mobile import / compile 214 / strict quick 120 and thirteen live captures pass.
Both renderers' representative captures were inspected. Full preflight has no
findings. Twelve frozen source mirrors and four independent UID pairs match.
The original 36-path staging manifest is build/qa/activities-stage-paths.json.
Protocol remains 0.3.15; no art changes.

Evidence: build/qa/activities-final-desktop-{quick,full}.log,
activities-extended-fourth.log, activities-mobile-*.log and the source audit
ward-activity-audit.md. Capture paths/limitations and the source freeze live
in activities-visual-validation.json and activities-source-freeze.json.
The reviewed directory retains unchanged representative PNGs. The disconnect
harness deliberately skips scene reload; its image does not establish the
real title-screen transition. No physical mobile-device claim.
Established renderer shutdown diagnostics remain in the windowed logs. The
full suite's malformed-code fixture and bare ObjectDB exit warning also remain;
the existing strict verdicts pass, with no new script errors.

The baseline live rig correctly failed all three reproduced defects. The fixed
capture quotes262 gold; the expired callback pays0 and consumes0 claims.
Later iteration caught and fixed the badge button's missing routing. A save
assertion initially compared live integers with JSON floats; diagnostics
confirmed identical values and an unchanged home world. That fixture now
compares the same JSON representation. Earlier failed logs remain for review.

The additional normal starting-kit caravan roster audit passed on all six
classes. New assassin:28.47s,95/95HP untouched,load84.65%; warlock:35.334s,
minimum61.54/95HP,load73.5%. Captures inspected; no tuning change justified.
Details: build/qa/roster-final-class-audit.json. Warlock's live view exposed a
separate missing cart-occlusion registration; see build/qa/caravan-occlusion-
audit.md. That gap is resolved by CARAVAN_VISIBILITY.md without regenerating
the cart or hero artwork.
