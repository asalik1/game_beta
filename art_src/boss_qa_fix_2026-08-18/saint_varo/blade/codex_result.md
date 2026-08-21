Generated exactly one image with built-in ImageGen.

- Raw: [blade_master_2x2_v1.png](/C:/Users/asali/Projects/MMO/art_src/boss_qa_fix_2026-08-18/saint_varo/blade/blade_master_2x2_v1.png) — **1254×1254 RGB**, unresized and byte-identical to the generated PNG.
- Keyed: [blade_master_2x2_v1_keyed.png](/C:/Users/asali/Projects/MMO/art_src/boss_qa_fix_2026-08-18/saint_varo/blade/blade_master_2x2_v1_keyed.png) — **1254×1254 RGBA**, auto-key sampled with soft matte and despill.

All four poses are visibly different:

1. One raised open hand with light.
2. Both hands raised.
3. Both arms thrust upward with a large flare.
4. Hands lowered with fading sparks.

Defects:

- **Frame 3 is not safely sliceable by quadrants.** Its flare crosses **24 pixels into the top row**, contaminating frame 1 and clipping frame 3 when cropped.
- The bottom-row character baseline is about **13 pixels lower** than the top row, violating the fixed-anchor rule.
- Frame 2’s light is at the chest, below/between the hands—not above the palms.
- Frame 3’s flare is oversized with a long vertical ray, not compact.
- The raw background is **not uniform `#00ff00`**; it varies across the canvas. The keyed output removes the visible green.
- The character is recognizable but not exact: skull, hands, cape, and throne details are redrawn and vary slightly between frames.
- No weapons, extra limbs, extra characters, wrong-facing frames, text, or watermark were found.

No slicing or installation was performed.