Generated exactly once.

Files:

- [Raw 2×2 master](C:/Users/asali/Projects/MMO/art_src/drift_fix_2026-08-24/saint_varo_standing_ability_w/ability_master_2x2_v1.png) — 1254×1254 px, 1,437,650 bytes; 627×627 px per cell.
- [Keyed master](C:/Users/asali/Projects/MMO/art_src/drift_fix_2026-08-24/saint_varo_standing_ability_w/ability_master_2x2_v1_keyed.png) — RGBA, auto-key + soft matte + despill.

| Cell | Weapon/facing | QA |
|---|---|---|
| TL | Two-handed greatsword; W/left profile | No edge touch; only 13 px below feet. |
| TR | Two-handed greatsword; W/left profile | No edge touch; sword tip 33 px from top. |
| BL | Two-handed greatsword; W/left profile | **Fails cell containment:** robe crosses the center seam into BR. Strike glow is 34 px from the outer left edge. |
| BR | Two-handed greatsword; W/left profile | Left cell boundary is contaminated by BL’s crossing robe. |

Blunt assessment:

- Weapon and W-facing pass in all four cells, though the hilt/blade proportions morph slightly between frames.
- Anchor lock fails badly: bottom-row feet sit roughly 87–97 px higher than the top row, with visible horizontal body shifting.
- No outer-canvas edge touch, but there is an internal cell-boundary crossing.
- Raw background also misses the literal requirement: it contains zero exact `#00ff00` pixels; auto-key sampled `#09f310`.
- Final keyed image has no measurable visible bright-green or green-dominant residue.
- Nothing was sliced or installed into game assets.

Built-in ImageGen was used with the supplied brief normalized to make Image 1 binding for the unmirrored W orientation/greatsword and Image 2 binding only for identity and palette.