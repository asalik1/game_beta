Created:

- [hazard_slow_master_v1.png](C:/Users/asali/Projects/MMO/art_src/Custom/HazardFX_2026-08-15/hazard_slow/hazard_slow_master_v1.png)
- [hazard_slow_master_v1_keyed.png](C:/Users/asali/Projects/MMO/art_src/Custom/HazardFX_2026-08-15/hazard_slow/hazard_slow_master_v1_keyed.png)

Validation:

- Raw size: **1254×1254**, not the requested 1024×1024. No resizing performed.
- All four frames are visibly different and follow the bubble/swirl storyboard.
- Centre and size are held consistently; bbox drift is under 1 pixel. Outlines are not pixel-identical.
- Cells do not overlap or touch. No extra cell, separators, text, watermark, or ground plane.
- Major deviation: background is not perfectly uniform `#00FF00`; it contains many green shades.
- Patch width is about 90% of each cell, larger than the requested ~80%.
- Raw edge antialiasing contains green contamination. The keyed/despill result removes detectable green cast from the effect body.