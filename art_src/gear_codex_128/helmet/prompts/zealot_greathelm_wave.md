# Zealot Greathelm continuation wave

## `h_zealot_greathelm_A`, `h_zealot_greathelm_B`, `h_zealot_greathelm_S`

- Sources: one built-in ImageGen output per key, retained untouched as
  `../generated/<key>.png`; masters are `../alpha/<key>.png`.
- Prompts: exactly one empty ash-white steel greathelm with a narrow black visor
  slit, sharp tapered brow, vertical nasal ridge, flared cheeks and crimson
  lining. B uses masterwork pale steel, restrained red enamel and one gold
  glint; A adds exotic layered steel, dark-red enamel channels, sculpted
  non-readable sunburst relief and contained gold glints; S has richest pale
  steel, finest enamel and two compact gold glints. Every prompt prohibits people,
  heads/faces/bodies/mannequins, floor/shadow, text, duplicates and green in
  the object on `#00ff00`.
- Extraction/QA: green border auto-key, soft matte, thresholds 12/220, despill;
  transparent corners, exactly one empty helmet, and checked 128px/hard-alpha
  32px candidates. No rejection/retry; runtime/mobile untouched.
