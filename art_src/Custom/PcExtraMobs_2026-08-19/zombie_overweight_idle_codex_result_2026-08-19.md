Generated exactly one sheet using built-in `image_gen`.

- [Raw master PNG](C:\Users\asali\AppData\Local\Temp\claude\C--Users-asali-Projects-MMO\e9942dba-d052-4194-9824-a200aaaa6d1b\scratchpad\pcmobs\zombie_overweight_idle\zombie_overweight_idle_master_v1.png) — unchanged, 1254×1254
- [Keyed RGBA PNG](C:\Users\asali\AppData\Local\Temp\claude\C--Users-asali-Projects-MMO\e9942dba-d052-4194-9824-a200aaaa6d1b\scratchpad\pcmobs\zombie_overweight_idle\zombie_overweight_idle_master_v1_keyed.png) — border auto-key, soft matte, despill enabled

Validation:

- Four complete figures produced.
- All face left in three-quarter view.
- Every figure is wholly inside its quadrant with at least 55 px of gutter; none touches an edge or neighbour.
- No extra limbs, weapons, held gear, text, shadows, or separators.
- No strong-green foreground remains in the keyed file.
- No slicing or MMO-project writes performed.

Defects:

- The raw background is not exact, uniform `#00ff00`. Auto-key sampled `#04f903`, with numerous nearby variations; only four raw pixels are exactly `#00ff00`.
- The frames show subtle pose differences with no turn or actual step, but the anchors are not locked. Right-column figures shift horizontally by approximately 43–55 px after quadrant cropping.
- Bounding-box dimensions vary by up to 6 px horizontally and 5 px vertically, with minor head/ground jitter. Therefore, the four frames do not differ solely by breathing as required.

Final prompt used the supplied brief, normalized into the image-generation skill schema without changing its creative requirements.