Generated exactly one sheet with built-in ImageGen.

- Raw: [attack_master_2x2_v1.png](<C:\Users\asali\Projects\MMO\art_src\drift_fix_2026-08-24\korrag_attack_n\attack_master_2x2_v1.png>) — 1254×1254 RGB, 1,588,121 bytes. Hash matches the untouched generated PNG.
- Keyed: [attack_master_2x2_v1_keyed.png](<C:\Users\asali\Projects\MMO\art_src\drift_fix_2026-08-24\korrag_attack_n\attack_master_2x2_v1_keyed.png>) — auto-key plus soft matte/despill; no visible green-dominant pixels remain.

| Cell | View | Blunt QA |
|---|---|---|
| TL wind-up | BACK | No face or extra limbs. Correct baseline. Whip is in the viewer-left hand. BL strike effects intrude across this cell’s bottom boundary. |
| TR gather | BACK | No face or extra limbs. No sliding or edge contact. Chain loop and weight are noticeably larger than TL, and the weapon switches hands. |
| BL strike | BACK | No face or extra limbs. Body is about 11 px higher than the top row. Whip/lightning crosses 7 px above its cell boundary—fails the no-edge-touch/no-overlap constraint. |
| BR recover | BACK | No face or extra limbs. Body is about 11 px too high. Clear margins, but the weapon remains in the opposite hand from TL. |

Identity drift is moderate: armor, horns, palette, and rear tabard remain recognizable, but the weapon changes hands and its length/end-weight vary. All four poses are distinct and back-facing.

The raw backdrop also fails the literal flat `#00ff00` requirement: it contains 173,320 RGB colors and only 3 exact `#00ff00` pixels; auto-key sampled approximately `#08f809`. The keyed output compensates for this, but the raw sheet is not specification-perfect.

Final prompt used the supplied brief normalized into labeled production fields, with Image 1 locked as the sole identity/view reference and no added creative elements. No MMO files outside this working folder were modified.