# Companions that actually move

The six rescue companions previously displayed a single painted portrait while
the follower code moved and bobbed it. That made them slide through the world.
They now have eight distinct frames each: Spore Pup steps, Hearth Hopper hops,
and the bat, crow, dragonfly and moth articulate their wings.

Ground companions use their resting frame while still. Their walking cadence
responds to actual follower speed; teleports do not count as a giant stride.
Flying companions continue beating their wings while hovering. Sanctuary
animals walk short routes with pauses and turn to face their travel.

The portraits remain the collection/Wardrobe illustrations. World actors load
the separate `companion_<id>_walk.png` strips. All frames share one scale and a
stable face anchor; changing wing span cannot resize or shift the creature.
The frog adds a small flight arc to its authored hop poses. The renderer does
not manufacture leg or wing motion by moving a static portrait.

## Art and reproduction

The six masters were generated with the built-in ImageGen tool, using the
existing companion atlas as the identity reference. Source masters, hashes,
briefs and review sheets are preserved in
`art_src/companion_motion_2026-09-08/`. The first transparency attempts produced
baked checkerboards and were rejected; the accepted masters use flat green or
magenta extraction backgrounds. A crowded crow sheet was also rejected.

`python tools/art/build_companion_motion.py` uses the repository's existing
key/despill and whole-figure gutter extraction. It refuses unsafe separators,
aligns whole frames using the face, applies one scale per cycle, and checks
clear margins. It never composites limbs or repairs a pose from another frame.
The six installed strips contain 8 × 512-square frames and use mipmaps.

All six frame sheets were visually reviewed. The art gate has zero failures.
Its silhouette-anchor warnings measure intentional wing and hop articulation;
the face anchor and body scale remain fixed. Antialiasing causes the existing
semi-alpha warning, while the specific green/magenta rim scan reports zero
defects or suspects. Glimmerwing's green is inside its body, as intended.

## Checks

`test_companion_motion.gd` requires all six installed eight-frame clips, actual
frame advancement, fixed scale, finite offsets, grounded idle and continuous
hovering wingbeats. `shot.bat companions --timeout=240` captures 24 six-animal
motion samples plus grounded rest, the real follower moving/stopping, and a
flying companion with the touch HUD. Logs and the generated engine preview
are under `build/qa/companions-*`.

Desktop full and mobile import/compile/quick results are recorded in
`AUTONOMOUS_STATUS.md` after validation finishes.


September 8 capture refresh: `build/qa/companions-in-game-calibrated.gif`
shows the same accepted motion strips with correct HDR-to-sRGB readback and
the new painted grass. The real follower/settle/flying/touch rig passes all
28 captures; no companion art or movement logic changed in this refresh.


## Sanctuary, Codex and Wardrobe previews

The menus now show each companion's actual movement frames too. A separate
UI Control drives short walk/rest cycles for grounded pets and continuous
wingbeats for flying pets while solo menus pause the world. World followers
retain their existing clock. Hidden previews and cards scrolled fully outside
their clipped panel do not advance. Closing/rebuilding the menu frees them.

The preview measures every frame's visible bounds once per texture, reserves
hop/hover headroom, and only shrinks the original pet scale to fit its card.
It never clips a wing or tail to fit one pose. Sanctuary keeps its dimmed
unrescued creatures and rescue/equip controls. Wardrobe uses aligned 44-pixel
action buttons, animated 64-pixel cards and visible lore. Existing prices and
ownership rules remain unchanged. Codex Sanctuary uses this same page.

`test_companion_preview.gd` checks every cycle in both menu sizes, fixed scale,
grounded rest, hidden/clipped clocks and rebuilding an empty preview.
`shot.bat companion_previews --timeout=240` checks actual paused-menu motion,
the paused world follower, purchase/equip/return callbacks, all six rows,
Codex and touch layout, with twelve calibrated captures. The first live rig
incorrectly assumed equipping rebuilt the world sprite before unpausing;
the corrected rig closes the menu and verifies the actual resumed follower.

No companion art was regenerated in this UI pass.

Final validation: desktop 188-script compile, 113 quick
checks and 193 full checks. Mobile editor import,
188-script compile and 113 quick checks. All
strict PASS without script errors. Desktop Forward+ and mobile Compatibility
each pass twelve companion-menu captures and five real final-boss captures.
The original seven-capture actual ENet history/reconnect rig passes again.
Twelve frozen source files match their mobile mirrors, with four independent
UID pairs. Source preflight has zero failures and 12 known structural warnings;
the engine Codex data gate passes. No new art, hardware QA or commits.
