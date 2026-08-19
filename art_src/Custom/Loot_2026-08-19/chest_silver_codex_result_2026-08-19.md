Created one source sheet with the built-in `image_gen` tool. No slicing or MMO-project writes occurred.

Files:

- [Raw master](C:\Users\asali\AppData\Local\Temp\claude\C--Users-asali-Projects-MMO\e9942dba-d052-4194-9824-a200aaaa6d1b\scratchpad\loot\chest_silver\chest_silver_open_master_v1.png) — 1774×887 RGB PNG
- [Keyed master](C:\Users\asali\AppData\Local\Temp\claude\C--Users-asali-Projects-MMO\e9942dba-d052-4194-9824-a200aaaa6d1b\scratchpad\loot\chest_silver\chest_silver_open_master_v1_keyed.png) — RGBA, auto-border key sampling, soft matte and despill

QA:

- Exactly five complete figures; none touch or are cropped.
- Body stability: imperfect. Baseline varies only one pixel, but the open frames shift horizontally by roughly 8–9 pixels and some plate, lock, and colour details redraw.
- Lid progression: yes, f1–f4 progressively open and f5 holds fully open.
- f3 is closer to 30° than the requested 45°.
- f4 has no visible sparkle motes. Its glow is only slightly brighter than f5.
- Background fails the brief: sampled as `#05f808`, contains colour variation, and has no exact `#00ff00` pixels in the tested clear area.
- Strong dark contours and glossy, semi-cartoon/game-icon shading remain; they do not precisely match the softer, outline-free painterly references.
- Raw glow edges contain green contamination. The keyed file removes strong green, though slight yellow-green fringe pixels remain.

The supplied prompt was used unchanged in substance; corrupted punctuation was normalized to em dashes and degree symbols.