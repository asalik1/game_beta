# Grave Cowl family wave

Generator: built-in ImageGen using the shared flat `#00ff00` chroma-key workflow. Untouched source PNGs are retained under `../generated/`; approved RGBA masters are retained under `../alpha/`.

## `h_grave_cowl`

Neutral assassin family master: one empty standalone soot-black gravecloth cowl with a blunt low crown, deep black face opening, weathered folds, thin sewn bone-bead brow trim, and one iron grave-nail clasp integrated into the lower drape. It is a restrained wearable with no magic. This candidate was accepted after alpha inspection; its key field was removed with soft matte + despill.

Every source prompt carries the shared contract: one centered empty cowl, no person/head/face/body/mannequin/floor/text/duplicate prop or shadow, and a uniform green chroma field with no green in the item.

## 2026-08-08 continuation

### `h_grave_cowl_A`

Built-in ImageGen generated the A-grade master as one empty soot-black
gravecloth cowl with bone-bead brow trim, a hollow dark face opening, layered
antique grave-silk construction, and a single integrated grave-nail clasp. The
accepted untouched chroma source is `../generated/h_grave_cowl_A.png`; its
RGBA master is `../alpha/h_grave_cowl_A.png`, extracted with border auto-key,
soft matte (12/220), and despill. The non-installing builder accepted the
master and its 128px/32px candidates remain under `tmp/gear_codex_128/helmet/`.

The first successful generation was accepted. A local display-wrapper error
made the caller issue one accidental duplicate request before the first output
was inspected; that second untouched raw source is retained only as
`../generated/rejected_h_grave_cowl_A_duplicate_tool_retry.png`. It was not
alpha-extracted or used. Runtime and `mobile/` remain untouched.

### `h_grave_cowl_B` and `h_grave_cowl_S`

Each key used one separate built-in ImageGen call. The B-grade cowl preserves
the same empty soot-black form while adding masterwork bone-thread embroidery
and one restrained ivory stitch accent; the S-grade cowl adds the family’s
richest grave-silk layers, bone-stitch relief, and contained ivory seam light.
Untouched chroma sources and approved RGBA masters are named exactly by key in
`../generated/` and `../alpha/`. Both were border-auto-keyed with soft matte
(12/220) and despill, then passed the non-installing 128px/32px builder QA.
