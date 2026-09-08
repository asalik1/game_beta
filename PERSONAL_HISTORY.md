# Personal history

A real two-peer ENet check reproduced two linked problems. A new hero joining
a veteran host inherited the host's completed chapter and missed first-clear
spoils. A veteran joining a new host lost their own completion and received the
package again. The same snapshot replaced personal city choices; new kept
promises then disappeared on the guest's solo resume. The home world's map and
ordinary story correctly stayed home throughout.

Each character now stores `history_flags`: opening choices, completed chapters,
city choices, kept promises, tutorial history and first-clear payment markers.
The existing durable flag tables live in `character_history.gd`, shared by save
handling and network routing. Unscoped quests keep their acceptance, payment
and pledge markers with their durable steps, preventing restored steps from
paying again. Their live party routing remains unchanged.

The host's snapshot carries world flags. It omits personal history and per-head
cache, hidden-reveal and shrine claims; the receiver applies the same filter.
Guests restore their own history before world construction, so a personal
choice that replaces a city NPC builds the correct person. Full character
application remains at its existing post-build point. Solo load also restores
the reconciled flags before building and applying the rest of the save.

Character-only home saves preserve the original world exactly. On resume,
explicit personal history overrides old copies in that world. Reconciliation
does not emit flag RPCs, pay quests or run gate callbacks mid-save. Ordinary
chapter quests, run flags, room claims, positions and geometry do not travel.
The six rescued creatures retain their separate canonical `rescued_pets` field.

First-clear rewards reserve a durable `first_clear_paid_<chapter>` marker before
paying. Repeated deferred callbacks, or returning after a disconnect before the
later victory message, cannot award the package again. Existing completed
chapters also remain ineligible. Reward contents and amounts are unchanged.

For older files, an absent history field lifts personal flags from that save's
own home world. The hero's saved `clear_<chapter>` achievements also recover
completion credit lost by the old guest-save behavior. Account chapter unlocks
are not used to infer this hero's accomplishments. An explicit empty history
remains authoritative; malformed containers are discarded. Already lost city
choices cannot be reconstructed without evidence.

Validation:

- Quick/full contracts use an isolated real player and restore slot96 plus its
  sidecars on every result. They cover migration without input mutation, host
  exclusion, exact home preservation, explicit empty/malformed records, private
  cache filtering, durable quest payment pairing, original reward packages,
  repeated claims and a save/reapply before victory.
- `shot.bat personal_history --timeout=260` uses real loopback ENet snapshots,
  first-clear and victory RPCs, home save/resume, first-timer/veteran pairings,
  reconnects, actual city NPC construction, touch reference and legacy saves.
- Desktop and mobile import/compile/quick, full desktop regression, calibrated
  live capture inspection, scoped mobile parity and source/Codex preflight.

No native Android/iOS hardware is part of this pass's evidence.

The network build is **0.3.11**. Both peers must update: older clients cannot
restore the personal history omitted from the corrected host snapshot. The
existing version handshake rejects mixed builds before joining.

Final validation: desktop 186-script compile, 112 quick
checks and 192 full checks. Mobile editor import,
186-script compile and 112 quick checks. All
strict PASS without script errors. Desktop Forward+ and mobile Compatibility
live rigs each passed seven captures and the actual loopback ENet contracts:
one first-timer package, zero duplicate/reconnect/veteran packages, real victory
autosave, exact home-world preservation, guest-specific city NPC and legacy
completion recovery. Eleven frozen source files match their mobile mirrors,
with three independent UID pairs. Source preflight has zero failures and
12 known structural-number warnings; the engine Codex data gate passes.


## Follow-up: final-boss settlement order

Reviewing the real final-boss path exposed a regression introduced by the
completed-chapter reward guard above: solo/host completion was marked before
calling the guard, suppressing legitimate first-clear spoils. Isolated helper
tests and the guest ENet flow both paid before completion and missed this.
`shot.bat first_conquest --timeout=230 --diagnostic` reproduced it through the
real boss factory and death callback: completed=true, paid=false, spoils=0.

The solo/host final-boss path now pays before recording completion. The durable
paid reservation and legacy-completion guard remain intact. No rewards, prices
or network message shapes changed. `shot.bat first_conquest --timeout=230`
checks real boss death, exactly one first-clear package, replay suppression,
the solo cinematic/results handoff and the later chapter's gear-plus-gem mail.
The original real ENet personal-history rig is rerun to cover guests/reconnects.
Follow-up validated.

Final validation: desktop 188-script compile, 113 quick
checks and 193 full checks. Mobile editor import,
188-script compile and 113 quick checks. All
strict PASS without script errors. Desktop Forward+ and mobile Compatibility
each pass twelve companion-menu captures and five real final-boss captures.
The original seven-capture actual ENet history/reconnect rig passes again.
Twelve frozen source files match their mobile mirrors, with four independent
UID pairs. Source preflight has zero failures and 12 known structural warnings;
the engine Codex data gate passes. No new art, hardware QA or commits.
