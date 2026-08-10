# Gossamer Cowl family wave

Generator: built-in ImageGen using the shared flat `#00ff00` chroma-key workflow. Untouched source PNGs are retained under `../generated/`; approved RGBA masters are retained under `../alpha/`.

## `h_gossamer_cowl`

Neutral assassin family master: one empty standalone charcoal-gray silk cowl with a rounded low crown, deep black face opening, narrow draped folds, and pale-silver gossamer web stitching at brow and hem. The accepted second source was necessary because the first source introduced a disallowed miniature duplicate; it is retained as `../generated/rejected_h_gossamer_cowl_duplicate_mini_icon.png`. The accepted source passed alpha inspection, with soft matte + despill removal.

Every source prompt carries the shared contract: one centered empty cowl, no person/head/face/body/mannequin/floor/text/duplicate prop or shadow, and a uniform green chroma field with no green in the item.

## 2026-08-08 continuation

Built-in ImageGen made one source each for `h_gossamer_cowl_A`,
`h_gossamer_cowl_B`, `h_gossamer_cowl_S`, and `u_mothsilk_cowl`. Their untouched
sources are retained under `../generated/`, and their approved alpha masters
were extracted with border auto-key, soft matte (12/220), and despill into
`../alpha/`. Each accepted result is one empty cowl with a dark face opening;
the grade ladder increases web embroidery, fold construction and contained
silver detail, while Mothsilk has an independent scalloped moth-wing hem.

`u_pale_web_cowl_between_heartbeats` used its required single built-in call,
but the raw result also contains a detached miniature duplicate beneath the
main cowl. It violates the one-object contract and is retained only as
`../generated/rejected_u_pale_web_cowl_between_heartbeats_duplicate_mini_icon.png`.
The isolated upper canvas (the sole main cowl, with the detached lower echo
excluded) was deterministically preserved as
`../generated/u_pale_web_cowl_between_heartbeats.png`, then chroma-extracted
to `../alpha/u_pale_web_cowl_between_heartbeats.png`; no retry was made.

The non-installing helmet builder accepted all five Gossamer masters and the
128px/32px QA sheets show a clean single-cowl silhouette for every key, without
green spill. Runtime assets and `mobile/` remain untouched.
