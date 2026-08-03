# Crafting material icon sources

Generated on 2026-07-30 with Codex built-in image generation for the 35
materials in `PROPOSALS/MATERIALS.md`.

The shared prompt contract was:

- Crownless 32x32 fantasy RPG inventory material sprite.
- Crisp hand-painted pixel art with a deliberately low-resolution look.
- Limited palette, chunky readable pixels, and a strong near-black outline.
- One centered material object with a compact silhouette and even padding.
- A perfectly flat `#ff00ff` background with no shadow, frame, text, or
  watermark.
- Each grade's named object, condition, construction, palette, and lore hook
  were described explicitly so the ladder reads by silhouette rather than as
  seven recolors.

`sources/` contains the untouched generated 1024px chroma-key sources.
`game/assets/icons/materials/` contains the production 32x32 transparent PNGs.
Run `tools/art/build_material_icons.py` to rebuild the production set and the
QA contact sheet from these sources.
