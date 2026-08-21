Generated and saved:

- [Raw 2×2 master](/C:/Users/asali/Projects/MMO/art_src/boss_qa_fix_2026-08-18/nullwarden/beam/e/beam_master_2x2_v1.png) — 1254×1254 px, byte-identical to the generated PNG.
- [Keyed RGBA master](/C:/Users/asali/Projects/MMO/art_src/boss_qa_fix_2026-08-18/nullwarden/beam/e/beam_master_2x2_v1_keyed.png) — auto-keyed with despill.

All four poses are visibly different:

1. Hands raised forward, small glow kindling.
2. Hands pulled together near the body, brighter charge.
3. Arms thrust fully forward, release spark.
4. Hands lowered into recovery.

Blunt defect report:

- The character is off-model: substantially taller, leaner, and less squat/colossal than Image 1, with altered proportions and simplified armor details.
- Frames 2 and 4 are closer to three-quarter views than strict right-side profile.
- Small detached cyan particles appear around the hands in every frame, violating the “nothing detached” rule.
- The raw background is not literal uniform `#00ff00`; it varies around `#09f809`. Auto-keying still removed it cleanly.
- Anchoring is good: local tops vary only y=98–99 and bottoms y=514–515. No meaningful resizing or camera slide.
- No sword, weapon, traveling beam, edge-touching effect, extra limbs, or extra heads.
- Final prompt followed the supplied brief, explicitly resolving “front-facing” as reference-only and enforcing right-profile output plus the projectile override.