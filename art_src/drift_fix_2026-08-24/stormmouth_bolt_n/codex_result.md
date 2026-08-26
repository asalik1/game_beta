Generated and keyed the sprite sheet using built-in ImageGen only.

- Raw: [bolt_master_2x2_v1.png](<C:\Users\asali\Projects\MMO\art_src\drift_fix_2026-08-24\stormmouth_bolt_n\bolt_master_2x2_v1.png>) — **1254×1254 px**, unresized.
- Keyed RGBA: [bolt_master_2x2_v1_keyed.png](<C:\Users\asali\Projects\MMO\art_src\drift_fix_2026-08-24\stormmouth_bolt_n\bolt_master_2x2_v1_keyed.png>) — border auto-key, soft matte, despill enabled.

Per-cell audit:

- TL: **BACK view, face hidden**. Wind-up reads correctly. Two arms/two legs; no edge contact.
- TR: **BACK view, face hidden**. Gather pose and orb are clear. No extra limbs or edge contact.
- BL: **BACK view, face hidden**. Strongest strike pose, arm thrust up-and-away. Effect comes within roughly 10 px of the cell top but does not touch it.
- BR: **BACK view, face hidden**. Recover pose with fading motes. No extra limbs or edge contact.

Blunt issues:

- Anchor lock failed: right-column figures sit roughly 45–50 px left of the left-column anchors; the bottom row sits about 41 px higher than the top row.
- Body scale is otherwise consistent.
- Mild identity drift: the titan is broader and more symmetrical than Image 1; rear armor is partly inferred, and the chest core itself is hidden, leaving only cyan seam energy.
- The raw background is not truly uniform `#00ff00`: only 5 pixels are exact `#00ff00`, with many near-green variations around sampled `#06f805`. The keyed derivative removes it successfully.
- No front/three-quarter frames, extra limbs, separators, or effects touching an edge.

Nothing was sliced or installed elsewhere.