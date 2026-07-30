# Full-object terrain prop animations — 2026-07-29

These ImageGen sources replace runtime-composited motion stickers with complete
four-frame props. Each frame owns the whole object; its rigid shell, footprint,
baseline, and centre stay anchored while water, fire, void energy, spores, or
electricity changes inside it.

The `*_keyed.png` files are the original built-in ImageGen outputs. Their
chroma backgrounds were removed with the ImageGen skill's
`remove_chroma_key.py --auto-key border --soft-matte --despill` helper, producing
the transparent `<name>.png` masters consumed by
`tools/art/build_terrain_prop_anims.py`.

## Prompt contract

Every edit used the existing in-repo sprite as its visual reference and required:

- exactly four equal frames in one horizontal row;
- the complete prop at the same size, baseline, and anchored position in every
  frame;
- rigid stone, wood, and metal held stable;
- only the integrated active material animated;
- chunky, limited-palette dark-fantasy pixel art, with no painterly realism;
- a flat green, magenta, or cyan chroma-key background.

Asset-specific motion:

- `garden_fountain`: connected spout, falling streams, basin ripples;
- `spore_vent`: inner violet pulse and restrained drifting spores;
- `void_rift` / `capital_portal_depths`: contained void field and motes;
- `storm_conductor`: cyan arcs attached to the conductor prongs;
- furnace/brazier family: coals, fire, and local hot glow inside the object;
- `sewer_outfall`: wastewater connected to the pipe mouth and its own puddle.

## Rebuild

```powershell
python tools/art/build_terrain_prop_anims.py
```

The builder uses one shared crop plus footprint/baseline alignment for all four
frames and writes `<name>.png` with a matching rectangular
`<name>_anim.png` strip into `game/assets/sprites/`.
