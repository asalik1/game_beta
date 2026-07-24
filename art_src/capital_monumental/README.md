# Crownfall monumental architecture

These project-bound source images were generated with Codex's built-in image
generation tool on 2026-07-24. They are original Crownfall architecture; the
user's MMO-city screenshots were used only for high-level lessons about strong
silhouette, enclosure, district hierarchy, and processional entrances.

## Crown Spire Gate

Reference roles:

- `game/assets/sprites/capital_emberward_gate.png`: Crownfall palette,
  materials, pixel-art rendering, and elevated camera.
- `game/assets/sprites/capital_chartered_hall.png`: masonry, line weight, and
  architectural detail.
- `tmp/capital_audit_before/room_00_crown_plaza.png`: current in-game scale and
  the empty north edge the landmark needed to anchor.

Prompt summary: an original monumental Crownfall plaza gate with one tall
crown-shaped central spire, lower flanking towers, stairs and buttresses, an
open traversable central arch, charcoal ironstone, brass, restrained crimson,
and integrated civic firelight. Isolated on flat `#ff00ff`; no people, text,
watermark, closed portcullis, ground plane, or copied game iconography.

Built-in output:
`capital_crown_spire_gate_source.png`

Chroma-keyed source:
`capital_crown_spire_gate_keyed.png`

## City Arcade

Reference roles:

- the generated Crown Spire Gate: premium material and architectural language;
- `game/assets/sprites/capital_chartered_hall.png`: camera and pixel-art style;
- `tmp/capital_audit_before/room_05_crown_bazaar.png`: the empty city edge to
  frame.

Prompt summary: an original continuous, very wide Crownfall arcade of connected
townhouses and battlements with an open central road arch, roof variation,
enclosed warm windows, brass, and restrained crimson banners. It is explicitly
background architecture: no shops, signs, accessible-looking standalone doors,
people, exposed flames, ground plane, text, or watermark. Isolated on flat
`#ff00ff`.

Built-in output:
`capital_city_arcade_source.png`

Chroma-keyed source:
`capital_city_arcade_keyed.png`

## Production build

Run `tools/art/build_capital_monumental.py` in an environment with Pillow. It
normalizes the two sources and creates:

- `game/assets/sprites/capital_crown_spire_gate.png`
- `game/assets/sprites/capital_crown_spire_gate_anim.png`
- `game/assets/sprites/capital_city_arcade.png`

The gate's ten exposed flames animate inside the full structure strip. The
arcade contains no exposed flame and remains static.
