# Reactive terrain atlas

Generated 2026-09-07 with Codex's built-in image generation tool. Original project
art; no external asset pack or paid generator was used. The untouched transparent
PNG is installed at `game/assets/sprites/reactive_terrain_atlas.png` and mirrored
to mobile. Runtime selects the left/right atlas cell; no raster edits were made.

Master: 1774×887 RGBA, 1,211,717 bytes, alpha range 0–255.
SHA-256: `d3ccb73f20a8ef6a3ec8f5cc7b7c9f6e61cc403dcfdf23c9f988c037abb10dce`.
Godot generates mipmaps for clean sampling at the 88-unit atlas-cell height.

Original tool output:
`C:/Users/asali/.codex/generated_images/01a07ad4-90c0-7cf3-9b81-509ae9c889ed/exec-556b5eac-456a-4b56-8a84-64c61fd1e561.png`

## Complete generation prompt

Create one production game sprite atlas for Crownless, a somber painterly 2D dark-fantasy action RPG, three-quarter top-down view (~35 degrees looking down), realistic compact proportions, crisp hand-painted edges and clear forms readable at 70 pixels tall. Transparent background with true alpha, no scene, no text, no labels, no border, no ground shadow. Exactly TWO isolated objects in a single horizontal row with huge transparent gap, equal cell spacing, both completely contained and same visual height. LEFT: Ember Cask, a squat weathered dark-oak powder barrel wrapped with two charcoal wrought-iron bands, a strongly visible faded red cloth X strapped across the front, a brass bung on its top and a short UNLIT fuse sticking up, a few warm amber cracks, dark red and aged bronze palette. RIGHT: Rimeheart, a cluster of three sharply faceted smoky blue ice crystals growing out of a low broken stone collar, one tall central shard flanked by two small shards, unmistakable frosty white split-diamond rune etched into the front central facet, restrained cyan internal light, dark blue stone palette. Objects are physical world props, not glossy UI icons. No floating particles, no aura haze, no external glow outside silhouette, no giant flames. Top left directional lighting. Output a wide transparent PNG atlas with each prop centered in its own half, common base line.
