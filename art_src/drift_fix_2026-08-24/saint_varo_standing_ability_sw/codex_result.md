Generated exactly one sheet with built-in ImageGen.

Files:

- [Raw master](/C:/Users/asali/Projects/MMO/art_src/drift_fix_2026-08-24/saint_varo_standing_ability_sw/ability_master_2x2_v1.png) — 1254×1254 RGB, 1,550,305 bytes; 627×627 per cell.
- [Keyed master](/C:/Users/asali/Projects/MMO/art_src/drift_fix_2026-08-24/saint_varo_standing_ability_sw/ability_master_2x2_v1_keyed.png) — 1254×1254 RGBA, 904,551 bytes.

Keying used border auto-key, soft matte, and despill. Detected key: `#06f707`.

| Cell | Weapon | Facing | Edge contact |
|---|---|---|---|
| TL | Broad two-handed greatsword | SW/front-left | None |
| TR | Broad two-handed greatsword | SW/front-left | None |
| BL | Broad two-handed greatsword with strike burst | SW/front-left | None; effect comes within 16 px |
| BR | Broad greatsword; two-hand grip is less readable | SW/front-left | None |

Blunt QA:

- Anchor lock failed. Horizontal body position drifts by roughly 155 px between cells; head and foot baselines drift about 29–30 px vertically.
- Raw backdrop failed the exact specification: only 2 pixels are `#00ff00`; the border contains 293 colors with median `#06f707`.
- The skull face is too dark/helmet-like, and the vestments are predominantly black-and-gold rather than strongly gold-and-purple.
- All four poses are distinct, all weapons read as greatswords, and no content touches the canvas edges, cell edges, or seams.
- No slicing or installation was performed.

Final prompt used the supplied brief as a structured specification, repeatedly locking Image 1 to weapon/SW orientation and Image 2 to identity/palette.