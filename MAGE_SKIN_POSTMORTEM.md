# Void Weaver Mage FX Postmortem

Status: **accepted Void Weaver visual-quality pass** on 2026-07-19.
Reference implementation commit: `a8caf18` (`feat: complete Void Weaver and
enforce skin parity`). Crystal Archmage is present only as an implementation
foundation and remains a separate future review; this sign-off applies to Void
Weaver.

This document records what the Mage pass taught us so later skins can gain
distinct visual identities without changing combat behavior. It supplements
`SKIN_ANIMATION_BIBLE.md` and `ARCHER_SKIN_POSTMORTEM.md`.

## The central lesson

A cosmetic effect has two simultaneous contracts:

1. It must convincingly express the skin's fantasy.
2. It must tell the truth about the unchanged base ability.

Void Weaver only became successful when both were treated as engineering
requirements. A beautiful eye placed at a different muzzle accidentally gave
Firebolt different range. A circular telegraph paired with an oval eruption
still lied about the hitbox. A thread cocoon that hid the player after Blink
had already finished made movement appear delayed. Presentation is not balance,
but misleading presentation can still create a real advantage or disadvantage.

## The accepted visual language

Void Weaver is not a purple version of Mage. The recurring vocabulary is:

- living eyes that form, watch, fire and close;
- sharp violet needles rather than fireballs;
- taut thread routes rather than smoke trails;
- stitched rings that close and violently unravel;
- cocoons that wrap, empty, reform and unwind; and
- vertical thread fields that rip upward from chosen ground.

Each ability uses the same nouns but performs a different verb. Firebolt
**watches and fires**. Nova **stitches and tears**. Blink **wraps and reveals**.
The ult **condemns and rips open** a circular patch of ground.

## What finally worked

### Firebolt: visual origin without gameplay drift

- The eye chooses a random clear pocket near the caster and avoids other live
  eyes, giving repeated casts an organic constellation rather than a fixed
  muzzle ornament.
- The real projectile still spawns at the exact base Firebolt position with the
  exact base velocity, lifetime, collision, targeting and riders.
- Only the projectile's visual container begins at the eye. A render offset
  converges onto the unchanged physics path over a short presentation window.
- The tiny needle launches from the eye's actual centre and records a strong
  violet trail along its visible route.
- Impact, direct projectile deletion and a final lifetime fuse all dismiss the
  eye. The fuse stores an integer instance id rather than capturing the eye
  object, avoiding callbacks that retain or reference freed nodes.

This is the reusable rule: when a skin wants a projectile to appear to originate
somewhere new, move the rendered projectile—not the gameplay projectile.

### Frost Nova: a real sequence can remain mechanically immediate

The accepted Nova already had the right structure: points stitch clockwise,
the final knot closes, then the ring unravels outward. Its animation continues
after cast, while the shared Nova gameplay resolves on the original base frame.
The visual sequence is allowed to be richer; the hit cannot move with it.

### Blink: disappearance must respect live movement

- Gameplay relocation remains the base `_dash_strike` and happens immediately.
- A copy at the departure point gives the threads something to wrap after the
  real body has moved.
- The destination cocoon begins opening quickly and the real body becomes
  visible as that opening begins, not after the entire sheet finishes.
- Remaining unwrap frames play over the visible character as an overlay.

The failed version hid the real sprite for roughly a third of a second. Input
was already live, so a walking Mage became an invisible moving body while the
cocoon stayed behind. Cosmetic disappearance windows must end when control and
movement resume, even if decorative aftermath continues.

### Ult: represent a top-down circle as depth, not one side-on wall

The purple telegraph is the literal damage radius. The procedural source has a
32px radius and is uniformly scaled by `gameplay_radius / 32`, so its rim is the
actual query boundary for base and radius-modified variants.

The eruption required two further corrections:

- **Anchor visible art, not the texture cell.** The 256px sheet contains
  transparent padding. Its dense woven root line is around source row 210.
  Anchoring that row to the target's ground position makes threads emerge from
  beneath feet; anchoring the cell edge made them float above the target.
- **Give a top-down circle depth.** One side-on sheet paints a horizontal wall
  through only one slice of the field. Five copies now sit on back-to-front
  circular chords. Each chord's width is derived from
  `sqrt(1 - depth_fraction²)`, so the back/front bands narrow and the centre
  band spans the full diameter.

The first five-band render was technically honest but visually unusable: five
full-height, nearly opaque sheets became one giant curtain. The accepted pass
keeps the five ground chords while shortening their vertical scale and grading
opacity from faint outer bands to a stronger centre. Coverage and readability
must be solved together.

## Parity problems discovered during the Mage audit

The Mage work exposed older skin-only behavior in Archer and Assassin. They
were fixed in the same parity commit because the rule must be global:

- Voidwraith Tumble awaited portal animation before relocating, adding a
  skin-only movement delay. It now relocates synchronously and lets portals
  finish asynchronously.
- Voidwraith Arrow Storm replaced base target selection with round-robin
  targeting and delayed damage until a tentacle contact frame. It now preserves
  the base-selected target and base damage tick; tentacles are presentation.
- Frostfall's primary lance and Voidwraith's tentacle contact were normalized
  to the base Arrow Storm's 0.11-second visual fall clock.
- Golden Ronin added a 0.12-second pause before the execution's final true hit.
  The iai spectacle now lands on the shared base/Phantom execution frame.
- Phantom/Void trail ribbons could submit self-crossing or zero-area quads.
  Explicit triangles keep the cosmetic trail reliable without touching its
  projectile.

The lesson is that a skin branch containing `await`, a different target query,
or a damage callback should be considered suspect until proven cosmetic.

## Approaches that failed, and why

### Moving the projectile to the eye

This made the screenshot look correct but changed the real starting position,
travel distance and effective range. Visual-origin problems need a render-space
solution.

### Capturing eye nodes in long-lived timers

Normal impact cleanup freed the eye before the safety timer fired, producing
freed-lambda-capture warnings. Long fuses should bind stable ids and resolve the
node only when the callback runs.

### Matching the telegraph numerically but not perceptually

The telegraph itself was a perfect circle, but the eruption asset still carried
an oval-looking visual mass. Players judge the combined silhouette, not the
scale value in code. Every large layer must support the same area language.

### Anchoring transparent frame bounds

Sprite-sheet dimensions are not meaningful attachment points. A bottom-padded
frame can be mathematically centred and still visibly float. Measure the opaque
root, muzzle or foot row in the authored pixels and anchor that feature.

### One sheet for a top-down area

A vertical thread wall can describe height or width, but not circular ground
depth. Repeating the sheet across mathematically sized chords turned a flat
illustration into a field while reusing the authored animation.

### Solving coverage with unrestrained duplication

Five full-strength copies covered the circle but obscured the fight. Density,
height, alpha and layer order must be tuned after coverage is correct.

### Letting animation completion control mechanics

Awaiting a skin animation is unsafe unless the base ability waits for the exact
same duration. Gameplay should resolve on the shared clock; visual sequences
may continue independently.

## Reusable implementation rules

1. **Define the immutable gameplay envelope first.** Record origin, range,
   hitbox, target selection, damage ticks, cast/release/recovery timing,
   projectile physics and cooldown before adding skin branches.
2. **Keep skin branches downstream of mechanics.** Select targets and resolve
   hits once; let the skin decide only how those events are shown.
3. **Use render offsets for alternate origins.** Never move a projectile's
   physics root to satisfy a muzzle, eye, familiar or floating weapon.
4. **Treat every `await` in skin code as a parity risk.** Prefer timers, tweens
   and callbacks for asynchronous spectacle.
5. **Match the whole visual footprint to the hitbox.** A correct rim is not
   enough if another dominant layer implies a different shape.
6. **Derive visual size from gameplay size.** Radius variants must expand the
   telegraph and authored field from the same radius value.
7. **Anchor semantic pixels.** Document source rows/columns for roots, feet,
   eyes, muzzles and pivots instead of guessing from canvas dimensions.
8. **Translate side-view sheets into top-down space deliberately.** Use depth
   bands, circular chords, layered rings or independent actors when one flat
   sheet cannot occupy an area honestly.
9. **Design cleanup ownership at spawn time.** Every persistent eye, trail,
   cocoon or field needs normal completion, forced deletion and room-reset
   paths.
10. **Keep effect completion independent of player visibility.** A character
    can become visible before an arrival overlay has finished.
11. **Test mechanics directly and visuals through captures.** Neither replaces
    the other.
12. **Sync the accepted implementation to mobile.** Assets, code and regression
    checks must match the desktop source of truth.

## Regression strategy that proved useful

Runtime QA now checks facts screenshots cannot:

- base and Void Firebolt physics roots, velocity, lifetime, collision, riders
  and damage multiplier are identical;
- the rendered Void bullet begins at the eye centre;
- eyes clean up after projectile exit and repeated missed casts;
- the Mage telegraph reaches the exact circular gameplay radius;
- Archer skin projectiles preserve base physics;
- Voidwraith Tumble relocates synchronously by the base distance;
- Voidwraith storm damage lands on the base tick; and
- all Assassin executions deliver equal damage by the same final-hit time.

Shot captures then verify the remaining truths:

- the eye actually reads as the muzzle;
- Blink never leaves a controllable invisible body;
- the circle looks circular as a combined effect;
- thread roots appear beneath targets;
- threads occupy the full back-to-front field; and
- combatants remain readable through the spectacle.

The numerical test passed before the ult looked correct. That is expected:
automated parity tests protect fairness, while gameplay-scale captures protect
visual honesty.

## Acceptance checklist for future area effects

- The visible boundary is the real hit boundary.
- Radius-modified variants scale from the same gameplay radius.
- The dominant interior effect occupies the same shape the boundary promises.
- Ground effects are anchored to feet/ground, not sprite-centre guesses.
- A top-down circle has visible depth, not only a single horizontal wall.
- Foreground pieces may cross enemies, but the whole field does not erase them.
- Damage and target selection occur on the base timeline.
- Decorative animation can continue without delaying recovery or input.
- Persistent actors clean up on impact, timeout, deletion and room reset.
- Repeated casts do not leak nodes or leave orphaned eyes/marks.
- Bright and dark terrain captures both pass.
- Desktop and mobile behavior match.

The clearest summary is: **the skin may invent a new explanation for the
ability, but it may not invent a new ability—and every pixel must tell the truth
about the one that already exists.**
