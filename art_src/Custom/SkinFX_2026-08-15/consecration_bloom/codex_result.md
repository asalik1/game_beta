Generated and saved:

- [consecration_bloom_master_v1.png](C:/Users/asali/Projects/MMO/art_src/Custom/SkinFX_2026-08-15/consecration_bloom/consecration_bloom_master_v1.png)
- [consecration_bloom_master_v1_keyed.png](C:/Users/asali/Projects/MMO/art_src/Custom/SkinFX_2026-08-15/consecration_bloom/consecration_bloom_master_v1_keyed.png)

Audit:

- Raw size: 1536×1024 RGBA.
- All 8 cells are present and visibly different.
- No cells overlap, touch, or are missing; no extra cell.
- Circle size and placement are approximately consistent, but not perfectly pixel-locked; minor irregular-edge/mote drift exists.
- No magenta pixels remain inside the visible keyed effect.
- No text, characters, weapons, or ground texture.
- Defect: the generated raw sheet did not use flat `#ff00ff`; it contained a brown atmospheric backdrop/low-opacity body. The helper keyed sampled `#83613d`, not magenta, and removed much of the faint interior field. The final keyed result is primarily pale rings, rays, and motes rather than the full intended soft field.