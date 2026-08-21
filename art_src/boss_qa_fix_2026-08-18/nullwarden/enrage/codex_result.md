Generated exactly one sheet using built-in ImageGen.

Files:

- [Raw 2×2 master](C:/Users/asali/Projects/MMO/art_src/boss_qa_fix_2026-08-18/nullwarden/enrage/enrage_master_2x2_v1.png) — **1254×1254 px**, byte-identical to the generated PNG.
- [Keyed RGBA master](C:/Users/asali/Projects/MMO/art_src/boss_qa_fix_2026-08-18/nullwarden/enrage/enrage_master_2x2_v1_keyed.png) — 1254×1254 px, auto-key border sampling, soft matte, and despill enabled.

All four poses are visibly different:

1. Wind-up: hunched, fists inward.
2. Swell: head raised, arms flared, brighter glow.
3. Roar: head thrown back, arms fully spread, maximum glow.
4. Settle: crouched inward, glow dimmed.

Defects:

- The raw background is not uniform `#00ff00`; it contains zero exact `#00ff00` pixels. Auto-key sampled `#09f808`, with green gradients around the glow.
- Character content occupies only **56–62%** of cell height, substantially below the requested 74%.
- Serious anchor drift: bottom-row figures sit about **44 px higher** than the top row. Horizontal centers alternate by roughly **32–35 px**.
- Frames 2–3 are visibly larger than frames 1 and 4, and some helmet, torso, and gauntlet details change. Identity is recognizable but not exactly locked to the reference.
- No weapon, extra limbs, wrong facing, separators, shadows, or edge-touching effects were found.

The final prompt followed the supplied brief, with punctuation normalized and the weapon/anatomy constraints reiterated.