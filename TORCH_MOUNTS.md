# Door pillar grounding

The shared doorway renderer now places freestanding stone torch pillars on the floor, clear of wall caps/faces and the open road lane. This addresses the owner's unsupported wall-edge pillars on all four doorway orientations, including inset rooms. The correction is natively validated on both source/render paths in chapters 1 and 3. Desktop and mobile suites pass; full repository preflight passed without findings.

The existing four-frame `torch_pillar_anim.png` remains unchanged: 736x296 pixels, four 184x296 frames, rendered 64 world pixels high. The helper measures the union of the painted lower plinth across those frames and caches the result. Flame motion cannot move the anchor. No generated or edited art is part of this change.

`game/scripts/door_torch_mount.gd` owns the measured placement; `Game._door_torches()` delegates to it. Existing size and pair spacing, plus the 6px ground clearance and lower-quarter footprint band, live in `Balance`. For the current strip, the painted plinth is about 39.784px wide and 16px deep. Pair centers retain the existing 98px offset from the 144px doorway lane.

| Side | Old painted front foot | Corrected painted front foot |
| --- | --- | --- |
| West | left edge +40px | left edge +73.892px |
| East | right edge -40px | right edge -73.892px |
| North | top edge +64px | top edge +92px |
| South | bottom edge -16px | bottom edge -54px |

West/east plinth centers are symmetric around the lane. North placement clears the 48px cap plus 22px visible wall face. Bounds use the actual play rectangle, so small inset rooms keep their actual road-mouth alignment.

Each pillar sorts as one unit with ordinary actors. The root is 22px above its painted front foot, matching `Player.HERO_FEET_ANCHOR`; the sprite compensates locally, preserving its painted position. Existing `PropShadow` supplies the contact rim and follows source frames. Standard structure-occlusion metadata makes the player's existing clipped silhouette available behind the stone.

Existing flame and floor glows move with the sprite while retaining their textures, colors, scales, pulse timing, random-number consumption and light budgets. Weak references protect retirement callbacks. This adds no collider or PointLight and changes no wall, gate or admission rule. Separately authored large `Terrains.STRUCTURES.torch_pillar` structures retain their own placement.

## Baseline evidence

- Desktop baseline2: 16 strict checks, 0 failures, 52 expected old floor/depth findings, 13 capture events/files and 5 ordinary keyboard legs; all four natural flame frames observed. All 13 native files reviewed in `build/qa/wall-torch-desktop-baseline2-review.md`.
- Mobile-source baseline1: 16 strict checks, 0 failures, 64 expected old findings, 16 capture events but 13 final unique files, 5 keyboard legs. Three repeated animation filenames were overwritten; only the 13 surviving files are reviewed in `build/qa/wall-torch-mobile-baseline1-review.md`. The corrected rig gives every capture a unique name.
- All 13 shared final baseline views have identical wall/lock/body/light receipts and identical pillar geometry after excluding natural frame indices: `build/qa/wall-torch-baseline-cross-renderer.json`.
- Desktop baseline1 failed its 6s natural-frame observation window after three costly native readbacks; no movement ran. Its ten images/log and original rig are preserved. The 30s bounded rerun retained strict four-frame completion and the original 6s movement deadlines.

The native west/east wood and moss bases visibly straddle the wall edge. North and south columns are partly covered by the normal HUD near camera limits; those images do not establish unobstructed contact quality. Far behind/front baseline poses are not exact sorting-threshold proof. The corrected rig adds explicit setup poses with the hero's painted feet 3px behind/in front, actual alpha overlap and standard clipped-outline checks.

## Corrected native evidence

Desktop fixed2 passed 112 checks with no failures or findings, 15 unique native images and five ordinary keyboard legs. Mobile fixed1 passed 118 checks with no failures or findings, 16 unique images and five legs. All 31 images were independently reviewed. The mobile natural-frame sequence observed frame 2 twice; unique filenames preserve both captures. Every frame keeps the measured base grounded.

Both renderers reach actual painted feet offsets of -3/+3 pixels with alpha 1.0 overlap. Behind the stone, its existing clipped player outline is present; in front, the hero draws over the stone with no stale outline. All nine shared before/after view mechanics dictionaries match in each renderer, including wall and room bounds, exits, unlock predicates, collider counts and glow/PointLight counts. The row/road layout is unchanged.

Reports with exact source, log, JSON and PNG hashes are `build/qa/wall-torch-desktop-fixed2-review.md` and `wall-torch-mobile-fixed1-review.md`. Installed source is recorded in `checkpoint33-source-freeze1.json`; candidate line-ending normalization does not change source semantics. The earlier fixed1 run failed a QA-only inferred-boolean compile error before any native window; the explicit type annotation is included in fixed2.

Chapter 3 desktop/mobile checks passed 112/142 checks with zero failures or findings, 15/20 unique native images and five ordinary keyboard legs each. All 35 images were reviewed in `build/qa/wall-torch-ch3-fixed-native-review.md`. Chapter 3 supplies the grave-wall setting; its material control repeats the Vigil east view, so no second chapter 3 wall material is claimed. Twelve common capture mechanics receipts match across renderers. In total, all 66 corrected torch images were reviewed. Desktop compile225/quick125/full205 and mobile import/compile225/strictquick125 passed; full preflight passed without findings. These are host renderer checks; the torch rig uses keyboard input in both projects, not a physical mobile device or touch joystick. Posed views and frozen enemies are distinct from the five recorded ordinary movement legs. No rendering-performance claim is made.

Reproduce serially in fresh isolated QA APPDATA beneath `build/qa`, using the muted compile-gated runner:

```text
shot.bat wall_torch_mount --timeout=300
shot.bat wall_torch_mount --chapter=ch3 --timeout=300
```

Append `--mobile --renderer=gl_compatibility` for the mobile-source renderer. `--baseline` records old placement findings only when running the archived baseline implementation; it is not a substitute for regression acceptance.
