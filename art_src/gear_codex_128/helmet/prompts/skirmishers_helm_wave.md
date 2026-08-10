# Skirmisher's Helm continuation wave

## `h_skirmishers_helm_A`

- Source: built-in ImageGen on 2026-08-08. Accepted untouched chroma source:
  `../generated/h_skirmishers_helm_A.png` on a uniform green field. Its
  transparent master is `../alpha/h_skirmishers_helm_A.png`.
- Prompt: exactly one A-grade empty Skirmisher's Helm: a lightweight low-profile
  dark-steel open-faced helm with a swept pointed brow, short narrow cheek
  guards, compact rear neck guard, a visible empty interior, and a crimson
  leather strap. The A-grade construction adds layered tempered plates, a
  refined ridged brow, copper edge bindings, non-readable chevrons and small
  contained amber fitting glints. The shared contract prohibited heads, faces,
  bodies, mannequins, floor planes, shadows, text, duplicate objects and green
  within the helmet.
- Chroma extraction: installed `remove_chroma_key.py`, border auto-key
  (`#03f905`), soft matte, thresholds 12/220, despill. It produced transparent
  corners and a clean isolated object.
- QA: the non-installing builder accepted the high-resolution master and made
  a 128px codex candidate plus hard-alpha 32px gameplay candidate under
  `tmp/gear_codex_128/helmet/`. Both were visually inspected: one centered,
  empty helmet; readable silhouette; no key-colour fringe.
- Rejection record: `../generated/rejected_h_skirmishers_helm_A_tool_result_adapter_duplicate.png`
  is retained only because a result-adapter failure occurred after the initial
  built-in generation completed. It was not used; the accepted source above is
  the second generated output.

Runtime and mobile assets remain untouched.

# Starweave Circlet continuation wave

## `h_starweave_circlet_A`

- Source: exactly one built-in ImageGen output, retained untouched as
  `../generated/h_starweave_circlet_A.png`; approved master:
  `../alpha/h_starweave_circlet_A.png`.
- Prompt: one empty A-grade Starweave Circlet: slender open silver-blue band,
  high central star brow setting, four smaller integrated star settings, arcing
  celestial wirework and a pointed lower pendant. A-grade work adds layered
  moon-silver filigree, faceted blue-white crystals, non-readable celestial
  lattice relief and contained starlight in the settings only. It expressly
  prohibited crowns, necklaces, separate jewelry, heads, bodies, floor, text,
  duplicate props and shadows.
- Extraction/QA: border auto-key `#fc04fa`, soft matte, thresholds 12/220 and
  despill. The inspected master has transparent corners; the generated 128px
  and hard-alpha 32px candidates retain the single readable circlet silhouette.
  No rejection/retry; runtime/mobile untouched.

## `h_starweave_circlet_B`

- Source: exactly one built-in ImageGen output, retained untouched as
  `../generated/h_starweave_circlet_B.png`; approved master:
  `../alpha/h_starweave_circlet_B.png`.
- Prompt: one empty B-grade Starweave Circlet preserving the slender open
  silver-blue band, central and four side star settings, celestial wirework and
  lower pendant. The masterwork version uses clean moon-silver wirework,
  refined blue-white gems, restrained lattice and one modest contained
  starlight point.
- Extraction/QA: border auto-key `#fa03f8`, soft matte, thresholds 12/220 and
  despill. Inspected at master and 128px/32px candidates: one empty circlet,
  clean transparent corners, readable hard-alpha reduction. No rejection/retry;
  runtime/mobile untouched.

## `h_starweave_circlet_S`

- Source: exactly one built-in ImageGen output, retained untouched as
  `../generated/h_starweave_circlet_S.png`; approved master:
  `../alpha/h_starweave_circlet_S.png`.
- Prompt: one empty S-grade Starweave Circlet retaining the same open circlet,
  central plus four star settings, wirework and pendant. Legendary work adds
  rich moon-silver filigree, bold faceted blue-white crystals, elaborate
  non-readable celestial relief, precise integrated constellation settings and
  only a few compact starlight sparks.
- Extraction/QA: border auto-key `#fb03fa`, soft matte, thresholds 12/220 and
  despill. The inspected master and 128px/32px candidates retain one readable
  circlet with transparent corners. No rejection/retry; runtime/mobile
  untouched.

## `h_skirmishers_helm_B`

- Source: exactly one built-in ImageGen output, retained untouched as
  `../generated/h_skirmishers_helm_B.png`; approved master:
  `../alpha/h_skirmishers_helm_B.png`.
- Prompt: one B-grade empty Skirmisher's Helm retaining the lightweight
  low-profile open-faced charcoal-steel form, swept brow, narrow cheek guards,
  neck guard, visible interior and crimson strap. It adds only clean segmented
  plates, a narrow brow ridge, modest copper bindings, restrained chevrons and
  one small amber fitting accent.
- Extraction/QA: border auto-key `#02f607`, soft matte, thresholds 12/220 and
  despill. The inspected alpha master and builder-created 128px/32px candidates
  show one centered empty helmet with transparent corners and a readable hard
  alpha gameplay silhouette. No rejection or retry; runtime/mobile untouched.

## `h_skirmishers_helm_S`

- Source: exactly one built-in ImageGen output, retained untouched as
  `../generated/h_skirmishers_helm_S.png`; approved master:
  `../alpha/h_skirmishers_helm_S.png`.
- Prompt: one S-grade empty Skirmisher's Helm retaining the lightweight
  open-faced charcoal-steel silhouette with swept brow, narrow cheek guards,
  neck guard and crimson strap. Its legendary but agile construction adds the
  richest layered tempered plates, a sculpted aerodynamic brow ridge, copper
  bindings, non-readable chevron relief and two compact amber fitting sparks.
- Extraction/QA: border auto-key `#04f904`, soft matte, thresholds 12/220 and
  despill. The inspected transparent master and 128px/32px candidates remain
  one isolated helmet and read cleanly at gameplay size. No rejection or retry;
  runtime/mobile untouched.
