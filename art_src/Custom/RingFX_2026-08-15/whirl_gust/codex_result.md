Done. Files saved:

- [Raw master PNG](C:/Users/asali/Projects/MMO/art_src/Custom/RingFX_2026-08-15/whirl_gust/whirl_gust_master_v1.png)
- [Keyed RGBA PNG](C:/Users/asali/Projects/MMO/art_src/Custom/RingFX_2026-08-15/whirl_gust/whirl_gust_master_v1_keyed.png)

Validation:

- Raw size: `1536×1024`.
- Frames 1–8: all present; each sequential frame is visibly different.
- Exact 15° rotation: not verifiable; the generated silhouettes drift.
- Centre/size consistency: failed. Bottom-row rings are approximately 20 px higher than top-row rings, and effect bounds vary.
- Missing/extra cells: none.
- Overlap/touching: none.
- Ground plane/shadow: none.
- Chroma key: failed exactness. Background is magenta but not uniform `#ff00ff`; the helper sampled `#ef1ae1`.
- Key-colour contamination: minor magenta/off-palette antialiasing existed in the raw effect; the keyed result was rerun with `--edge-contract 1` to reduce it.
- No slicing, installation, or writes outside the staging directory were performed.

Used built-in ImageGen plus its required chroma-key helper; no CLI fallback.