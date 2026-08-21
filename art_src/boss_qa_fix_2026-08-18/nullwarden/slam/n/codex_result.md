Created with one built-in ImageGen call:

- [Raw 2×2 master](<C:/Users/asali/Projects/MMO/art_src/boss_qa_fix_2026-08-18/nullwarden/slam/n/slam_master_2x2_v1.png>) — **1254×1254 px**, byte-identical copy of the generated PNG.
- [Keyed RGBA master](<C:/Users/asali/Projects/MMO/art_src/boss_qa_fix_2026-08-18/nullwarden/slam/n/slam_master_2x2_v1_keyed.png>) — auto-key sampling and despill enabled.

All four poses are visibly different:

1. Rear-view bent-arm wind-up.
2. Rear-view peak with fists raised higher.
3. Low slam pose.
4. Rear-view recovery with fists lifting.

Blunt defect report:

- **Frame 3 is wrong-facing:** its face and glowing eyes are visible.
- Frame 3 includes a substantial ground-impact burst, violating the body-only/effect override.
- The raw background is **not uniform `#00ff00`**. Auto-key sampled `#04f90b`; only 9 pixels were exactly `#00ff00`.
- The keyed result retains a conspicuous opaque green rim/residue—about 19,000 green-dominant pixels.
- Significant anchor drift: frames 1/3 sit roughly 50–60 px right of frames 2/4, while frames 3/4 have a feet baseline about 50 px higher.
- The rear plate appears to reuse the front chest rune, so the back design is likely inferred/off-model.
- No weapons, extra limbs, extra heads, cell overlap, separators, or edge-touching effects were observed.

No files outside the staging directory were written.