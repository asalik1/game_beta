# Weapon benchmark QA: Pike

Status: **approved benchmark, candidate-only** (2026-08-03).

## Deliverables

- Approved untouched chroma sources: `generated/<key>.png`
- Approved transparent masters: `alpha/<key>.png`
- Exact ImageGen prompts: `prompts/<key>.txt`
- 128px candidates: `tmp/gear_codex_128/weapon/codex/<key>.png`
- 32px candidates: `tmp/gear_codex_128/weapon/gameplay/<key>.png`
- Contact sheets: `tmp/gear_codex_128/weapon/qa_codex.png` and
  `tmp/gear_codex_128/weapon/qa_gameplay.png`

The six benchmark keys are `w_pike`, `w_pike_B`, `w_pike_A`, `w_pike_S`,
`u_the_red_pennon`, and `u_crownspike_the_last_decree`.

## Process

All art was generated with the built-in ImageGen tool on a flat green chroma
field. PixelLab was not used. Chroma removal used the imagegen skill helper with
border sampling, soft matte, despill, thresholds 12/220, then the shared
`build_gear_codex_icons.py --slot weapon` candidate builder. `--install` was not
used.

The first family pass was rejected because the long shaft made neutral and B
read as thin slivers at the actual codex box. A compact full-weapon composition
with a large head, thick socket, and thicker shaft fixed that issue. A and S
were then regenerated into the same composition so B did not outweigh the
higher grades. Rejected sources and prompts remain in the `rejected_pass1`
folders.

Forward+ in-engine QA then found that the two named uniques still inherited the
original long-shaft composition and rendered as slivers inside their real 64px
cards. Both were regenerated with the same compact full-weapon rule: their
identity-bearing head/socket assembly now occupies roughly the upper third,
with a thicker shaft and the complete butt still visible.

## Findings

- Neutral, B, A, and S now share an unmistakable Pike silhouette at 128px and
  32px.
- The ladder reads through construction and grayscale mass: restrained neutral,
  faceted/inlaid B, layered high-relief A, luminous best-fittings S.
- The Red Pennon and Crownspike are visibly independent objects while remaining
  pikes. Their larger head assemblies now match the family's card-scale visual
  mass. The attached forked banner survives the 32px export; Crownspike's broad
  three-tine head and violet-black royal-decree palette remain distinct.
- All six alpha masters and both candidate sizes are RGBA with four transparent
  corners.
- Automated spill scan found zero bright chroma-green foreground pixels in all
  18 alpha/codex/gameplay files.
- All six files have distinct SHA-256 hashes at both candidate sizes.
- Coverage is intentionally 6/180 weapon masters; the remaining 174 keys are the
  post-approval bulk pass, not missing benchmark output.

## Prompt-contract note

The shared prompt contract was added while this benchmark was in progress. All
six final approved prompts now use its common wording, one-object constraints,
chroma rules, and compact card-scale composition. Exact executed prompts are
retained per key.

## Blockers

None for the approved benchmark. Bulk weapon generation has not started.
