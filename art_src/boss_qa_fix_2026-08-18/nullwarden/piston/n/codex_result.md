Generated with built-in ImageGen:

- [Raw master PNG](<C:\Users\asali\Projects\MMO\art_src\boss_qa_fix_2026-08-18\nullwarden\piston\n\piston_master_2x2_v1.png>) — **1254×1254 px** RGB; four 627×627 cells.
- [Keyed RGBA PNG](<C:\Users\asali\Projects\MMO\art_src\boss_qa_fix_2026-08-18\nullwarden\piston\n\piston_master_2x2_v1_keyed.png>) — 1254×1254 px, auto-keyed with despill.

All four poses are visibly different:

1. Wind-up: fist drawn sideways.
2. Load: fist raised overhead.
3. Thrust: arm extended laterally.
4. Recover: arm bent and partially retracted.

Blunt defect report:

- **Severe:** frame 1 uses the opposite arm from frames 2–4.
- **Severe:** frame 3 thrusts toward screen-right, not away toward the top.
- Bottom-row feet are about **31 px higher** than the top row, violating the fixed-anchor rule.
- Backdrop is not uniform `#00ff00`; auto-key sampled `#06f804`, with thousands of green shades. Only four raw pixels are exactly `#00ff00`.
- Detached cyan sparkles surround the body in every frame, violating the effects rule. None touch a cell edge.
- The keyed output retains a visible green fringe.
- Character is recognizable but off-model: more upright proportions and altered back/cloth rune markings.
- Back view is correct overall; no face, weapon, extra limbs, or extra heads are visible.

No slicing or installation was performed.