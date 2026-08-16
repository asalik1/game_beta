Done using built-in imagegen.

- [Raw master PNG](C:\Users\asali\Projects\MMO\art_src\Custom\SkinFX_2026-08-15\gilded_iai\gilded_iai_master_v1.png)
- [Keyed RGBA PNG](C:\Users\asali\Projects\MMO\art_src\Custom\SkinFX_2026-08-15\gilded_iai\gilded_iai_master_v1_keyed.png)

Findings:

- Raw size: 1448×1086, not the requested 1536×1024.
- Frames: all 8 are present and visibly different.
- Centering: broadly stable per cell.
- Size: intentionally changes across the storyboard; not uniform.
- Defect: frames 3 and 4 abut at the column seam, violating the requested broad magenta gap; no overlap detected.
- No extra/missing cells, ground plane, weapons, text, or obvious key color inside the effect.
- Background is near-magenta but not perfectly uniform `#ff00ff`; auto-key sampled `#f90af6`.
- Keyed output has valid transparency and transparent corners.