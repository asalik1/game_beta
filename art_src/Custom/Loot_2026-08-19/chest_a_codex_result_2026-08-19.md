Generated exactly one master using built-in `image_gen`; no slicing or MMO-project writes.

Files:

- [Raw master PNG](C:\Users\asali\AppData\Local\Temp\claude\C--Users-asali-Projects-MMO\e9942dba-d052-4194-9824-a200aaaa6d1b\scratchpad\loot\chest_a\chest_a_open_master_v1.png) — 2172×724 RGB
- [Keyed master PNG](C:\Users\asali\AppData\Local\Temp\claude\C--Users-asali-Projects-MMO\e9942dba-d052-4194-9824-a200aaaa6d1b\scratchpad\loot\chest_a\chest_a_open_master_v1_keyed.png) — RGBA, auto-key plus soft matte/despill

Blunt audit:

- Five complete figures: yes. None touch or crop; gutters are 91–120 px.
- Body stability: not exact. Baselines vary by 3 px and widths by 12 px; minor placement, geometry, and detail drift exists.
- Lid progression: correct from f1 closed through f4 fully open; f5 holds fully open.
- f4/f5 lighting: f5 is not clearly softer than f4. F4’s motes are extremely faint.
- Background defect: raw background is neither exact nor perfectly uniform `#00ff00`; sampled key was `#03f904`, with 131 border colors.
- Green contamination: keyed output has no detected strong-green interior pixels, but faint greenish hinge-edge residue remains.
- Style defects: thin dark outlines are present, and the finish is brighter, sharper, and more 3D/game-icon-like than the softer muted painterly benchmarks. Brass is oversaturated.
- Prompt: your supplied specification was preserved in substance, with corrupted punctuation normalized; no creative elements were added.