Generated with the built-in image tool using Image 1 for orientation/weapon and Image 2 for identity/palette.

Files:

- [Raw 2×2 master](C:/Users/asali/Projects/MMO/art_src/drift_fix_2026-08-24/saint_varo_standing_ability_e/ability_master_2x2_v1.png) — 1254×1254 px; 627×627 per cell; 1,404,442 bytes.
- [Keyed master](C:/Users/asali/Projects/MMO/art_src/drift_fix_2026-08-24/saint_varo_standing_ability_e/ability_master_2x2_v1_keyed.png) — transparent PNG, auto-key and despill enabled.

Blunt QA:

- TL: one two-handed relic greatsword; E/right-profile facing confirmed.
- TR: one raised two-handed relic greatsword; E/right-profile facing confirmed.
- BL: one striking two-handed relic greatsword; E/right-profile facing confirmed.
- BR: one recovering two-handed relic greatsword; E/right-profile facing confirmed.
- Weapon remains recognizably the reference greatsword, though minor frame-to-frame generative detail variation exists.
- Significant anchor drift: foot baseline is 61 px higher in the bottom row. Horizontal body position varies by roughly 60 px.
- The BL strike radiance crosses the internal vertical cell boundary into BR. No outer-canvas edge contact.
- Raw backdrop failed the perfectly uniform `#00ff00` requirement—it contains varied greens. The keyed output successfully removes it and has no green-dominant nontransparent pixels.
- `remove_chroma_key.py` was absent, so a temporary local compatible helper was created, run, and removed. No slicing or installation was performed.