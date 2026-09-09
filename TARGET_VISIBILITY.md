# Target visibility

Solid scenery can cover a correctly selected enemy. The actual Darkwood Road
capture showed a Wildfang Raider behind a log: its covering autumn tree faded
correctly, but the opaque log still hid the body and its attack poses.

The current nearby target now gains a thin amber silhouette only where a solid
prop covers its art. Trees retain their existing fade. Solid props stay opaque;
their collisions and attack blocking are unchanged. The copy uses the enemy's
actual texture, frames, pose, anchor, flips and transform. Edge width is measured
in world pixels, so a higher-resolution master cannot make it disappear.

Settings → Combat & comfort calls the existing toggle **Target visibility**.
The saved `combat_foliage` key is retained; existing preferences apply. The
Codex's combat field notes explain the feature.

Coverage uses the existing alpha probes and y-sort metadata at the foliage
sample interval. Sprite frames track every frame. Target changes, loss, death,
untargetability, hidden sprites, range and the disabled setting remove copies.
World repaint and HUD teardown release references and world-owned children.
Hero and target copies share prop masks safely: a departing owner cannot remove
another's mask, and queued children cannot leave the last mask stuck on.

Caravans now register their existing opaque art with the same system. Both
hero and target readers restrict scenery to their current world; another
game's scenery, retired worlds and foreign targets cannot acquire copies.
See CARAVAN_VISIBILITY.md for the reproduction and follow-up validation.

Validation:

- A real log and raider fixture checks opaque cover, animated copy properties,
  resolution-independent width, eligible targets, shared masks in both departure
  orders, same-frame deferred deletion, repaint and teardown. Borrowed state is
  restored on every result. It runs in both quick and full suites.
- `shot.bat target_cover --timeout=190` checks actual Darkwood geometry and
  captures the disabled setting, enabled silhouette, three real attack poses,
  lost target, touch combat and touch settings. It also deletes the live target
  and checks that no silhouette remains.
- Desktop Forward+ and mirrored mobile Compatibility captures are inspected at
  normal gameplay scale using the calibrated shared ShotRig.

No art was changed. Native Android/iOS hardware is outside this pass's evidence.

Final validation: desktop 184-script compile, 111 quick
checks and 191 full checks. Mobile editor import,
184-script compile and 111 quick checks. All
strict PASS without script errors. Desktop Forward+ and mobile Compatibility
live rigs each passed eight captures, including real action frames and freed
target cleanup. All nine frozen source files match their mobile mirrors, with
two independently generated UID pairs. Source preflight has zero failures and
12 known structural-number warnings; the engine Codex data gate passes.

The first visual draft used a fixed texture-pixel edge, which became too fine
on larger masters. The final edge is one world pixel. The live fixture also
checks foliage conditionally: seeded scenery can place a canopy beside the
target, where it correctly stays opaque. The actual covering log is mandatory.
