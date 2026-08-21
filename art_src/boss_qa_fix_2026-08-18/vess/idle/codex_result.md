Created:

- [idle_master_2x2_v1.png](C:\Users\asali\Projects\MMO\art_src\boss_qa_fix_2026-08-18\vess\idle\idle_master_2x2_v1.png) — raw RGB, **1254×1254 px**
- [idle_master_2x2_v1_keyed.png](C:\Users\asali\Projects\MMO\art_src\boss_qa_fix_2026-08-18\vess\idle\idle_master_2x2_v1_keyed.png) — RGBA, automatic border key and despill

All four poses are visibly different:

- Frame 1: neutral rest.
- Frame 2: arms/hands spread and lift slightly.
- Frame 3: veil, arms, and gown shift noticeably.
- Frame 4: narrower, lowered settling pose.

Defects:

- The raw background is neither uniform nor literal `#00ff00`. It contains no exact `#00ff00` pixels; automatic sampling returned `#0ef011`.
- Frame 3 violates the anchor rule: its head rises about 8 px and the figure grows to 344×454 px, versus roughly 324–334×446–447 px elsewhere.
- The feet remain within 1 px vertically, and sideways centering varies only slightly.
- The character is recognizable and palette-consistent, but not an exact reproduction: face, hands, hood, and cloak details were reinterpreted.
- Body height is about 71–72% of each cell, short of the requested 74%.
- No extra heads or limbs, wrong-facing frames, separators, shadows, edge contact, text, or residual green-dominant visible pixels were found.

Built-in ImageGen was used once. The supplied prompt was preserved in substance, with malformed dash markers normalized and “exactly one image” clarified.