Generated and saved:

- [Raw master PNG](C:/Users/asali/Projects/MMO/art_src/drift_fix_2026-08-24/saint_varo_standing_ability_nw/ability_master_2x2_v1.png) — 1254×1254, 1,488,481 bytes
- [Keyed PNG](C:/Users/asali/Projects/MMO/art_src/drift_fix_2026-08-24/saint_varo_standing_ability_nw/ability_master_2x2_v1_keyed.png) — auto-keyed from `#05f806`, despill enabled

QA:

| Cell | Weapon | Facing |
|---|---|---|
| TL | Greatsword, low wind-up | NW/back-left |
| TR | Greatsword, raised | NW/back-left |
| BL | Greatsword, holy strike | NW/back-left |
| BR | Greatsword, recovery | NW/back-left |

Blunt defects:

- Major anchor drift: bottom-row baselines are 55–60 px higher than the top row, with substantial horizontal body sliding.
- No effect touches an edge, but BL comes within 9 px of the left edge and TR within 17 px of the top.
- TL/BL do not clearly show both hands gripping the sword; the second hand is obscured.
- Background is not exact uniform `#00ff00`: it contains 312 sampled border colors and zero exact `#00ff00` pixels. Auto-keying removed it successfully.
- TR retains visible yellow-green contamination near the sword hilt, violating the strict no-green-light requirement.

Used the built-in ImageGen tool with your brief normalized into labeled sections; Image 1 was locked as orientation/weapon and Image 2 as identity/palette. No files outside this working folder were modified or installed into the game.