Generated once with the built-in `image_gen` tool and saved:

- [Raw master PNG](C:/Users/asali/AppData/Local/Temp/claude/C--Users-asali-Projects-MMO/e9942dba-d052-4194-9824-a200aaaa6d1b/scratchpad/pcmobs/mummy_warrior_attack/mummy_warrior_attack_master_v1.png)
- [Keyed RGBA PNG](C:/Users/asali/AppData/Local/Temp/claude/C--Users-asali-Projects-MMO/e9942dba-d052-4194-9824-a200aaaa6d1b/scratchpad/pcmobs/mummy_warrior_attack/mummy_warrior_attack_master_v1_keyed.png)

Audit:

- Raw size: **1254 × 1254**, RGB, unresized.
- Complete poses: **4**, all distinct.
- Quadrant containment: **Yes**. All bodies, weapons, and the strike arc remain inside their quadrants. Smallest measured gutter is approximately 30 px.
- Strike direction: **LEFT**, as required.
- Ready-pose height match: **No**. Reference height is 151 px; generated ready pose is approximately 411 px—about **2.72× too tall**.
- Per-row ground lines align, but torso positions are not locked.
- Raw background fails the specification: it is mottled green, not uniform `#00ff00`. Only 5 pixels exactly match `#00ff00`; auto-key sampled `#06f908`.
- The strike arc is too large, pale, and prominent—not short, dull, and low-contrast.
- Character identity drifted bulkier, with thicker outlines and altered equipment proportions. The pixel treatment does not precisely match Image 1.
- Keyed output was produced with automatic border sampling, soft matte, and despill.
- No slicing, installation, or MMO-project writes were performed.

Final prompt preserved the supplied brief, with only explicit row-major pose placement and raw-background opacity added.