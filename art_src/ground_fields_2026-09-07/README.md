# Painterly keep paving

Generated with the built-in image-generation tool on 2026-09-07 for the
autonomous Crownless visual/QA pass. No external stock art was used.

The untouched 1254 × 1254 RGB output is installed as
`game/assets/sprites/ground_field_stone_painterly.png` and mirrored to mobile.
The older `ground_field_stone.png` remains available for the comparison rig.
No slicing, painting, palette conversion or offline resampling was applied.

`Art.ground_field("stone")` selects this master. The renderer repeats it every
384 world pixels with mipmaps; the codex preview uses the same material scale.
This retains 3.27 source pixels per world pixel and keeps individual flagstones
roughly in scale with the cast. A 1.28 field-only exposure gain compensates for
the darker neutral master under the keep's lighting. Terrain geometry, ambient
lighting, roads, prop placement and collision are unchanged.

The generator did not follow the requested 30–36 stones across. World-space
texture scaling resolves this without discarding the high-resolution master.
Edge differences at the source are 6.80/255 left–right and 4.32/255 top–bottom;
the final decision is the repeated material in the actual renderer, not those
metrics alone. `shot.bat quality` includes the outgoing and incoming floor at
the same camera position, plus danger/shelter markers across four terrains.

## Exact generation prompt

Create one square seamless tileable game FLOOR TEXTURE, viewed exactly straight
down orthographically. Production bitmap for a painterly dark-fantasy 2D action
RPG; this is a flat surface texture, NOT a scene, mockup, screenshot or concept
art composition. Subject: time-worn muted grey stone paving in a medieval
castle bailey, roughly cut irregular rectangular and polygonal flagstones with
thin subdued mortar joints, gently worn chipped edges, subtle stone-grain
brushwork and faint weathering. Cohesive hand-painted material quality to sit
beneath detailed softly shaded fantasy characters and weathered stone
architecture. Many small paving stones: approximately 30 to 36 stones across
the width, with varied proportions and natural interlocking masonry. Very low
overall contrast so actors and danger markers remain prominent. Neutral
desaturated mid-grey palette centred around RGB 115,116,122, with most stone
values between RGB 95 and 137; very subtle warmer/cooler stone variation. Thin
joints are only modestly darker than the stone, never black outlines. Matte
surface, flat diffuse lighting, absolutely no directional highlights, no cast
shadows, no vignette or darker perimeter. Fine painterly grain, not cartoon
linework, not pixel art, not noisy photogrammetry. Absolutely NO props, walls,
plants, grass clumps, rubble piles, creatures, blood, symbols, lettering,
border, focal landmark or large contrasting crack. Edge-to-edge uniform
material density and brightness. All four edges must tile seamlessly
left-to-right and top-to-bottom: paving and mortar continue naturally across
wrap boundaries with no visible seam or border. Output a single opaque square
texture image at high resolution.
