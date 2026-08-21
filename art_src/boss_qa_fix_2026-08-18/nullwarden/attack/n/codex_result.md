Generated exactly one sheet using built-in ImageGen.

- Raw: [attack_master_2x2_v1.png](<C:\Users\asali\Projects\MMO\art_src\boss_qa_fix_2026-08-18\nullwarden\attack\n\attack_master_2x2_v1.png>) — 1254×1254 RGB
- Keyed: [attack_master_2x2_v1_keyed.png](<C:\Users\asali\Projects\MMO\art_src\boss_qa_fix_2026-08-18\nullwarden\attack\n\attack_master_2x2_v1_keyed.png>) — 1254×1254 RGBA

All four poses are visibly different:

1. Low-fist wind-up.
2. Both fists raised, gathering energy.
3. Large diagonal forward strike.
4. Lowered-fist recovery.

Blunt QA: this sheet is not fully brief-compliant.

- Character is off-model: taller, narrower, and less squat than the binding reference, with smaller-looking gauntlets and redesigned rear armor.
- Background is neither uniform nor `#00ff00`. Auto-key sampled `#0af80d`; the raw image contains thousands of green shades and zero exact `#00ff00` background pixels.
- Anchor/scale drift: frames 1, 2, and 4 occupy about 63% cell height; frame 3 occupies 84% and its lowest extent shifts roughly 30 pixels downward.
- Frames 2 and 3 contain detached cyan spark flecks around the hands, violating the strict “nothing detached” rule. None touches an edge; frame 3 comes within 6 pixels.
- Back view is readable in every frame with no visible face or eyes.
- No sword, weapon, projectile, extra limbs, extra heads, text, scenery, shadows, or separators.
- The final keyed file used border auto-sampling, soft matte, one-pixel contraction, and despill; no visible green-dominant pixels remained in the QA scan.

Final prompt was the supplied brief, with only the corrupted dash punctuation normalized.