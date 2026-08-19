Generated one sheet with the built-in ImageGen tool.

Files:

- [Raw master](C:/Users/asali/AppData/Local/Temp/claude/C--Users-asali-Projects-MMO/e9942dba-d052-4194-9824-a200aaaa6d1b/scratchpad/pcmobs/zombie_overweight_walk/zombie_overweight_walk_master_v1.png) — 2172×724 RGB, unresized
- [Keyed master](C:/Users/asali/AppData/Local/Temp/claude/C--Users-asali-Projects-MMO/e9942dba-d052-4194-9824-a200aaaa6d1b/scratchpad/pcmobs/zombie_overweight_walk/zombie_overweight_walk_master_v1_keyed.png) — RGBA, auto-key sampled, soft matte and despill enabled

Eight complete figures were produced.

| Frame | Observed gait |
|---|---|
| f1 | Screen-left/apparent near foot leads; contact-like. |
| f2 | Same foot remains forward; load phase is weak. |
| f3 | Same foot remains forward; required FAR-leg passing/lift is absent. |
| f4 | Screen-left foot still appears forward; FAR-foot reach is unclear. |
| f5 | Same apparent leg leads as f1—not the required opposite leg. |
| f6 | Same forward-foot arrangement; FAR-foot load is not convincing. |
| f7 | Same side advances as f3; required opposite NEAR-leg pass is absent. |
| f8 | Close stance, but the opposite reaching leg is not clearly shown. |

Blunt defect audit:

- f1 versus f5: **fails**—opposite leading legs are not readable.
- f3 versus f7: **fails**—neither is a clear passing pose, and they do not show opposite passing legs.
- Body height: proportions and upright silhouette broadly match Image 1, but literal scale does not. Reference figures are 177–178 px tall; generated figures are 336–345 px tall. Within this sheet the head drifts downward by 7 px and height varies by 9 px, with f7/f8 visibly lower.
- Ground line: f2, f4, and f7 end approximately 3 px above the common y=515 baseline.
- Raw backdrop: **fails the exact background constraint**. It contains 254 sampled green shades and no exact `#00ff00` pixels in the upper background sample. The keyed deliverable removes this variation.
- No extra limbs, missing limbs, wrong-facing figures, exact duplicate pair, overlaps, cropping, scenery, text, or shadows were found.
- All figures face left. Inter-figure gutters are 42–76 px; canvas-edge gaps are 61 px left and 54 px right.

The final prompt was the supplied brief normalized into the imagegen skill’s labeled schema without substantive creative changes. Nothing was sliced, installed, or written under the MMO project.