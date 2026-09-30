# T53 — complete foliage silhouettes at walls

The owner's `canopy_clipping.webp` shows green rectangular bands cutting
through orange tree crowns. The cause was `_canopy_overhang`, not the wall
mass: it drew a repeated canopy tile at absolute z=20, over rooted scenery,
statues, banners and actors (z=0), with a hard straight top edge and hard
span ends. Wherever a crown crossed the band, the strip painted a rectangle
over it.

The wall foliage now sits at z=-2 (`Balance.WALL_CANOPY_Z`), above the wall
faces (-4) and post faces (-3), and below rooted scenery, backdrops and
actors. A local-coordinate alpha feather (`wall_canopy.gdshader`, 18 px,
`WALL_CANOPY_FEATHER`) fades its top and span ends; the bottom keeps the
painted silhouette. The strip draws at unit scale, exactly as before, over
the whole texture height. The doorway clearance and headroom placement stay
unchanged. No assets, colliders, network state, wall-mass shading, floor
lighting or camera bounds changed.

The P3.4 "foreground overhang" behavior (heads near the north wall passing
under the leaves) is retired; `POLISH_TASKS.md` P3.4 records why.

Review correction (round 1): the first pass also claimed the old
`minf(96, tex_h)` source crop cut off painted fringe, and it rescaled the
full 128-row texture to 96 px (`scale.y = 0.75`). That premise was false.
`canopy_forest.png` (512x128) has no alpha past row 79 (rows 76-79 are
already near zero, rows 80-127 are fully transparent), so the 96-row region
showed every painted row. The rescale only flattened every forest and hedge
band by 25% and dropped rows under the nearest filter. It is gone: the strip
is back at unit scale. The region now spans the whole texture height, which
shows the same pixels as the old 96-row region (the extra rows are
transparent) and cannot crop taller art later.

## Audit

- `game/scripts/wall_surface.gd`: mass z=-6, lane backdrop z=-12; neither
  overlays rooted props. Its shader discards the floor from the wall sprite
  only, not from other sprites.
- `game/scripts/game_world.gd`, `_canopy_overhang`: the north headroom clamp
  changes position, never the tree sprite's extent. The z=20 wall strip with
  hard edges was the offending rectangle.
- `game/scripts/game_world.gd`, `_add_obstacle`: trees, statues and banners
  use full static/animated visuals under a rooted z=0 body. Their geometry
  needs no change. Foliage wind deforms vertices without clipping alpha.
- `game/scripts/game_world.gd`, `_add_backdrop`: full texture on the z=0
  backdrop layer, so the wall foliage also sorts behind backdrop trees.
- `game/scripts/floor_dressing.gd`, `spawn_details`: tall civic dressing
  uses z=0; floor wear/debris uses -8/-9. `room_floor.gd` vignette uses -9,
  below the walls and tall props. Neither is responsible for the bands.

## Reproduction and output notes

Run from this lane through the machine lock:

```text
shot.bat polish --canopy-overlap --seed=53029 --timeout=240 --no-import
```

One engine session. The rig plants autumn trees at the north, west and east
walls of room 2, alongside a banner, statue and a tree built through the
backdrop factory. It captures the outgoing strip settings from parent
`9df77c2` first (z=20, 96-row region, unit scale, no feather), then restores
production settings and captures the same camera positions. No old-behavior
switch is added to the game. The game is paused only inside this offline
capture fixture, then restored. Prop placement, terrain, ambient tint,
camera (position, zoom, top limit) and pause loans are cleaned up on
assertion failure as well as success.

The north/west/east views use the normal room camera, which clamps at the
wall-mass lip, just below the strip's top edge. The added "top" view loans
the camera's top limit so the whole strip, its top edge and the crowns
crossing it are in frame, as in the owner's north-door screenshot. In that
view the rig also measures the rendered top edge: it slips a flat card
directly under the strips and reads the frame with a light and a dark card,
strips shown and hidden. Per pixel,
`1 - (shown_light - shown_dark) / (hidden_light - hidden_dark)` is the
strip's rendered opacity whatever sits behind it; pixels a crown fully covers
are skipped. The rig requires the opacity of rows 1-3 over that of the
opaque body rows to exceed 0.7 for the outgoing settings (the probe can see
a hard edge) and to stay under 0.4 for the fix (the feather renders).

The regression is `canopy_overlap` in `game/scripts/tests/test_wall_surface.gd`.
Its ordering bounds come from nodes the real factories build, not literals:
a probe tree (`_add_obstacle`) and a backdrop tree (`_add_backdrop`) are
planted and freed inside the check, and the wall and post faces are read
from the room's built walls (`zone_wall_sprites`, `zone_posts`). Each strip's
effective z must sit strictly below both crowns and strictly above every
face. It also requires unit scale, the whole source height, the feather
shader and feather uniforms matched to the drawn span. It runs in the
stacked-room fixture (quick tier via `test_ch1`) and in the live room checks.
The rig's negative controls put one strip back at z=20 and squash one to
0.75, and both must fail the check.

Retained 1280x720 captures (all visually inspected):

| View | Outgoing settings | Fixed |
| --- | --- | --- |
| Whole strip (top limit loaned) | [Before](qa/t53/canopy_top_before.png) | [After](qa/t53/canopy_top_after.png) |
| North wall | [Before](qa/t53/canopy_north_before.png) | [After](qa/t53/canopy_north_after.png) |
| West corner | [Before](qa/t53/canopy_west_before.png) | [After](qa/t53/canopy_west_after.png) |
| East corner | [Before](qa/t53/canopy_east_before.png) | [After](qa/t53/canopy_east_after.png) |

The top pair is the owner's composition: before, the band has a hard,
ruler-straight top edge and a hard doorway end, and paints over the autumn
crown, the statue, the twisted trunk and the (oversized, fixture-only)
banner. After, the band fades in at its top and doorway ends, and the crown,
statue, trunk and banner all stand in front of it. In the east pair the
fringe hangs as deep as before (unit scale). [Masonry control](qa/t53/canopy_masonry_control.png)
retains the dark wall face against the brighter floor without forest
dressing.

Rig validation after the review fixes (2026-09-29, locked run, 56 s scene
time): `CANOPY OVERLAP PASS`, `RIG DONE: polish shots=9 exit=0`, runner
verdict `RIG DONE ... exit=0`. Negative controls rejected: `wall foliage
overlays rooted canopies` and `wall foliage is squashed off its painted
scale`. Rendered top edge: before rows 1-3 opacity 0.923 vs body 0.929
(ratio 0.994, hard); after 0.085 vs 0.840 (ratio 0.101, feathered), from
661-996 readable pixels per row set. The live room 2/17 wall checks, the
stacked-room fixture, pilasters, lane backdrop and vignette checks passed.
The runner accepted only its established renderer shutdown diagnostics.

Limits: this is a controlled composition using production factories, not a
replay of the owner's save. No full suite, multiplayer session or mobile
renderer run. The diagnostic banner uses the generic obstacle factory's
legacy scale and is oversized; it is fixture-only and unchanged across each
pair. Shader wind can advance between frames even while gameplay is paused;
placements and camera anchors remain fixed.
