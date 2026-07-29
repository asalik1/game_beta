# Act 2 creature sprite masters

These 59 masters cover the documented Chapter 8–14 mob roster plus every
distinct boss, boss form, and boss-scale encounter body currently called for
by `PROPOSALS/ACT2_BOSS_KITS.md`. Kaethra's spared form continues to use her
existing canonical art instead of duplicating the character.

The masters were generated with the built-in ImageGen tool on 2026-07-29,
using `art_src/Custom/MobRedesign_2026-07-25/royal_knight_master.png` only as
the Crownless rendering/layout reference.

## Canonical prompt contract

- Exact label-free 4x4 sheet on a flat green or magenta chroma background.
- Same subject in all sixteen cells: idle, walk/drift, attack/ability, defeat.
- Four equal centered cells per row; no grid, text, UI, scenery, or shadows.
- Humanoids visibly alternate left/right legs; quadrupeds alternate diagonal
  leg pairs. Stationary and floating bodies use a deliberate drift/pulse row.
- Identity, face, silhouette, costume, colors, handedness, and equipment are
  locked across all frames.
- A held weapon is exactly one persistent object with a fixed shape, size,
  grip, hand, and details. It may be released only during the defeat sequence,
  where it must remain visibly the same object.

The approved sources include targeted corrections where first passes failed
that contract, notably Pollen Drifter's defeat progression, Choir Ascendant's
walk row, and the Korrag/Grael attack cells that initially hid their flails.
The stricter locomotion/continuity pass on 2026-07-29 also replaced the
opposite-phase walk keyframe for 29 humanoid, quadruped, and multi-legged
actors. Those repairs were generated as isolated full-body keyframes so the
advancing foot or diagonal leg set stayed readable at the installed 192px
cell size, then normalized back to the original frame's scale and baseline.
A follow-up locomotion review rejected 17 of the humanoid repairs for
overstated high-knee marching. Their replacement keyframes keep the free foot
within a low 4-8% body-height clearance, the thigh well below horizontal, and
the figure aligned to the other three walk frames' median height, center, and
ground line. The chapter walk sheets and armed-boss continuity sheet were
regenerated from the installed strips after that correction.
Cindersmith, Oathbound Knight, Sand Revenant, and Shardcaller received
isolated attack-frame corrections so their documented equipment remains
present and in the same hand throughout the clip.

The builder removes small disconnected fragments that ImageGen sometimes
lets cross any boundary of a neighboring animation cell while preserving
substantial detached props such as flail heads and censers. The engine-ready
outputs are reproducible with:

```text
python tools/art/build_act2_sprites.py
```

For a targeted rebuild after one master changes:

```text
python tools/art/build_act2_sprites.py --keys korrag_reborn thornfather_grael
```

Canonical keys and chapter/type metadata live in
`game/assets/act2_visual_catalog.json`. The dev-only in-engine review rig is
`game/shot_act2_art.tscn`.
