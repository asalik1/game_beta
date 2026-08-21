Generated exactly once with built-in ImageGen.

Files:

- [Raw master](C:/Users/asali/Projects/MMO/art_src/boss_qa_fix_2026-08-18/vargoth/walk8/s/walk8_master_1x8_v1.png) — **2172 × 724 px**
- [Keyed RGBA](C:/Users/asali/Projects/MMO/art_src/boss_qa_fix_2026-08-18/vargoth/walk8/s/walk8_master_1x8_v1_keyed.png) — **2172 × 724 px**

Observed leading foot, using anatomical left/right:

1. Left
2. Left
3. Left
4. Left
5. Left
6. Left
7. Right
8. Left

Blunt QA: the walk fails the required alternation. Frame 5 is not a mirror of frame 1; most poses retain the left foot forward, and several read as high-knee marching. Frames 3 and 7 are not convincing crossed-leg passing poses. The sheet is approximately 3:1 rather than 8:1, its width is not divisible by eight, and therefore it does not contain eight directly usable equal square cells. Figures also drift horizontally and occupy roughly 44% of the canvas height instead of 66%.

Identity, front facing, armor, palette, and weapon side/angle are fairly consistent. No extra limbs or outer-edge clipping were observed. The raw background is neither uniform nor exact `#00ff00`; auto-key detected approximately `#05f809`. The keyed result used border sampling, soft matte, and despill, with no green-dominant visible rim detected.