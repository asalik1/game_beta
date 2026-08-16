Created in the staging directory:

- [rage_burst_master_v1.png](C:/Users/asali/Projects/MMO/art_src/Custom/HazardFX_2026-08-15/rage_burst/rage_burst_master_v1.png)
- [rage_burst_master_v1_keyed.png](C:/Users/asali/Projects/MMO/art_src/Custom/HazardFX_2026-08-15/rage_burst/rage_burst_master_v1_keyed.png)

Audit:

- Raw size: 1536×1024 RGB.
- Keyed size: 1536×1024 RGBA.
- Frames 1→2 through 7→8: visibly different.
- Exactly 8 cells; none missing, overlapping, or touching.
- No extra cell, ground plane, text, character, weapon, or separator.
- Centres are approximately stable, but not pixel-perfect; frames 1–4 drift slightly left.
- Effect size changes as storyboarded, but frames 1–4 are oversized: roughly 49%, 78%, 94%, and 96% of cell width instead of 30%, 55%, 80%, and 85%.
- Raw background is not exact `#00ff00`; it is near-green and varies. The keyed output retains a minor olive/green fringe: 11 strongly green visible pixels.
- Frame 4 has only about 12 px of right-edge margin, not the requested broad margin.