Generated one master with built-in ImageGen and did not slice or install it.

Files:

- [ult_se_v1.png](C:/Users/asali/Projects/MMO/.claude/worktrees/focused-bhaskara-90aea6/art_src/warlock_unify_imagegen_2026-08-24/ult_se/ult_se_v1.png) — raw RGB, **2172×724 px**
- [ult_se_v1_keyed.png](C:/Users/asali/Projects/MMO/.claude/worktrees/focused-bhaskara-90aea6/art_src/warlock_unify_imagegen_2026-08-24/ult_se/ult_se_v1_keyed.png) — RGBA, auto-key sampled with soft-matte despill

Blunt audit: **not a clean spec pass.**

- Nine figures were produced in one horizontal row, with no overlaps.
- The poses are different overall, but frames 6–7 are too similar; frame 6 is still the widest pose.
- He stayed lean/slender and consistently faced the correct front-right/SOUTH-EAST direction. Frame 9 did not flip.
- Skull and grimoire remained on the correct sides. No extra limbs, duplicate props, or large detached hex effects.
- Identity drifted: the face is softer/different, the chest treatment resembles heavier crossed straps, and robe/tabard details are not an exact match.
- The pixel treatment is smoother and higher-resolution than the binding reference.
- The output is 3:1, not nine square cells. Nine nominal slices would be approximately 241×724 px, and the width is not divisible by nine.
- Character height is about **49%** of the canvas, not the requested 66%.
- Vertical anchoring drifts roughly 12 px overall; the feet vary by about 6 px.
- Frame 9’s book/flame reaches the right canvas edge and appears clipped.
- The raw background is varied near-green centered around `#07f90b`, not perfectly flat `#00ff00`. The keyed output removes the visible green contamination.