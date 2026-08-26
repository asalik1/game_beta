Generated exactly one sheet using built-in ImageGen.

Files:

- [Raw PNG](C:/Users/asali/Projects/MMO/art_src/drift_fix_2026-08-24/saint_varo_standing_ability_s/ability_master_2x2_v1.png) — 1254×1254 RGB, 1,577,217 bytes
- [Keyed PNG](C:/Users/asali/Projects/MMO/art_src/drift_fix_2026-08-24/saint_varo_standing_ability_s/ability_master_2x2_v1_keyed.png) — 1254×1254 RGBA, 925,511 bytes

Per-cell audit:

- TL: broad two-handed greatsword; gold-and-purple light, not green.
- TR: same greatsword raised overhead in both hands; gold-and-purple light, not green.
- BL: same greatsword in the downward strike; large gold-purple burst, not green.
- BR: same greatsword returning to guard; dimmer gold-purple light, not green.

Blunt drift report:

- Character and weapon identity are strong; all four poses are distinct.
- Anchoring fails the brief: top-row figures sit lower than bottom-row figures and touch/cross the horizontal cell boundary. There is no clean broad horizontal gutter.
- The overhead sword has only about two pixels of top clearance, and it obscures the skull/crown.
- Raw background fails the literal color lock: it is varied around `#07f909`, not uniform `#00ff00`; only three raw pixels are exactly `#00ff00`.
- Keying used border auto-key, soft matte, and despill. QA found zero green-dominant visible foreground pixels afterward.

Nothing was sliced or installed into game assets. The final prompt preserved the supplied brief with Image 1 as the binding identity/weapon reference and Image 2 as pose support only.