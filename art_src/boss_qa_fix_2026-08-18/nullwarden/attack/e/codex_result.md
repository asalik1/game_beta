Generated exactly one sheet with built-in ImageGen.

Files:

- [Raw master](/C:/Users/asali/Projects/MMO/art_src/boss_qa_fix_2026-08-18/nullwarden/attack/e/attack_master_2x2_v1.png) — **1254×1254 px**, copied byte-for-byte without resizing
- [Keyed RGBA master](/C:/Users/asali/Projects/MMO/art_src/boss_qa_fix_2026-08-18/nullwarden/attack/e/attack_master_2x2_v1_keyed.png) — 1254×1254 px

All four poses are visibly different:

- Frame 1: guarded wind-up
- Frame 2: deeper energy-gather pose
- Frame 3: large committed forward punch
- Frame 4: retracted recovery pose

Defects:

- Frames 1, 2, and 4 are three-quarter right views, not strict full right profiles.
- The character is recognizable but not exact; helmet, armor shapes, and proportions were reinterpreted.
- Detached cyan sparks appear in frames 2 and 3, violating the body-only effect rule.
- The raw background is sampled as `#0bf805`, not exact `#00ff00`.
- The keyed result has a conspicuous bright-green fringe despite despill.
- Minor head-anchor drift exists between frames.
- No weapon, extra limb, extra head, edge-touching effect, or cell overlap was found.

The final prompt preserved your brief while explicitly treating strict right-profile and unarmed requirements as overrides. Nothing was sliced or installed.