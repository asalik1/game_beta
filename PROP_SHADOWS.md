# Prop shadow grounding

The September 9 owner screenshot showed the mirrored `tombstone3` cluster
casting a detached shape. The shared renderer measured only the lowest 8% of
opaque pixels. A sloping group, rock corner or broad pedestal could therefore
look like a narrow trunk and receive a projection around the canvas bottom.
The same calculation ignored transparent padding and the full source transform.

`scripts/prop_shadow.gd` now owns scenery shadow geometry. The bottom quarter
distinguishes a broad ground footprint from a narrow trunk. Broad props retain
their complete source silhouette with a southeast contact rim capped at eight
world pixels. Narrow props project from a visible foot point using the source
transform, preserving padding, offsets, centering and mirroring. Sprite strip
cells and animated frames share the same measured geometry and frame cache.
Atlas views have separate cache identities and include their draw margins;
vertically flipped sprites measure their displayed lower footprint. A fitted
broad shadow replaces the generic center ellipse, which otherwise still
floated below diagonal groups and logs. Narrow projected props and no-cast
fallbacks retain it; canopy trees use the trunk contact described below.
The source artwork, colliders and prop placement are unchanged.

Lore objects made through the NPC interaction factory use the same scenery
path. Gravestones, shrines and chests retain their authored pose while the hero
turns to address them. Citizen facing and breathing remain available.

The original production path is preserved in
`build/qa/prop-shadows-baseline1*`: 80 structural checks, 16 fullframes and 15
native framebuffer crops. The mirrored cluster matches the reported defect.
These baseline checks establish reproducible factories, frames and captures;
they do not assert that the old shadows look correct.

The new geometry contracts cover authored broad/narrow shapes, padded and
rotated sprites, centering, negative scale, strips, shared atlas regions and
margins, flipped footprints and animated shadow lifetime. Desktop quick1 and
strict mobile quick1 passed 125 checks; the latter includes the expanded atlas
and flip regressions. These quick runs precede the final ellipse cleanup.

Desktop visual1 passed 113 checks/19 fullframes but review found the remaining
generic ellipse. Visual2 passed 129 checks/19 fullframes and 18 native closeups,
including the absence of that redundant ellipse and two real keyboard reads
of an interactive gravestone. Source/cast pose remained stationary over the
former breathing window. Evidence is under `build/qa/prop-shadows-desktop2*`.
The mobile Compatibility run also passed 129 checks/19 fullframes/18 native
closeups. Every desktop2 and mobile image was reviewed with no remaining
actionable shadow or interaction-pose issue; both sampled phases of the tree
and fountain were inspected. Reports are `prop-shadows-desktop-review.md` and
`prop-shadows-mobile-review.md` under `build/qa/`. Mobile here means the mobile
source running Compatibility on the host, with keyboard input; this is not a
physical-device, touch-interaction or complete-animation-loop claim.
Final desktop compile224/full205 and mobile compile224/strictquick125 passed
after the ellipse cleanup. Full preflight reported no findings. The frozen
source, explicit paths, logs and final identity use the `checkpoint31-` prefix
under `build/qa/`, including `checkpoint31-validation.json`.


## Loot chest ground contact — September 17, 2026

Loot chests use the closed sprite's measured painted base to place their
existing contact ellipse. The padded lid canvas no longer determines ground
contact. Measurement reuses the prop geometry cache, occurs once on creation,
and retains the 44 by 14.4 logical-unit footprint and existing opacity. The
ellipse center sits two units inside the base; it stays still during the
cosmetic scale pop and opening animation. Art, placement, collisions and
reward rolls are unchanged. Empty geometry retains the previous fallback.

`shot.bat prop_shadows --chests --timeout=240` exercises actual F/B gear and
bronze supply factories on village and graveyard floors. The posed rows use
quiet terrain, hidden scenery and direct lid previews; they are controlled
visual fixtures. Separate normal W-key pickup controls verify movement,
exact single payout and parent/shadow cleanup. Frame samples check a single
persistent stationary shadow; they do not establish exhaustive animation or
performance coverage. Pickup screenshots are partly hero-occluded.

Evidence lives under `build/qa/session-sept17/chest-grounding-*`. Rejected
baseline1 stopped at a QA type-inference compile error; baseline2 exposed an
invalid CanvasLayer visibility call. Corrected baseline3 reproduced four
contact failures in 106 checks. Prototype1 passed strict contact, retained
footprint, opening and pickup checks, with all six native images reviewed.
Final acceptance, source pins, validation logs, visual manifests and commit
identity are recorded in `chest-grounding-checkpoint-validation.json` there.
Mobile validation uses the mobile source on the Windows host Compatibility
renderer; it does not establish physical-device or touch-pickup behavior.

## Tree trunk contacts — September 29, 2026

Owner playtest: large trees threw no ground shadow while their sibling props
did. Broad-rooted canopy art classified as a hugging copy, which hid the
generic ellipse and left only a thin rim, and composite parts never cast.

Canopy trees (`_canopy_tree`: the name contains `tree` and is not solid decor)
now use a third mode, `trunk`, in `scripts/prop_shadow.gd`. It is a soft
`shadow` ellipse, not a copy of the art, centred on the opaque root band: the
bottom `TREE_SHADOW_FOOT_BAND` of the painted rows, counting only pixels above
`TREE_SHADOW_ALPHA_MIN` alpha so export fringe cannot widen or shift it. Width
is the root span times `TREE_SHADOW_WIDTH_SCALE`, capped at
`TREE_SHADOW_CANOPY_FRACTION` of the canopy width and clamped to
`TREE_SHADOW_WIDTH_MIN`/`MAX`; depth is `TREE_SHADOW_DEPTH` of the width. The
generic prop ellipse is always hidden for trees, and the contact stays put
while the canopy sways.

Scatter trees, composite tree bases and parts, and lore trees built by the NPC
interaction factory (the Hollow Oak's deadtree) all use it. Every other
composite part (statues, pillars, cacti, rocks, braziers) now casts the same
hugging or projected copy it gets standing alone. Each shadow sits below its
source, and inside a composite below the lowest sunken part, so no rim or
contact draws over a prop.

`test_prop_shadows.run_trees` (quick tier) covers the factories, root-band
position, trunk span, canopy cap, composite part coverage and layering, and
the tree_green4 fringe. `shot.bat prop_shadows --tree-contacts` captures
matched before/after frames of one frozen forest fixture and checks a lore
tree NPC.
