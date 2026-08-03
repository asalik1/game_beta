# Stormweave benchmark generation and QA notes

## Accepted benchmark

- Family: Stormweave Leggings.
- Assets: neutral, B, A, S, named A `Stormneedle Leggings`, named S
  `Tempest Crown, Leggings of the Last Gale`.
- Generator: built-in ImageGen only. PixelLab was not used.
- Background: flat magenta chroma field, chosen to protect the blue/cyan storm
  palette.
- Alpha: installed imagegen `remove_chroma_key.py` helper with border auto-key,
  soft matte, thresholds 12/220, and despill. The accepted S alpha uses
  `--edge-contract 1` after enlarged inspection found a one-pixel magenta rim.
- Builder: `build_gear_codex_icons.py --slot pants`, without `--install`.
- Coverage after benchmark: 6/180 transparent pants masters; 174 intentionally
  remain for the full production pass.

## Rejection log

1. `p_stormweave_leggings_S_reject01_detached_lightning.png`: rejected because
   cyan arcs projected into the chroma field on both sides of the knees. A
   targeted edit removed only those arcs. The rejected chroma output is retained
   for audit; no rejected file was put in `alpha/`.

## Quality findings

- All six 128px candidates retain a closed, immediately readable pants
  silhouette with transparent corners and safe canvas padding.
- Neutral/B/A/S preserve the same family proportions. The ladder remains
  legible without rarity color washes: cleaner seam relief at B, feather-weave
  and articulated knees at A, and scale textile plus richer knee construction
  at S.
- Mean opaque gameplay luminance rises monotonically across the family
  (neutral 65.8, B 73.1, A 80.6, S 87.1), avoiding the current dark-icon
  collapse while preserving the charcoal Stormweave identity.
- `Stormneedle` is the darkest candidate (gameplay mean 64.6) but its asymmetric
  feather panel and silver needle bars remain distinguishable at 32px.
- `Tempest Crown` is intentionally the brightest and most ornate (gameplay mean
  86.7); the crown-shaped integrated waist and feathered knee silhouette remain
  unique at both sizes.
- The 32px optimization reduces fine textile and seam detail as expected, but
  all six remain recognizable as pants rather than boots, skirts, or armor
  loadouts. No magenta pixels survive in the final 32px candidates.
