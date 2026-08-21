Generated exactly once with the built-in ImageGen tool. No slicing or installation was performed.

Files:

- [Raw master](/C:/Users/asali/Projects/MMO/art_src/boss_qa_fix_2026-08-18/nullwarden/idle/idle_master_2x2_v1.png) — **1254×1254 px**, copied byte-for-byte without resizing.
- [Keyed RGBA master](/C:/Users/asali/Projects/MMO/art_src/boss_qa_fix_2026-08-18/nullwarden/idle/idle_master_2x2_v1_keyed.png) — auto-key sampled, despill enabled.

All four poses visibly different: **No.**

- Frame 1: neutral idle.
- Frame 2: visibly taller/broader inhale; also improperly resized.
- Frame 3: near-duplicate of frame 1 with minor redraw/particle changes.
- Frame 4: near-duplicate of frame 3; not a convincing exhale.

Defects:

- Severe anchor drift: bottom-row figures sit roughly **48–50 px higher**; right-column figures shift roughly **52 px left** after cell cropping.
- Body height varies from **421 to 436 px** and occupies only about **67–70%** of each cell, not 74%.
- Character is off-model: armor/helmet details drift, including a new large white chest emblem and altered waist details.
- Background is not flat `#00ff00`: only 7 pixels exactly match that color, and the outer border contains 172 colors.
- Keyed output retains a conspicuous neon-green rim and green pixels at outer edges/corners despite despill.
- Correctly contains four front-facing figures, four heads, no extra limbs, and no sword or other weapon.
- No intended blue effect touches an edge.