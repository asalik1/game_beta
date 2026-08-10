# Earthen Circlet family wave

Generator: built-in ImageGen using the shared flat `#00ff00` chroma-key workflow. Untouched source PNGs are retained under `../generated/`; approved RGBA masters are retained under `../alpha/`.

## `h_earthen_circlet`

Neutral mage family master: one empty standalone low antique-bronze circlet with three irregular brown faultstone slabs across its brow, earth-toned wire binding, and a visible dark inner hollow. It is a well-made restrained wearable headpiece with no magic. This candidate was accepted after alpha inspection; its key field was removed with soft matte + despill.

Every source prompt carries the shared contract: one centered empty headpiece, no person/head/face/body/mannequin/floor/text/duplicate prop or shadow, and a uniform green chroma field with no green in the item.

## Completion wave — 2026-08-08

Built-in ImageGen made exactly one distinct source for each of the four remaining
manifest keys below. No source was rejected and no retry or variant was made.
Each untouched source remains in `../generated/`; the corresponding approved
RGBA master is in `../alpha/`. Alpha removal used the installed
`remove_chroma_key.py` helper with border auto-key, soft matte, thresholds
12/220, and despill.

### `h_earthen_circlet_A`

- Source: `../generated/h_earthen_circlet_A.png`; border key sampled
  `#03f90d`.
- Alpha master: `../alpha/h_earthen_circlet_A.png`.
- Prompt: `one A-grade Earthen Circlet, designed as a complete standalone empty
  wearable headpiece: one low antique-bronze circlet with three irregular
  smoky-brown faultstone slabs across the brow and a visible dark inner hollow;
  preserve the family silhouette, but make it visibly exceptional with nested
  bronze retaining claws, layered mineral strata, fine copper wire binding,
  cracked amber seams contained within the stones, and stronger carved relief.`

### `h_earthen_circlet_S`

- Source: `../generated/h_earthen_circlet_S.png`; border key sampled
  `#03f907`.
- Alpha master: `../alpha/h_earthen_circlet_S.png`.
- Prompt: `one S-grade Earthen Circlet, designed as a complete standalone empty
  wearable headpiece: one legendary low antique-bronze circlet with three
  irregular brown faultstone slabs across the brow and a visible dark inner
  hollow; preserve the family silhouette but make it legendary through the
  richest stepped mineral setting, thick forged bronze retaining claws, fine
  copper binding, small compact amber sparks and luminous seismic seams
  contained inside the cracked stone, with no extra floating pieces.`

### `u_faultstone_circlet`

- Source: `../generated/u_faultstone_circlet.png`; border key sampled
  `#0bf90d`.
- Alpha master: `../alpha/u_faultstone_circlet.png`.
- Prompt: `one Faultstone Circlet, designed as a complete standalone empty
  wearable headpiece; it must read immediately as a circlet, but have an
  independent named-unique silhouette rather than a brightened generic:
  asymmetrical low dark-bronze and clay circlet, its brow formed from a single
  large fractured gray-brown faultstone shard held by visible copper staples
  and wire, with one smaller offset earthen plate, a hairline geological fault
  running through the crown, and a deep empty inner hollow; restrained dull
  orange mineral glow only inside the fault.`

### `u_worldmantle_circlet_beyond_the_firmament`

- Source: `../generated/u_worldmantle_circlet_beyond_the_firmament.png`; border
  key sampled `#03f908`.
- Alpha master: `../alpha/u_worldmantle_circlet_beyond_the_firmament.png`.
- Prompt: `one Worldmantle, Circlet Beyond the Firmament, designed as a
  complete standalone empty wearable headpiece; it must read immediately as a
  circlet, with its own legendary independent silhouette rather than a
  brightened generic: a majestic low circular crown-circlet forged from dark
  umber worldstone and aged bronze, its brow a continuous fractured continental
  ridge with three broad tectonic plates, deep empty inner hollow, tiny
  contained amber-gold geological seams and sparse compact sparks between the
  plates, with a subtle raised stone crest at center; all stone stays attached
  to the circlet, no floating fragments.`

## QA

- The non-installing `build_gear_codex_icons.py --slot helmet` run accepted all
  four masters and emitted their normalized 128px codex and hard-alpha 32px
  gameplay candidates under `tmp/gear_codex_128/helmet/`.
- Visual inspection of `qa_codex.png` and `qa_gameplay.png` found four single,
  empty circlets, transparent fields with no green fringe, and a distinct
  readable construction ladder. The two named designs retain independent
  silhouettes at 32px.
- Runtime icons and `mobile/` remain untouched.

## Audited completion — 2026-08-08

### `h_earthen_circlet_B`

- Source: `../generated/h_earthen_circlet_B.png`, retained unchanged from one
  built-in ImageGen call; border auto-key sampled `#04fa06`.
- Alpha master: `../alpha/h_earthen_circlet_B.png`, made with the installed
  imagegen `remove_chroma_key.py` helper using border auto-key, soft matte,
  thresholds 12/220, and despill.
- Prompt: `one B-grade Earthen Circlet, designed as a complete standalone
  EMPTY wearable headpiece: one low antique-bronze circlet with three irregular
  smoky-brown faultstone slabs across its brow and a visible dark inner hollow;
  preserve the same family silhouette, masterwork construction with fine copper
  wire binding, shallow stone-carved geometric ornament, small bronze retaining
  claws, and one restrained contained amber mineral accent inside a crack.` The
  shared contract required one centered standalone object on a flat green chroma
  field, with no head, face, body, mannequin, floor, shadow, lettering, or
  duplicate prop.
- Acceptance: inspected raw and alpha outputs: one empty circlet only, no green
  spill, and clear bronze/faultstone construction at both 128px codex and 32px
  gameplay candidate sizes. No rejection or retry; the one source was accepted.
- QA: non-installing `build_gear_codex_icons.py --slot helmet` refreshed the
  128px/32px candidates and sheets under `tmp/gear_codex_128/helmet/`.
  Runtime icons and `mobile/` remain untouched.
