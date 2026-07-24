# Crownfall capital redesign — generated art source

## Animated Crown Plaza fountain

`capital_crown_fountain_anim_source.png` was made with Codex's built-in image
generation tool using `game/assets/sprites/capital_crown_fountain.png` as the
locked edit target and style reference.

Final prompt:

> Use case: precise-object-edit
>
> Asset type: 4-frame pixel-art environmental animation sheet for the Crownless
> game
>
> Input image: Image 1 is the exact edit target and geometry/style reference.
>
> Primary request: Create a clean 2x2 animation storyboard of the exact Crown
> Plaza fountain from Image 1. Each quadrant is one equal 512x512 frame.
> Preserve the fountain's silhouette, scale, camera angle, crown statue,
> stonework, banners, braziers, palette, hard pixel clusters, and placement
> exactly in every frame. Change ONLY the blue water: subtly cycle the falling
> streams, basin ripples, and a few restrained cyan highlights so the four
> frames loop smoothly 1→2→3→4→1. Keep the structure perfectly still with no
> geometry wobble, no camera shift, no recoloring, and no added objects.
>
> Scene/backdrop: perfectly flat solid #ff00ff chroma-key background in every
> quadrant, uniform to the edges, for background removal.
>
> Style/medium: production-quality crisp pixel art matching Image 1; hard
> aliased edges; no antialiasing; no painterly shading; no bloom.
>
> Composition/framing: exact 2x2 grid, one centered full fountain per quadrant,
> identical margins and alignment; no gutters, dividers, labels, or borders.
>
> Constraints: no shadows, gradients, texture, reflections, or floor plane in
> the background; do not use #ff00ff in the fountain; no watermark; no text.
> This is an animation sheet, so stone and architecture must be identical
> between frames and only water pixels may move.

The chroma-key helper produces `capital_crown_fountain_anim_keyed.png`.
`tools/art/build_capital_water_anim.py` then aligns all four generated
frames to the shipped static sprite and copies only the water regions. This
keeps the architecture byte-stable while allowing the streams and basin to
move. The final horizontal strip is:

`game/assets/sprites/capital_crown_fountain_anim.png`

## Animated Wellspring

`capital_wellspring_anim_source.png` was produced in a separate built-in
image-generation call using `game/assets/sprites/capital_wellspring.png` as its
locked edit target. The final prompt used the same workflow:

> Use case: precise-object-edit
>
> Asset type: 4-frame pixel-art environmental animation sheet for the Crownless
> game
>
> Input image: Image 1 is the exact edit target and geometry/style reference.
>
> Primary request: Create a clean 2x2 animation storyboard of the exact
> Crownfall Wellspring pavilion from Image 1. Each quadrant is one equal frame.
> Preserve the pavilion's silhouette, scale, camera angle, crown finial, arches,
> columns, masonry, ivy, flower beds, stairs, palette, hard pixel clusters, and
> placement exactly in every frame. Change ONLY the central blue water: subtly
> cycle the narrow falling stream, basin ripples, and restrained cyan-blue
> highlights so the four frames loop smoothly 1→2→3→4→1. Keep every
> architectural and plant pixel visually still with no geometry wobble, no
> camera shift, no recoloring, and no added objects.
>
> Scene/backdrop: perfectly flat solid #ff00ff chroma-key background in every
> quadrant, uniform to the edges, for background removal.
>
> Style/medium: production-quality crisp pixel art matching Image 1; hard
> aliased edges; no antialiasing; no painterly shading; no bloom.
>
> Composition/framing: exact 2x2 grid, one centered full pavilion per quadrant,
> identical margins and alignment; no gutters, dividers, labels, or borders.
>
> Constraints: no shadows, gradients, texture, reflections, or floor plane in
> the background; do not use #ff00ff in the pavilion; no watermark; no text.
> This is an animation sheet, so all non-water artwork must remain identical
> between frames and only water pixels may move.

The same chroma-removal and water-only compositor builds:

`game/assets/sprites/capital_wellspring_anim.png`
