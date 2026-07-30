# Tiered terrain-art replacement sources — 2026-07-30

This directory archives the built-in image-generation sources for every asset
listed in `TERRAIN_ART_FIX_TASK.md`.

- `*_keyed.png` is the original built-in image-tool output.
- `<name>.png` is the transparent master produced with the official
  `remove_chroma_key.py` helper.
- `tools/art/build_terrain_art_fix.py` trims, registers, palette-reduces and
  installs the production desktop/mobile sprites.

## Coverage

- Tier 1: `cottage_a`, `cottage_a2`, `cottage_b`, `stall`, `rock3`, `crypt`,
  `signpost`
- Tier 2: `keep_arch`, `camp_workbench`, `cook_grill`, `camp_bonfire`, `pillar`
- Tier 3: `banner_blue`, `banner_green`, `banner_red`, `hideout_poster`,
  `hideout_table`, `amphora`, `station_alchemy_t3`, `station_anvil_t3`

`cook_grill`, `camp_bonfire`, all three banners and `station_alchemy_t3` were
generated as four complete-object horizontal frames. Their rigid bodies and
top/bottom anchors remain fixed; only fire, cloth or contained alchemical
liquid changes.

## Prompt contract

Mode: built-in image tool, reference-image edit.

Every prompt used the existing local asset as the subject/camera reference and
one or more approved Crownless environment sprites (`capital_*`,
`rock_volcanic`, statues or `ruin_pillar`) as quality references. Shared
requirements:

- high-resolution painterly pixel art with deliberate chunky pixel clusters;
- the same three-quarter top-down camera as Crownless terrain props;
- crisp, bottom-grounded silhouette and believable attached construction;
- restrained medieval dark-fantasy palette and tactile materials;
- no photorealism, smooth 3D, heavy black outline or flat cel shading;
- one isolated subject on a flat `#ff00ff` removable chroma background;
- no floor plane, cast shadow, surrounding scene, text, logo or watermark.

Each individual prompt then described the requested object's materials,
silhouette, defects to remove, and invariants. Animated prompts additionally
required exactly four equal horizontal frames containing the complete object
at one stable scale, center and anchor.
