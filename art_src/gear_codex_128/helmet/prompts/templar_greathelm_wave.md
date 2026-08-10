# Templar Greathelm continuation wave

## `h_templar_greathelm_A`, `h_templar_greathelm_B`, `h_templar_greathelm_S`

- Sources: one built-in ImageGen output per key, retained untouched as
  `../generated/<key>.png`; approved transparent masters are
  `../alpha/<key>.png`.
- Prompts: exactly one empty closed dark-gunmetal crusader greathelm per grade,
  with a narrow black empty visor slit, pointed brow, flared cheek plates and
  squared neck guard. B has masterwork segmented steel and a single ivory
  fitting glint; A adds exotic layered steel and raised non-readable relief;
  S uses richest layers, sculpted non-readable relief and two compact ivory
  seam glints. Every prompt prohibited people, heads/faces/bodies/mannequins,
  floor/shadow, text, duplicate objects and green in the object on `#00ff00`.
- Extraction/QA: border auto-key (green field), soft matte, thresholds 12/220,
  despill. Each alpha master has transparent corners and one empty helmet; the
  builder accepted each and made visually checked 128px and hard-alpha 32px
  candidates. No rejection/retry; runtime/mobile untouched.
