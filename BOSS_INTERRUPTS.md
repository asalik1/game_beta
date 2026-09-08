# Crownless — Signature interrupts

Implemented on `codex/crownless-wayfinder`, starting from the interrupt-window
proposal in `PROPOSALS/COMBAT_LANES.md`. This pass changes the main combat loop:
save a burst for the cast, approach for stronger pressure, or keep moving and
answer the normal dodge mechanic.

## The six casts

| Boss | Cast | What a break prevents |
|---|---|---|
| Morwen | Blight Rain | The whole four-patch rain |
| Vargoth | Blade Storm | The entire chasing sword sequence |
| Choirmother | Hymn of Hunger | Both the marked strike and her 2% heal |
| Vess | The Silence | The shelter exam and its enraged decoy |
| Sleepkeeper | Frost Hymnal | Three strikes and their slowing patches |
| Gardener | Vine Lash | The root and closing ring |

Amber body brackets identify the caster. The broad HUD bar fills with damage;
the thin white fuse empties toward release. Breaking a cast turns the display
mint and opens an attack opportunity. The same abilities work on keyboard,
controller and touch; no extra interrupt button or item is required.

## Current tuning

- Morwen gives 2.2 seconds to teach the read; the other casts give 1.8 seconds.
- Pressure target is 6% of the boss's maximum health after party scaling.
- Damage from within 190 world units builds 1.5x pressure; other direct hits 1x.
- Periodic damage contributes 0.4x, independent of the source's distance.
- A break stops the boss's decisions for 0.7 seconds and increases damage
  received by 25% for 2.5 seconds. Ordinary boss CC immunity remains.
- The exposure timer is separate from existing class debuffs such as Death Mark.
  Only this new multiplier expires with the break window.
- A failed interrupt releases the original ability with its original ground
  warning. Other attacks already in flight keep their normal behavior.

## Implementation and lifecycle

`boss_cast.gd` owns the clock, pressure, exposure and validated snapshot.
`Boss` commits the ability before authoring its effects. The physics clock owns
release, exactly once; breaking or canceling removes that commitment. No queued
rain, heal or hazard needs to be undone. Reset/death cancels the state; unoccupied
rooms and a party with no standing player also cancel. Solo pause and hit-stop
freeze the clock. Online menus retain the world's normal live simulation.

Casting poses hold through the windup instead of snapping back early on long
fuses. Vargoth's released multi-sword sequence additionally checks a fight generation
after each await; a reset cannot wake an old sequence. Its awaits now pause with
the fight. Combat announcements wait while the cast readout needs the HUD space.
The Codex includes the mechanic in Combat field notes and each affected boss's
Mechanics & Tells fold.

Damage accounting uses the HP actually removed after mitigation and requires
an attributed player. The host counts party damage through the existing hit
funnel. Guest mirrors receive state and animate it; they never author casts or
breaks. The reliable state message is capped at 10 Hz plus transitions, and the
spawn snapshot includes active casts for late joiners. Network version: 0.3.6.

## Validation

- Quick desktop suite passed with the new contract section.
- Nine rendered captures cover windup, pressure, a break, released Blade Storm,
  the healing hymn, three later bosses and touch controls. Reviewed in-engine.
- The single-engine ENet fixture checks production start/progress/break/reset
  messages, a late-join spawn, guest damage breaking a host cast, and applying
  the exposed multiplier exactly once to a guest's raw hit.
- Pause freezes both the cast and release. Reset cancels the remaining swords
  of an already released Blade Storm. Interrupting the healing hymn prevents
  its heal; allowing it to complete grants the original 2% heal.
- Seeded L8, D-gear, no-talent Morwen probes exercise every class's real kit.
  With abilities ready, all six can break the cast; basic-only samples fall
  short. These are reachability checks, not a statistical balance claim.
  The paladin burst includes Conviction into Retribution; omitting the stance
  was an invalid burst probe and correctly failed.
- The deadline comparison tolerates floating-point roundoff from actual HP
  subtraction: an exact-threshold hit cannot leave an invisible sliver.

Final validation: desktop full suite passed all 179 checks. The mobile mirror
passed editor import, compilation of 152 scripts, and all 98 quick-suite checks.
All 14 mirrored source paths match. Preflight reports zero failures and six
existing balance-literal warnings; no new warnings were introduced.

Useful local evidence: `build/qa/boss-cast-trials.log` (five class pairs),
`boss-cast-final-visual2.log` (paladin pair, nine captures and full wire check).
Final suite logs: `build/qa/boss-cast-full-verified.log` and
`build/qa/boss-cast-mobile-final.log`.
Earlier numbered QA attempts record issues caught and fixed during development.
No physical mobile-device build, wide-area latency test or full party soak is
claimed by these checks.
