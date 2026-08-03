# Visual cleanup generation record — 2026-08-02

Generated with the built-in Codex ImageGen tool in `stylized-concept` mode.
No external generator or downloaded third-party art was used. Raw keyed outputs
are in `sources/`; background-removed masters are in `alpha/`. Rebuild shipped
sprites with:

```powershell
python tools/art/build_visual_cleanup.py
```

Background removal used `remove_chroma_key.py --auto-key border --tolerance 56
--edge-contract 2 --despill --force`. The builder crops alpha, resamples with
Lanczos, and writes the 192 px shrine plus 128 px crafting icons.

## Crystal shrine prompt

> Use case: stylized-concept. Asset type: game-ready interactable world shrine
> sprite for Crownless. Input 1 is the current 16×16 crystal and is a negative
> reference only—replace its blocky scale and saturated-purple execution. Input
> 2 is the accepted Moonstone and is the binding finish/palette reference for
> pearly controlled highlights. Input 3 is the current crystal-spire terrain art
> and is a quality/camera reference only; make a distinct smaller interactable,
> not duplicate terrain. Create one ancient resonance crystal shrine used as a
> touchable story object: a broad waist-high blue-white crystal rising from a
> compact circular dark-stone socket with three small supporting shards. The
> central crystal is opaque painted mineral, cloudy within, with restrained cold
> inner glow and faint lavender undertones. It should read as an altar, font, or
> keystone rather than a natural crystal field. Polished hand-painted 2D dark
> fantasy, low three-quarter top-down camera, crisp anti-aliased silhouette,
> strong readable planes at 80–110 px, not pixel art or photorealistic. Centered,
> compact, roughly square, grounded footprint, generous padding, no cropping.
> Cool internal moonlight; somber, ancient, restrained highlights. Perfectly
> flat solid #ff00ff chroma-key background, with no background shadow, gradient,
> texture, reflection, floor, or lighting variation. Fully opaque subject; one
> object only; no cast shadow, aura, particles, text, letters, runes, UI frame,
> scenery, people, skulls, or watermark. Keep edges separate from the background
> and do not use #ff00ff in the subject. Avoid saturated amethyst, tall natural
> crystal forest, jewelry, floating crystal, sci-fi machinery, neon bloom,
> black-square outline, and blocky pixels.

## Gem-family prompt recipe

Each gem used its existing tiny icon as a material-identity/negative-pixel-art
reference and the accepted Moonstone as the binding finish reference.

> Use case: stylized-concept. Asset type: high-resolution Crownless crafting-
> material icon. Create one loose cut gem, isolated and centered, in polished
> hand-painted 2D dark-fantasy game art. Use crisp anti-aliased edges, controlled
> pearly highlights, opaque mineral planes, and a strong silhouette readable at
> 48–64 px. Match the accepted Moonstone's finish without copying its shape.
> One gem only; no jewelry setting, pedestal, cast shadow, glow, particles,
> text, frame, scenery, hands, or watermark. Keep every edge separated from a
> perfectly uniform chroma-key background and do not use the key color in the
> subject. Avoid pixel art, photorealism, neon bloom, glass transparency, and
> oversized white specular clipping.

Per-gem clauses:

- Sapphire: elongated octagonal brilliant; deep-water blue, icy blue, and navy;
  flat `#00ff00` key.
- Emerald: cushion-cut square with clipped corners; forest emerald, mint, and
  bottle green; flat `#ff00ff` key.
- Ruby: oval brilliant; blood red, scarlet-warm rose, and wine; flat `#00ff00`
  key.
- Amber: polished teardrop/cabochon hybrid; amber-orange, gold, and cognac; one
  tiny dark mineral inclusion but no insect; flat `#00ff00` key.
- Amethyst: hexagonal rose cut; sober violet, lavender, and plum; flat `#00ff00`
  key.

## Runtime outputs

- `game/assets/sprites/crystal.png`
- `game/assets/sprites/rv_mat_gem_blue.png`
- `game/assets/sprites/rv_mat_gem_green.png`
- `game/assets/sprites/rv_mat_gem_red.png`
- `game/assets/sprites/rv_mat_gem_amber.png`
- `game/assets/sprites/rv_mat_gem_violet.png`

`qa_visual_cleanup.png` is the generated contact sheet and includes the earlier
Moonstone so the entire family can be reviewed together.
