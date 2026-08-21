Created the requested files:

- [Raw master](C:/Users/asali/Projects/MMO/art_src/boss_qa_fix_2026-08-18/vess/walk/n/walk_master_2x2_v1.png) — **1254×1254 px**
- [Keyed RGBA master](C:/Users/asali/Projects/MMO/art_src/boss_qa_fix_2026-08-18/vess/walk/n/walk_master_2x2_v1_keyed.png) — **1254×1254 px**

All four poses are visibly different:

1. Compact neutral hem.
2. Raised, widely flared robe.
3. Strong asymmetric cloth sweep.
4. Compact jagged settling hem.

Defects:

- Raw background violates the brief: it is neither uniform nor exact `#00ff00`. It contains 18,316 green shades; only 18 pixels are exact `#00ff00`.
- Scale drifts: frames 2–3 are about 7% taller than frames 1 and 4.
- Right-column frames are shifted roughly 22–26 px left.
- The vertical bob is excessive and incorrectly sequenced. Frame 2 rises about 56 px rather than “a few”; frame 4 remains roughly 40 px above frame 1 instead of settling back down.
- Frames 2–3 occupy about 75% of cell height rather than 68%.
- Upper bodies are nearly static; most differentiation is confined to robe/hem deformation.
- The keyed result is clean after auto-border sampling, soft matte, and despill: no green-dominant visible pixels remained.

Correct aspects: exactly four heads and four characters; all face directly away; no faces, feet, weapons, effects, extra limbs, scenery, shadows, separators, or edge contact. Identity and palette remain recognizably Vess, though the back veil is necessarily extrapolated from front references.

Built-in ImageGen was used once. The supplied prompt was used verbatim apart from normalizing the `???` separators to em dashes.