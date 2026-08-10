# Ironwall Helm family wave

Generator: built-in ImageGen using the shared flat `#00ff00` chroma-key workflow. Untouched source PNGs are retained under `../generated/`; approved RGBA masters are retained under `../alpha/`.

## `h_ironwall_helm`

Neutral warrior family master: one empty standalone broad, squat dark-iron closed helm with a flat reinforced brow, deep black narrow T visor slit, squared cheek plates, round rivets, and a blunt back rim. It is a restrained wearable with no magic. This candidate was accepted after alpha inspection; its key field was removed with soft matte + despill.

Every source prompt carries the shared contract: one centered empty helm, no person/head/face/body/mannequin/floor/text/duplicate prop or shadow, and a uniform green chroma field with no green in the item.

## 2026-08-08 continuation

`h_ironwall_helm_A`, `h_ironwall_helm_B`, and `h_ironwall_helm_S` each used
one separate built-in ImageGen call. The accepted masters are single empty
dark-steel defensive helms with a horizontal black visor and increasingly
layered shield-relief/riveted construction; the A and S keys use contained
cool-blue seams only inside the metal. Exact raw chroma sources and alpha
masters live in `../generated/` and `../alpha/`. Border auto-key extraction,
soft matte (12/220), despill, and the non-installing 128px/32px builder all
passed. Runtime and `mobile/` remain untouched.
