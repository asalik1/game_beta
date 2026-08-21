Generated one sheet with the built-in ImageGen tool and saved:

- [walk_master_2x2_v1.png](C:/Users/asali/Projects/MMO/art_src/boss_qa_fix_2026-08-18/vargoth/walk/s_r5/walk_master_2x2_v1.png) — raw, unresized, **1254×1254**
- [walk_master_2x2_v1_keyed.png](C:/Users/asali/Projects/MMO/art_src/boss_qa_fix_2026-08-18/vargoth/walk/s_r5/walk_master_2x2_v1_keyed.png) — **1254×1254 RGBA**, auto-keyed with despill

All four poses are visibly different:

1. Screen-left boot forward, wide contact.
2. Narrow passing pose, knees close.
3. Screen-right boot forward, opposite contact.
4. Opposite narrow passing pose.

Blunt defects:

- Raw background is not uniform `#00ff00`. The sampled key was `#06f80c`; the border contained 192 green variants and zero exact `#00ff00` pixels.
- Characters occupy about **77.7%** of cell height, not 68%.
- Bottom-row figures are shifted roughly **14 px upward** relative to the top row, violating the fixed anchor rule.
- Identity is recognizable and not generically redesigned, but crown, armor, flames, and proportions were reinterpreted rather than reproduced exactly.
- Passing frames remain similar to their neighboring contact frames above the knees.
- No extra limbs/heads, wrong facing, edge contact, or weapon-side/angle flip was found.
- Final keyed image has no measured green-dominant visible fringe pixels.

No slicing or installation was performed.