# Archer high-detail redraw — review proof

Status: **review only; not installed in `game/`**.

This is a built-in Codex image-generation proof for raising the base Archer
from her current 121px south-idle body source toward the 180px source-density
language used by Elder Maren, while preserving the game's 88px rendered body
height. The intended gain is denser source information and cleaner material
separation, not a larger gameplay silhouette.

## Files

- `idle_s_source_v2.png` — final four-frame south-facing white-background
  generation source.
- `idle_s_alpha_v2.png` — pipeline-style white-key preview. The live install
  should be produced by the eventual Archer upscale builder, not copied from
  this review file by hand.
- `idle_s_npc_density_v2.png` — the same four frames normalized to a 180px
  alpha-body inside 256px cells, matching the Elder's source-density regime.
- `comparison_game_scale_v2.png` — current Archer, Elder NPC, and redraw
  normalized to their real body-height targets, then enlarged 3x with nearest
  filtering for review.

## Generation prompt

Use case: precise-object-edit

Asset type: Crownless game hero sprite quality proof, four-frame south-facing
idle strip.

Image 1 was `game/assets/sprites/archer_anim.png`, used as the exact character,
pose, and animation reference. Image 2 was `game/assets/sprites/elder.png`, used
only as the pixel-detail and construction-quality reference.

Redraw/upscale the Archer as exactly four separated, evenly spaced, full-body
south-facing idle frames in one horizontal row. Increase native pixel
information, material definition, facial readability, and clean pixel-cluster
craftsmanship to be slightly sharper and more detailed than the Elder, while
keeping the Archer unmistakably the same character. Preserve the adult female
huntress, slim tall proportions, visible face, short dark-brown side-parted
bob, pale skin, gray fur shoulder mantle, charcoal/deep forest-green split
cloak, layered dark leather armor, belts, pouches, gloves, boots, shoulder
quiver, curved wooden recurve bow, four subtle poses, pose order, shared
baseline, and identical body scale. Use hand-authored dark-fantasy RPG pixel
art, a crisp near-black outline, dense readable pixel clusters, a restrained
palette, and a perfectly flat pure-white background. No shadows, floor, labels,
numbers, text, UI, watermark, effects, scenery, extra props, or extra figures.

## Correction prompt

The first generation invented a second arrow bundle at the viewer-left hip.
The targeted edit removed only that bundle in all four frames, restored the
cloak silhouette there, and kept the single shoulder quiver and all other
design, pose, spacing, palette, and background constraints unchanged.

## Review notes

- At gameplay height, the redraw retains a brighter face, more legible fur,
  clearer armor layers, and finer boot/cloak separation than the current
  source.
- The corrected silhouette has one shoulder quiver and one bow.
- The four poses remain intentionally subtle. A full production pass still
  needs an approved body anchor, all eight directions, and every action strip;
  none should replace live art until checked together at gameplay scale.
