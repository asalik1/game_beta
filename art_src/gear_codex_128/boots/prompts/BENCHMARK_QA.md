# Boots benchmark QA: Radiant Greaves

Status: candidate-only benchmark complete on 2026-08-03.

## Six keys

- `b_radiant_greaves`
- `b_radiant_greaves_B`
- `b_radiant_greaves_A`
- `b_radiant_greaves_S`
- `u_solarch_greaves`
- `u_noonwalker_greaves`

Untouched chroma sources are in `../generated/`, transparent masters in
`../alpha/`, exact executed prompts beside this report, and candidate outputs
under `tmp/gear_codex_128/boots/`. Built-in ImageGen was used for all six;
PixelLab was not used. Chroma removal used the installed imagegen helper with
border sampling, soft matte, despill, and thresholds 12/220. Candidate building
used `build_gear_codex_icons.py --slot boots` without `--install`.

## Visual findings

- Every image contains exactly one matched pair of two empty armored boots.
- Both cuffs are visibly hollow. There are no feet, toes, legs, knees, skin,
  wearer, mannequin, floor, pedestal, props, third boots, or mismatched pairs.
- Neutral through S retains the knee-high Radiant Greaves silhouette. The grade
  ladder progresses through construction: restrained plate, finer B facets and
  inlay, layered A sunsteel relief, then the richest S fittings and luminous
  seams.
- Solarch is an independent black-sunsteel and burnished-gold command design.
  Noonwalker is an independent white-crownsteel and midnight-blue horizon
  design. Neither is a brightened generic or a variation of the other.
- All pairs remain legible as boots at 128px and 32px; open-cuff separation and
  articulated toes survive the gameplay export.

## Automated findings

- All 18 alpha/codex/gameplay files are RGBA with four transparent corners.
- Bright chroma-green foreground pixels detected: zero.
- All six files have distinct SHA-256 hashes at both candidate sizes.
- Coverage is intentionally 6/180; the other 174 boots keys belong to the later
  bulk pass.

## Rejections and blockers

No images were rejected or regenerated in this six-call benchmark. No blocker
was encountered. Runtime and mobile assets were not modified.
