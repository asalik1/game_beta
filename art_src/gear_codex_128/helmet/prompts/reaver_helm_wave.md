# Reaver Helm family wave

## h_reaver_helm

- Source: built-in ImageGen, one distinct generation on 2026-08-08.
- Chroma source: `../generated/h_reaver_helm.png` (flat green field; auto-key sampled `#02f906`).
- Alpha master: `../alpha/h_reaver_helm.png`, made with the installed imagegen
  `remove_chroma_key.py` helper using border auto-key, soft matte, thresholds
  12/220 and despill.
- Prompt: standalone brutal low-domed steel Reaver Helm, squared brow, split
  crest and short swept-back cheek guards; dark iron with worn crimson leather
  lining. It required one centered helmet only, with no head, face, body,
  mannequin, duplicate, floor, shadow, lettering or UI.
- Acceptance: one empty, centered helmet with a closed silhouette; no chroma
  spill visible in the extracted master. Candidate outputs built at 128px and
  32px under `tmp/gear_codex_128/helmet/` (runtime untouched).

## 2026-08-08 completion wave

Each key below used exactly one built-in ImageGen source; no source was
rejected or retried. Raw chroma sources and accepted transparent masters retain
the manifest key under `../generated/` and `../alpha/`. Each used border
auto-key, soft matte thresholds 12/220, and despill.

### `h_reaver_helm_A`

- Source key/color: `../generated/h_reaver_helm_A.png`, `#03f906`.
- Prompt: `one A-grade Reaver Helm, designed as a complete standalone EMPTY
  wearable helmet: preserve the Reaver Helm family identity, a brutal low-domed
  dark steel helm with squared brow, split crest, short swept-back cheek guards,
  a visible dark empty visor hollow and worn crimson leather lining. Make it
  visibly exceptional through layered blackened steel plates, rich riveted brow
  reinforcement, etched non-readable chevrons, scarred crimson leather crest
  binding and a contained ember-red glow only within a few hairline visor seams;
  no horns, no skull, no detached pieces.`

### `h_reaver_helm_B`

- Source key/color: `../generated/h_reaver_helm_B.png`, `#05f90a`.
- Prompt: `one B-grade Reaver Helm as a complete standalone EMPTY wearable
  helmet: same brutal Reaver family silhouette, low-domed dark steel helm,
  squared brow, split crest, short swept-back cheek guards, visible dark empty
  visor hollow and worn crimson leather lining. Masterwork construction: finer
  riveted brow band, clean steel plate segmentation, restrained non-readable
  etched chevrons, deep-red leather crest binding and one small contained ember
  accent at the visor seam.`

### `h_reaver_helm_S`

- Source key/color: `../generated/h_reaver_helm_S.png`, `#03f904`.
- Prompt: `one S-grade Reaver Helm as a complete standalone EMPTY wearable
  helmet: preserve the brutal Reaver Helm family identity: low-domed black
  steel, squared brow, split crest, short swept-back cheek guards, visible dark
  empty visor hollow and crimson leather lining. Legendary workmanship through
  richest layered blackened steel plates, heavy riveted brow reinforcement,
  carved non-readable chevrons, deep crimson crest binding, compact sparks and
  narrow contained ember-red seams around the visor.`

All three output sources were inspected before alpha extraction: each is a
single empty standalone helmet with no person, head, face, body, floor, shadow,
lettering, duplicate or chroma spill. Their alpha masters retain a readable
B/A/S construction ladder; runtime icons and `mobile/` are untouched.

## QA rerun

On 2026-08-08, the non-installing dual-resolution builder was rerun for all
four Reaver keys (`h_reaver_helm`, `_A`, `_B`, `_S`). Each passed its master,
128px codex, and 32px gameplay validation; visual inspection confirms the
closed empty-helmet silhouette and a clear B/A/S construction ladder. Runtime
and `mobile/` remain untouched.

## Pending keys

The Earthen Circlet, Featherweave Circlet, and Gossamer Cowl completion waves
are accepted. Pale Web's raw source retains its duplicate-mini rejection, while
the isolated upper-canvas main cowl is accepted without a second generation.
The next genuinely missing manifest key is `h_grave_cowl_A`.

## h_ruinweave_hood

- Source: built-in ImageGen, one distinct generation on 2026-08-08.
- Chroma source: `../generated/h_ruinweave_hood.png` (flat green field; auto-key
  sampled `#03f909`).
- Alpha master: `../alpha/h_ruinweave_hood.png`, made with the installed
  imagegen helper using border auto-key, soft matte, thresholds 12/220 and
  despill.
- Prompt: standalone torn charcoal hood with layered broken-clause cloth,
  ragged mantle edge, restrained ember-red stitches and an empty face opening;
  it prohibited a wearer, face, body, mannequin, duplicate, floor and shadow.
- Acceptance: a single empty hood/cloak object; the cloth envelope remains
  visually clear at 32px and there is no chroma spill. Candidate files built
  under `tmp/gear_codex_128/helmet/` only.

## h_runeplate_circlet

- Source: built-in ImageGen, one distinct generation on 2026-08-08; retained at
  `../generated/h_runeplate_circlet.png` on its magenta chroma field.
- Alpha: `../alpha/h_runeplate_circlet.png`, border auto-key (`#f903f8`), soft
  matte, thresholds 12/220, despill. Identity: empty gunmetal three-plate
  circlet with a blue-white lens and non-readable geometric inlay.
- Accepted as one centered circlet, with 128px/32px candidate outputs only.

## h_sanctified_greathelm

- Source: built-in ImageGen, one distinct generation on 2026-08-08, retained at
  `../generated/h_sanctified_greathelm.png`; alpha uses green border auto-key
  (`#02f909`), soft matte, thresholds 12/220 and despill.
- Identity: empty ivory-and-warm-steel crusader greathelm with cross visor,
  sunburst plate and amber gem. Accepted as one centered object; runtime
  untouched.

## h_shadeweave_hood, h_shadowveil_cowl, h_silkward_circlet

- Each used exactly one separate built-in ImageGen call on 2026-08-08. Raw
  sources remain under `../generated/` using their exact asset keys.
- Raw outputs contained a detached miniature preview echo below the main object,
  violating the one-object contract. The raw files are preserved; a deterministic
  upper-canvas extraction removed only that echo before chroma extraction. No
  second generation was used.
- Alphas use border auto-key, soft matte, thresholds 12/220 and despill:
  `../alpha/h_shadeweave_hood.png`, `../alpha/h_shadowveil_cowl.png`,
  `../alpha/h_silkward_circlet.png`. Their 128px/32px candidates are under
  `tmp/gear_codex_128/helmet/`; runtime untouched.
