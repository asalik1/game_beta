# Titan Helm continuation wave

## `h_titan_helm_A`, `h_titan_helm_B`, `h_titan_helm_S`

- Sources: one built-in ImageGen output per key, retained untouched as
  `../generated/<key>.png`; masters are `../alpha/<key>.png`.
- Prompts: exactly one empty massive basalt-black heavy helm with a wide dark
  empty visor slit, blocky brow, layered cheek slabs and low crown. B adds
  masterwork ironstone and one ember seam glint; A adds exotic plates and
  copper reinforcement; S uses richest ironstone relief and two glints. All
  prohibit people, heads/faces/bodies/mannequins, floor/shadow, text,
  duplicates and green in the object on `#00ff00`.
- Extraction/QA: green border auto-key, soft matte, thresholds 12/220, despill;
  transparent corners and one empty helmet per master. The builder produced
  checked 128px and hard-alpha 32px candidates. No rejection/retry; runtime and
  mobile untouched.
