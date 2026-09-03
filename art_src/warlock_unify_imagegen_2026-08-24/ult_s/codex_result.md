Generated exactly once with built-in ImageGen and saved:

- Raw: [ult_s_v1.png](/C:/Users/asali/Projects/MMO/.claude/worktrees/focused-bhaskara-90aea6/art_src/warlock_unify_imagegen_2026-08-24/ult_s/ult_s_v1.png) — **2172×724 px**, unresized.
- Keyed: [ult_s_v1_keyed.png](/C:/Users/asali/Projects/MMO/.claude/worktrees/focused-bhaskara-90aea6/art_src/warlock_unify_imagegen_2026-08-24/ult_s/ult_s_v1_keyed.png) — auto-keyed with despill and soft matte.

Blunt QA:

- Nine figures appear in one row, but they are **not nine valid equal square cells**. Width is not divisible by nine, and a true 724px-square nine-frame strip would be 6516×724. This output is therefore not cleanly slice-ready as requested.
- Poses are distinguishable, but frames 1/2/9 and 3/4 are too similar. Frame 6 is not the widest pose; frame 7 reads wider and more committed.
- The warlock remains broadly lean and faces FRONT/SOUTH in every frame. Frame 9 does not flip.
- Identity drift exists: the shoulders and flared robe are broader, the face is larger/harsher, and the chest gained a conspicuous crossed/X treatment forbidden by the brief.
- Skull and grimoire remain on consistent sides. No extra limbs, duplicate props, large detached effects, or edge-touching effects.
- Small anchor drift exists: content top varies about 8px and feet baseline about 3px. Body size is roughly 54% of canvas height, below the requested 66%.
- The raw background is **not uniform `#00ff00`**. Auto-key sampled `#06f80a`, and the supposedly empty top band contains color variation. The keyed output removes it successfully.