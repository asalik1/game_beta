# Bag icon masters — 2026-07-30

Built-in Codex image generation, generated in seven separate calls. These are
project-generated assets; no third-party license or attribution is required.

Production outputs:

| Grade | Item | Master | Installed icon |
|---|---|---|---|
| F | Frayed Pouch | `bag_F_master.png` | `game/assets/icons/bag_F.png` |
| E | Patched Satchel | `bag_E_master.png` | `game/assets/icons/bag_E.png` |
| D | Soldier's Knapsack | `bag_D_master.png` | `game/assets/icons/bag_D.png` |
| C | Knight's Rucksack | `bag_C_master.png` | `game/assets/icons/bag_C.png` |
| B | Runed Haversack | `bag_B_master.png` | `game/assets/icons/bag_B.png` |
| A | Dragonhide Duffel | `bag_A_master.png` | `game/assets/icons/bag_A.png` |
| S | Emberforged Hold | `bag_S_master.png` | `game/assets/icons/bag_S.png` |

`bag_icons_contact.png` is the nearest-neighbour 10× review sheet for the seven
installed 32×32 icons.

## Prompt contract

Shared prompt:

> Crownless game inventory sprite, final use at exactly 32x32 like the gear
> icons. Hand-authored dark-fantasy pixel art, chunky deliberate square pixels,
> crisp hard edges, limited 10–14 color palette, strong near-black one-pixel
> silhouette outline, top-left highlights. Centered single object in three-
> quarter front view, fully visible with even padding, on a perfectly flat solid
> `#ff00ff` chroma-key background. Exactly one bag; transparent-cutout-ready;
> no cast/contact shadow, text, numbers, border, UI frame, watermark, extra
> props, smooth vector gradients, or photorealism.

Per-grade subject clauses:

- F: tiny greasy brown drawstring pouch, badly frayed mouth and bottom seam,
  loose cord, lopsided and nearly worn through.
- E: small rectangular leather satchel repaired by many hands with mismatched
  patches, rough stitches, crooked flap, and worn strap.
- D: fallen-kingdom infantry canvas knapsack with practical leather straps,
  dull iron buckles, and a rolled blanket lashed beneath.
- C: broad rider's rucksack of dark oiled canvas with reinforced corners, iron
  buckles, a side pouch, and bedroll straps.
- B: deep-blue-black canvas haversack with silver-grey seams and sparse glowing
  cyan Accord ward-runes stitched around the closed flap.
- A: horizontal duffel of overlapping crimson-brown drake scales, blackened
  leather end caps, and gold-bronze reinforced seams and buckles.
- S: carryable reliquary-hold of black meteoric metal with ancient gold-bronze
  bindings, a central clasp and handle, and a narrow ember-lit seam.

## Production conversion

Each master was passed through `tools/art/clean_sprite.py` with:

```text
size=32, colors=14, thresh=70, gamma=0.82, key=(255, 0, 255)
```

That conversion removes the chroma background, keeps the largest silhouette,
hardens alpha, reduces the palette, adds the house one-pixel outline, and
normalizes the result to exactly 32×32 RGBA. The installed icons are mirrored
to `mobile/game/assets/icons/`.
