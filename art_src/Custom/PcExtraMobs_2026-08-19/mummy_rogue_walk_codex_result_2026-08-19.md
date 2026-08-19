Generated once with built-in imagegen. No slicing or MMO-project writes were performed.

Files:

- [Raw master](C:/Users/asali/AppData/Local/Temp/claude/C--Users-asali-Projects-MMO/e9942dba-d052-4194-9824-a200aaaa6d1b/scratchpad/pcmobs/mummy_rogue_walk/mummy_rogue_walk_master_v1.png) — **2172×724 RGB**, exact unresized copy
- [Keyed master](C:/Users/asali/AppData/Local/Temp/claude/C--Users-asali-Projects-MMO/e9942dba-d052-4194-9824-a200aaaa6d1b/scratchpad/pcmobs/mummy_rogue_walk/mummy_rogue_walk_master_v1_keyed.png) — **2172×724 RGBA**, border auto-key + despill + soft matte

Exactly **8 complete figures** were produced.

| Frame | Leg/gait result |
|---|---|
| f1 | Foreground/near-looking leg leads toward screen-left; rear leg trails. |
| f2 | Same near-looking leg still leads; reasonable load variant. |
| f3 | Same leg remains planted forward. FAR-leg pass is missing. |
| f4 | Legs close/cross; no unambiguous leader. Resembles a pass rather than the requested reach. |
| f5 | Same screen-left/near-looking leg appears to lead again. **Not visibly opposite to f1.** |
| f6 | Same lead-leg arrangement continues. |
| f7 | Legs close/cross; pass-leg depth is ambiguous. **Does not demonstrate an opposite pass to f3**, which was not a pass pose. |
| f8 | Screen-left leg is already forward and grounded, not clearly reaching with heel about to touch. |

Blunt defect report:

- **Body scale fails:** generated figures are 261–268 px tall versus 146–150 px in Image 1—about **1.8× too large**.
- Head height shifts by 7 px; body height is not fully locked.
- Raw background is not flat `#00ff00`: only 2 pixels are exact green. Auto-key sampled `#07f809`.
- The required alternating two-step cycle is not present. f1–f3 and f5–f6 are functionally near-duplicate stances.
- f5’s planted foot is approximately 2 px above the shared ground line.
- Gutters vary from roughly 55–86 px, so spacing is not even.
- Black outlines are visibly thicker than one output pixel.
- No exact pixel-identical pair was found, but several poses are effectively duplicated.
- All figures face left; none touch another or the canvas edge. No cropping, detached feet, or extra limbs are visible. Each figure appears to retain two knives.

The final prompt was the supplied brief normalized into the imagegen skill’s labeled schema, with all storyboard and exclusion constraints preserved.