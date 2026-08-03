# Moonstone regeneration — 2026-08-02

The old `rv_mat_gem_moon.png` was a 22×22 Raven icon. The Codex displays
curio art at 48×48 with nearest-neighbour filtering, so the old crystal's
source pixels became the dominant visual feature.

## Source files

- `moonstone_keyed.png` — untouched built-in ImageGen output on a green key.
- `moonstone_alpha_master.png` — background-removed production master. The
  installed chroma-key helper used border auto-keying, tolerance 56, despill,
  and a one-pixel edge contraction to retain the blue-white crystal interior.

The screenshot supplied by the owner was a scale, silhouette, camera, and
finish reference only. The old 22 px Moonstone was explicitly a negative
quality reference; its blocky execution was not preserved.

## Final generation prompt

```text
Use case: stylized-concept
Asset type: game-ready dark-fantasy inventory/world prop sprite for Crownless
Input image: Image 1 is the in-game context and current low-resolution Moonstone; use it only for scale, overall upright silhouette, camera angle, and the surrounding game's somber painted rendering. Do not preserve its pixelated execution.
Primary request: Create one much cleaner high-resolution Moonstone sprite: a compact upright cluster of smooth translucent moonstone crystal, with one taller central shard and two or three smaller supporting facets. It should feel cloudy in daylight and lit from within by cold moonlight, with pearly blue-white opalescence, restrained lavender undertones, subtle internal glow, and a small dark stone base. Make it clearly distinct from a saturated purple amethyst.
Style/medium: polished hand-painted 2D dark fantasy game sprite, crisp anti-aliased silhouette, clean painterly facets, readable at 64–96 px, matching the detailed armored character in the reference; not pixel art, not photorealistic, not chibi.
Composition/framing: centered single object, three-quarter front view, symmetrical-enough compact silhouette, generous padding, no cropping.
Lighting/mood: cool moonlit inner glow, restrained highlights, somber and mysterious.
Scene/backdrop: perfectly flat solid #00ff00 chroma-key background for background removal. The background must be one uniform color with no shadows, gradients, texture, reflections, floor plane, or lighting variation.
Constraints: one object only; no cast shadow, no contact shadow, no reflection; no text, runes, frame, UI, pedestal, scenery, particles, aura outside the silhouette, or watermark. Keep crisp clean edges fully separated from the background. Do not use #00ff00 anywhere in the subject.
Avoid: blocky pixels, nearest-neighbor pixel art, black square outline, neon saturation, oversized fantasy crystal monument, jewelry setting, orb, gemstone icon border.
```

## Build

Run with the workspace Python runtime that provides Pillow:

```powershell
python tools/art/build_moonstone.py
```

The builder crops the visible master, downsamples it with Lanczos into a
128×128 transparent runtime cell, and bottom-anchors the stone. It writes only
`game/assets/sprites/rv_mat_gem_moon.png`; mobile receives the result through
the standard desktop-to-mobile sync.
