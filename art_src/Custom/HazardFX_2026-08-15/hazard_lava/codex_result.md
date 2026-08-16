Done using built-in `image_gen`; no slicing, resizing, installation, or MMO-project writes.

- [Raw PNG](C:\Users\asali\Projects\MMO\art_src\Custom\HazardFX_2026-08-15\hazard_lava\hazard_lava_master_v1.png)
- [Keyed RGBA PNG](C:\Users\asali\Projects\MMO\art_src\Custom\HazardFX_2026-08-15\hazard_lava\hazard_lava_master_v1_keyed.png)

Audit:

- Raw size: **1254×1254**, not requested 1024×1024.
- Frames: **all four visibly different** and follow the bubble/crack storyboard.
- Anchor: base pool remains centered and similarly sized; no camera drift.
- Cells: no missing, extra, overlapping, or touching cells.
- Ground plane/texture/shadow: none.
- Defects: background is visibly gradient/non-uniform instead of flat `#00ff00`; auto-key sampled `#05f90b`. The keyed result retains a visible green-yellow fringe around pool edges. No solid green appears inside the lava body.
- Style is crisp and readable, though somewhat glossier/more rendered than the reference strip.