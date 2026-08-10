# Ranger's Hood family wave

Generator: built-in ImageGen using the shared flat `#ff00ff` chroma-key workflow. Untouched source PNGs are retained under `../generated/`; approved RGBA masters are retained under `../alpha/`.

## `h_rangers_hood`

Neutral archer family master: one empty standalone forest-charcoal cloth hood with a broad rounded crown, deep black opening, weathered brown leather seam binding, short gray fur edge, and a small brass compass-like brow rivet. It is a restrained wearable with no magic. This candidate was accepted after alpha inspection; its key field was removed with a stronger soft matte + despill to eliminate the generator's varied magenta field.

Every source prompt carries the shared contract: one centered empty hood, no person/head/face/body/mannequin/floor/text/duplicate prop or shadow, and a uniform magenta chroma field with no magenta in the item.

## 2026-08-08 continuation

`h_rangers_hood_A` and `h_rangers_hood_B` each used one separate built-in
ImageGen call. Both accepted outputs are single empty forest-brown and
moss-gray ranger hoods with hollow openings, fur lining, leaf clasp, and
progressively richer leather/leaf construction. Exact magenta chroma sources
and alpha masters are stored by key in `../generated/` and `../alpha/`.
Border auto-key, soft matte (12/220), despill, and the non-installing 128px/32px
builder passed. Runtime and `mobile/` remain untouched.

### `h_rangers_hood_S`

- Source: one built-in ImageGen call, retained unchanged as
  `../generated/h_rangers_hood_S.png`; border auto-key sampled `#fb03fc`.
- Alpha master: `../alpha/h_rangers_hood_S.png`, produced with border auto-key,
  soft matte, thresholds 12/220, and despill.
- Prompt: `one S-grade Ranger's Hood, designed as a complete standalone EMPTY
  wearable headpiece: preserve the Ranger's Hood family silhouette, a broad
  rounded forest-charcoal cloth crown with a deep black hollow opening,
  weathered brown leather seam binding, short gray fur edge and a small brass
  compass-like brow rivet. Make it legendary through richest layered dark
  moss-gray cloth construction, crisp leaf-shaped leather clasp, reinforced
  antler-brown seam cords, finely worked fur lining and a few contained pale
  wind-thread sparks only along the hood rim; clearly a hood, not a cloak, no
  detached pieces.` The shared contract additionally prohibited a person, head,
  face, body, mannequin, duplicate object, floor, shadow, lettering and UI.
- Acceptance: the only source is a single empty hood with a visible opening;
  alpha inspection found no magenta fringe. The 128px codex and 32px gameplay
  candidates retain the hood silhouette and the B/A/S construction ladder.
  No rejection or retry.
- QA: non-installing `build_gear_codex_icons.py --slot helmet` refreshed the
  candidate outputs and contact sheets under `tmp/gear_codex_128/helmet/`.
  Runtime icons and `mobile/` remain untouched.
