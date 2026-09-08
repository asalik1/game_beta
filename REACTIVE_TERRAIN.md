# Reactive terrain — 2026-09-07

The Dynamic World roadmap's reactive-prop lane now changes ordinary combat
rooms. This pass prioritizes a reusable combat/exploration verb over another
isolated activity: draw a pack toward a marked object, prime it, and get clear.

## In play

- **Ember Cask:** a red-X powder barrel. Its blast deals 32% of each nearby
  ordinary monster's maximum health before existing enemy damage modifiers.
- **Rimeheart:** a diamond-marked blue crystal. It deals 12% and slows monsters
  to 45% speed for three seconds.
- Interact within 75 units, land a normal melee arc, or hit one with a real
  projectile. Hostile projectiles can prime them too. Arbitrary area spells
  do not implicitly activate props; all classes can use the interaction.
- Both have a **1.5-second fuse and a 220-unit blast radius**. A fixed boundary
  and filling fuse show the danger. Nearby labels name the object; approaching
  shows the existing keyboard/controller/touch action and a radius preview.
- Heroes inside either blast take 18% max-health raw magic damage, with their
  normal mitigation and defenses. Rimehearts also chill heroes. These are
  positioning tools with friendly fire, not free damage buttons.
- A blast primes other marked objects within range. Every link gets a full
  fuse. Used objects leave a ground scar and stay spent across scenery rebuilds
  and save/load for the current chapter visit.

Up to two objects populate eligible rooms, with deterministic positions biased
toward actual enemy packs. Placement respects the room's reserved river, hazard,
building and corner regions and existing prop spacing. Ice, crystal and storm
biomes use Rimehearts; other supported combat biomes use Ember Casks. Safe rooms,
boss arenas, terrain galleries, competitive/weekly runs and endgame ladders are
excluded. No additional gold, XP, drops, skills or inventory resources are added.
Bosses are immune to these blasts, including when brought near an object.

## Presentation and implementation

The two original painted sprites are one transparent atlas, generated with the
built-in image tool. Their red X and diamond rune distinguish them from ordinary
scenery. Controlled unshaded rendering keeps the marks and warnings readable in
dark terrain. The props stay planted: no bobbing collision bodies or idle strobes.
The full source prompt is in `art_src/reactive_terrain_2026-09-07/README.md`.

`scripts/reactive_terrain.gd` owns placement, interaction, the three-state
intact/primed/spent lifecycle and effects. Tuning lives in `balance.gd`.
Melee activation uses the existing contact circle; real projectile impacts use
the existing static-body collision branch. Cosmetic network shots cannot prime.
Spent state is a normal saved world flag reserved before any effects can run.
World teardown removes pending fuses with the scenery; a deserted encounter
cancels its pending blast. Pause and impact pauses freeze the fuse in solo play.

Network protocol **0.3.7** adds a guest request and a host state event. Requests
carry an object key and interaction mode; the host resolves the player, room,
distance and live object. Damage is host-authored and player hits/statuses use
the existing owner-application network paths. A join-ready refresh corrects any
consumption that happened while the guest built its world and restores still-live
fuses. Settled join snapshots are quiet. This does not change the enemy packet
format or the save schema.

## QA

The contract suite checks invalid snapshots, single-use reservation, state order,
repeated snapshot timing, spent rebuilds and boss-room exclusion. The live rig
uses actual melee contact and projectile physics, checks pack damage and radius,
frost status, damage to the player, chain deadlines, pause and touch interaction.
Its two ENet peers share one engine and exercise the production guest request,
host state receiver, mirror authority and a late-join active fuse.

Desktop full suite: **180 checks passed** (`build/qa/reactive-full.log`).
Eight final in-engine captures were reviewed from `build/qa/reactive-render.log`;
the same run passed the live combat and production ENet checks. The atlas has
real alpha, correct two-cell geometry and generated mipmaps; all 15 source/mobile
paths match. Preflight reports **0 failures, 7 warnings**: six existing warnings
and one for reusing the existing melee contact-circle ratio (0.55) in the prop
hit test. No melee reach or hit shape was retuned.

Mobile passed editor import, compilation of **154 scripts**, and **99 quick-suite
checks** (`build/qa/reactive-mobile-final.log`).
No physical-device or wide-area-network performance claim is made by this pass.

Run `shot.bat reactive_terrain --timeout=210` for the muted in-engine rig.
