Generated exactly one sheet with built-in ImageGen using the supplied prompt and references.

Files:

- [Raw master](C:\Users\asali\Projects\MMO\art_src\boss_qa_fix_2026-08-18\vargoth\walk\e_r1\walk_master_2x2_v1.png) — 1254×1254 RGB
- [Keyed master](C:\Users\asali\Projects\MMO\art_src\boss_qa_fix_2026-08-18\vargoth\walk\e_r1\walk_master_2x2_v1_keyed.png) — 1254×1254 RGBA

Pose report:

- Frame 1: broad contact stride.
- Frame 2: compact passing/crossed-leg pose.
- Frame 3: visibly different broad stride, but it does not convincingly show the opposite leg leading versus frame 1.
- Frame 4: distinct passing pose, though similar to frame 2.

Defects:

- Raw background is not uniform `#00ff00`; it contains zero exact `#00ff00` pixels and was auto-sampled as `#0af80e` with nearby variations.
- Bottom-row figures are shifted upward roughly 20 px relative to the top row, violating the fixed-anchor rule.
- Frames 1 and 3 do not clearly alternate leg lead.
- The two-handed grip is unclear and often reads as one-handed.
- Crown, armor markings, and weapon handling vary slightly between frames, so the strict identity lock is imperfect.
- No extra heads or obvious extra limbs. All four face right. Nothing touches the canvas or cell edges.
- Keying used auto-border sampling, soft matte, and despill. The keyed output has no remaining green-dominant visible pixels.