Generated one 2×2 master using built-in ImageGen:

- [Raw master](/C:/Users/asali/Projects/MMO/art_src/drift_fix_2026-08-24/saint_varo_standing_ability_se/ability_master_2x2_v1.png) — 1254×1254 RGB, 627×627 per cell, 1,516,242 bytes.
- [Keyed master](/C:/Users/asali/Projects/MMO/art_src/drift_fix_2026-08-24/saint_varo_standing_ability_se/ability_master_2x2_v1_keyed.png) — 1254×1254 RGBA, 817,298 bytes.

| Cell | Weapon | Facing | Anchor audit |
|---|---|---|---|
| TL wind-up | Greatsword, both hands | SE; slightly frontal | Feet y=553 |
| TR raise | Greatsword, both hands | Strong SE match | Feet y=553 |
| BL strike | Greatsword, both hands | SE; slightly frontal | Feet y=537—16 px too high |
| BR recover | Greatsword, both hands | SE | Feet y=556 |

Blunt QA:

- All four poses are visibly different and use the correct broad relic greatsword.
- No edge-touch. Closest is the strike radiance, only 9 px from its cell’s top boundary.
- Significant horizontal body drift remains: measured lower-body centers span roughly 105 px.
- Body height is about 55% of a cell, short of the requested ~70%.
- Raw green is not mathematically uniform `#00ff00`; auto-key detected approximately `(17,247,13)`. The keyed derivative removes it cleanly with despill; visible green-dominant residue count is 0.
- No slicing, installation, or writes outside this working directory.

The final prompt preserved the supplied brief, with Image 1 locked as facing/weapon reference and Image 2 locked as identity/palette reference. The requested keying script was absent, so I created and ran a temporary local equivalent with auto-key and despill enabled, then removed it.