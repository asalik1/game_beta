# Vigil Greathelm continuation wave

## `h_vigil_greathelm_A`, `h_vigil_greathelm_B`, `h_vigil_greathelm_S`

- Sources: one built-in ImageGen output per key, retained untouched as
  `../generated/<key>.png`; masters are `../alpha/<key>.png`.
- Prompts: exactly one empty tall midnight-blue steel greathelm with black
  empty visor slit, peaked brow, vertical side ridges, small flared cheeks and
  rear neck plate. B uses masterwork nightsteel and one moon-white glint; A
  adds layered nightsteel, silver non-readable relief, pale-blue enamel seams
  and contained moon-white glints; S uses richest layers, intricate
  non-readable relief, refined silver fittings and two compact seam glints.
  Every prompt prohibits people, heads/faces/bodies,
  mannequins, floor/shadow, text, duplicates and green in the object on
  `#00ff00`.
- Extraction/QA: green border auto-key, soft matte, thresholds 12/220, despill;
  transparent corners and one empty helmet per master. Checked 128px and
  hard-alpha 32px candidates were built. No rejection/retry; runtime/mobile
  untouched.
