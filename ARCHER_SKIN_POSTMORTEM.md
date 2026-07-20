# Archer Skin FX Postmortem

Status: **accepted visual-quality pass** on 2026-07-19. Frostfall Ranger and
Voidwraith now meet the same presentation bar as Golden Ronin and Phantom.
Reference implementation commit: `2fdb78d` (`Finish Archer skins and shared FX
foundation`).

This document records what the Archer pass taught us so the remaining class
skins do not repeat the same mistakes. It supplements `SKIN_ANIMATION_BIBLE.md`;
the bible remains the authority for the overall tier contract and each skin's
fantasy.

## The central lesson

A skin becomes convincing when its fantasy is expressed as a chain of motion,
not as a collection of recoloured effects.

The accepted Archer skins each have a small visual vocabulary that recurs
through the entire kit:

- **Frostfall Ranger:** complete radial snowflakes, faceted ice projectiles,
  falling ice, rime blooms and cold sky light.
- **Voidwraith:** watching eyes, portals, disappearance/reappearance, barbed
  eye-arrows, persistent violet trails and independently hunting tentacles.

Every action uses the same vocabulary but performs a different verb. That is
why the skins feel coherent without duplicating the same effect on every key.

## What finally worked

### Frostfall Ranger

- The bow cast uses one complete, padded radial snowflake centred on the bow.
  It changes scale and opacity in place. It is not a strip sliding across the
  character.
- Tumble leaves the same readable snowflake at the departure point while the
  Ranger moves normally. The effect marks where she *was*; it does not travel
  with her.
- Direction-specific sprite anchor corrections prevent the character from
  shifting at the end of an otherwise correct dash.
- Frost arrows have their own slim ice silhouette and leave a small shrinking
  snowflake on impact. The motif therefore has cast, flight and contact beats.
- Arrow Storm became a blizzard rather than a blue version of the base volley:
  a sky-blue ground field establishes the affected circle, faint light rises
  from it, and dense snowflakes plus ice lances fall through the field.
- Decorative flakes and lances are more numerous than damage events. Visual
  density is independent of the unchanged gameplay tick schedule.

### Voidwraith

- The core projectile is an eye-bearing purple arrowhead with a strong trailing
  streak. It has its own silhouette rather than borrowing another class's bolt
  or recolouring the base arrow.
- Tumble is a two-gate disappearance: a portal and eye open at the origin, the
  character vanishes during travel, and a second portal returns her at the
  destination. The unused middle dash poses are intentionally hidden.
- Arrow Storm became a hunting portal. A dark circular portal and one large eye
  establish the area, then **eight separate tentacles arranged in a circle**
  emerge and take turns whipping at targets in range.
- Each tentacle is a stateful object with idle and attack art. It aims and
  animates independently instead of being painted into one static ult image.
- Tentacle roots remain fixed to the portal while the free ends attack. The
  rotation/pivot is based on the root of the authored sprite and accounts for
  display scale.
- The portal and eye render below enemies; the attacking tentacles render above
  them. This preserves target readability while still allowing attacks to cross
  silhouettes.
- The eye is large enough to dominate the portal but small enough to leave a
  dark annulus. Tentacle roots disappear naturally into that darkness instead
  of sitting visibly on pale sclera.

## Approaches that failed, and why

### Recolour plus emblem

The first Frostfall ult was still the base arrow storm with a frost colour and
an emblem above the Archer. It identified the skin but did not change the event.
An elite or mythic signature ability needs a different action silhouette and a
different sequence, not just an identifier.

### Treating a strip as a single effect

The early bow/dash snowflake exposed a horizontal sprite strip. Scaling or
fading the whole texture made the effect look stretched, cropped and as if it
were translating sideways. For a single cast accent, use one complete image
with transparent padding. Use a sheet only when runtime code deliberately
selects its frames.

### A monolithic tentacle painting

A large portal image containing several tentacles looked impressive while
still, but the actual attacks came from unrelated small appendages. The large
tentacles did not participate, so the scene had no causal connection between
threat and hit. Breaking the creature into eight independently animated limbs
made every visible strike belong to the ult.

### Rotating around the sprite centre

Pointing a whole tentacle sprite at a target moved its base away from the
portal. The limb looked detached even when its tip reached the correct enemy.
Rooted effects must treat the attachment point as the invariant. Compute and
preserve the root pivot first; animate the free end second.

### Letting foreground spectacle obscure gameplay

Drawing the entire portal and eye above mobs covered enemies and bosses. Large
area effects need intentional compositing: environmental field below actors,
interactive limbs/projectiles above actors, and restrained opacity wherever
the player must still read a target.

### Solving root seams with more art on top

An oversized pale eye made the tentacle stems more obvious, not less. Reducing
the eye and exposing the portal's dark interior created a natural socket for
the roots. When an attachment seam is visible, first inspect the surrounding
negative space and layer order before adding another overlay.

### Trail dimensions without enough value contrast

Longer trails still looked faint while their effective opacity was too low.
Trail tuning has four coupled variables: projectile size, trail length, trail
width and opacity. Judge them together at gameplay zoom and against both light
and dark terrain.

### Duplicated projectile identities

Borrowing a good projectile from another class may improve one screenshot but
weakens both skins. A shared helper is fine; a shared finished silhouette is
not. Mage fire, Hellfire Warlock fire and Voidwraith arrows must each remain
recognizable without relying on colour alone.

## Reusable production rules

1. **Write the visual sentence first.** State what the skin is doing to the
   world or target. Every effect must serve that sentence.
2. **Give every ability a verb.** Open, freeze, fracture, brand, orbit, stitch,
   conduct and condemn are useful. "Glow" and "recolour" are not complete
   verbs.
3. **Build anticipation, action and aftermath.** Even a short projectile should
   have a cast read, a flight identity and a contact response.
4. **Reuse motifs, not finished attacks.** Shared runtime helpers are desirable;
   copied class assets and plain recolours are not.
5. **Prefer stateful pieces over static tableaux.** If parts of an effect are
   supposed to act, make those parts independent objects or real animation
   frames.
6. **Separate presentation from mechanics.** Add decorative density freely,
   but keep damage count, timing, targeting, hitboxes and cooldowns unchanged.
7. **Design the layer stack.** Decide which pieces belong below the ground
   target, below actors, above actors and above the whole scene.
8. **Author for the pivot.** Transparent padding, root location, muzzle anchor
   and directional sprite offsets are part of the asset contract.
9. **Tune at gameplay scale.** Full-resolution art inspection cannot reveal
   cropped edges, disappearing trails, target occlusion or a one-pixel anchor
   jump.
10. **Keep base and skin variants complete.** New shared ability machinery must
    still select a deliberate visual for base and every supported skin. A skin
    pass cannot silently make the base version generic or make two skins share
    the same final asset.
11. **Keep desktop and mobile mirrored.** `game/` remains the source of truth;
    the accepted implementation and assets must be synced to `mobile/game/`
    and validated there.

## Review loop that was effective

The pass improved fastest when each review isolated one visible failure:

1. Capture the effect in a normal combat scene at the shipped camera scale.
2. Name the failure literally: detached root, cropped edge, faint trail,
   obscured enemy, duplicate projectile, sliding cast mark or anchor jump.
3. Decide whether the cause is asset geometry, animation/state logic, layer
   order or tuning. Do not regenerate art when the real problem is a pivot.
4. Change one visual relationship and recapture it.
5. Recheck all directions and all variants that share the helper.
6. Confirm that gameplay timing and hit application did not change.
7. Sync the accepted result to mobile, then run compile, quick and full gates in
   the repository's required order.

## Acceptance checklist for the remaining classes

Before calling another elite/mythic pair complete, verify all of the following:

- The base class and every skin use intentional, distinguishable assets.
- No skin projectile is a plain recolour or copy of another class's projectile.
- Core attack, movement skill, secondary abilities and ult all express the same
  fantasy through different motions.
- The signature ability tells a readable mini-story rather than presenting one
  static emblem.
- Cast, travel/action, impact and lingering beats are present where appropriate.
- Animated pieces actually cause or visually correspond to gameplay impacts.
- Ground fields match the real hit area and do not hide enemies.
- Rooted, orbiting and muzzle effects remain attached in all eight directions.
- Trails remain visible over both bright and dark terrain at gameplay zoom.
- Sprite sheets are framed intentionally; single effects use padded single
  images.
- Decorative particles do not add damage events or alter balance.
- Base and skin-specific colour variants still work after shared-helper changes.
- Desktop and mobile implementations/assets match and both pass validation.

The most important bar is simple: if the skin name and colour were hidden, a
player should still be able to identify the fantasy from how the abilities move.
