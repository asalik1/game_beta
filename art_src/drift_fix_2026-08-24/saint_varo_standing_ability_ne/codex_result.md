Generated exactly one sheet with the built-in image tool.

Files:

- [Raw PNG](C:/Users/asali/Projects/MMO/art_src/drift_fix_2026-08-24/saint_varo_standing_ability_ne/ability_master_2x2_v1.png) — 1254×1254, 1,425,012 bytes.
- [Keyed PNG](C:/Users/asali/Projects/MMO/art_src/drift_fix_2026-08-24/saint_varo_standing_ability_ne/ability_master_2x2_v1_keyed.png) — auto-keyed from `#08f40a`, soft-matte despill enabled.

Blunt QA:

- TL: unmistakable greatsword; NE/back-right facing passes. Second-hand grip is somewhat ambiguous.
- TR: greatsword and two-handed grip pass; NE/back-right facing passes.
- BL: greatsword passes, but facing fails—it turns toward a left-facing profile. Holy burst is oversized.
- BR: greatsword and two-handed grip pass; NE/back-right facing passes.
- No edge contact. Minimum cell margins: TL 59 px, TR 36 px, BL 50 px, BR 103 px.
- Significant drift: bottom-row feet sit 43 px higher than the top row; strike-frame body shifts roughly 100 px right.
- Bodies are approximately 58% of cell height, short of the requested 70%.
- Raw backdrop fails the exact requirement: zero pixels are literal `#00ff00`; it is a noisy near-green with 321 border colors. The keyed result removes it cleanly.
- Overall verdict: usable for review, but not production-pass because of strike-facing failure, anchor drift, underscaling, and nonuniform raw key color.

Final prompt used was the supplied four-frame brief normalized into labeled fields, with Image 1 locked to orientation/weapon, Image 2 locked to identity/palette, and strengthened prohibitions against weapon morphing, mirrored facing, green effects, and edge contact.