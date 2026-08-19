Generated one sheet using the built-in `image_gen` tool.

Files:

- [Raw master PNG](C:\Users\asali\AppData\Local\Temp\claude\C--Users-asali-Projects-MMO\e9942dba-d052-4194-9824-a200aaaa6d1b\scratchpad\pcmobs\fungus_immature_attack\fungus_immature_attack_master_v1.png)
- [Keyed RGBA PNG](C:\Users\asali\AppData\Local\Temp\claude\C--Users-asali-Projects-MMO\e9942dba-d052-4194-9824-a200aaaa6d1b\scratchpad\pcmobs\fungus_immature_attack\fungus_immature_attack_master_v1_keyed.png)

Audit:

- Raw output: **1254×1254 RGB**, unresized.
- Complete poses: **4**.
- Quadrant containment: **Yes**. All figures, cap edges, and spores remain inside their quadrants; minimum substantive gutter is approximately **90 px**.
- Strike direction: **LEFT**, clearly indicated by the lunge and spores.
- Ready height match: **No**. Ready is approximately **365 px tall**, versus roughly **174 px** in Image 1—about **2.1× too large**.
- Other defect: the raw background is **not uniform `#00ff00`**. It varies around green (`#06f80b` sampled), with zero pixels exactly `#00ff00`. The keyed derivative removes it with border auto-keying, soft matte, and despill.
- Identity/style are recognizable but not pixel-perfect; spot placement and pixel clustering drift from Image 1.

The final prompt preserved the supplied brief, adding the measured 174-pixel ready-height target and explicitly resolving the contradictory weapon wording as **no arms/no weapon**. No slicing or MMO-project writes were performed.