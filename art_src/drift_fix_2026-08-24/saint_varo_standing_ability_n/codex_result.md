Generated with built-in ImageGen and saved:

- [Raw master](/C:/Users/asali/Projects/MMO/art_src/drift_fix_2026-08-24/saint_varo_standing_ability_n/ability_master_2x2_v1.png) — 1254×1254, 627×627 cells, 1,403,150 bytes.
- [Keyed master](/C:/Users/asali/Projects/MMO/art_src/drift_fix_2026-08-24/saint_varo_standing_ability_n/ability_master_2x2_v1_keyed.png) — auto-key, despill, soft matte.

Blunt QA:

- TL: N/back-facing; greatsword present. Second-hand grip is partly obscured.
- TR: N/back-facing; clearly raised two-handed greatsword.
- BL: N/back-facing; greatsword strike and gold-purple burst.
- BR: N/back-facing; greatsword recovery pose, with partially obscured grip.
- All four poses are visibly distinct.
- Anchor lock fails: lower-row feet sit 28–29 px higher. Horizontal robe centers vary by about 131 px, so sliding is substantial.
- No actual cell-edge touch after keying, but BL radiance has only 8 px top clearance—too tight for the requested generous margin.
- Raw chroma fails the exact requirement: it is nonuniform, with 233 border colors; auto-key sampled `#0aed12`, not `#00ff00`. The keyed result removes it successfully.

Verdict: weapon, facing, identity, and storyboard pass; raw-green uniformity and fixed anchoring do not. Nothing was sliced or installed.