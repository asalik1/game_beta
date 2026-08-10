# Voidsilk Hood continuation wave

## `h_voidsilk_hood_A`, `h_voidsilk_hood_B`, `h_voidsilk_hood_S`

- Sources: one built-in ImageGen output per key, retained untouched as
  `../generated/<key>.png`; masters are `../alpha/<key>.png`.
- Prompts: exactly one empty deep purple-black silk hood with a visible empty
  face cavity, high narrow brow and short shoulderless cowl. B has masterwork
  voidsilk and one violet seam spark; A adds exotic panels, dark-silver clasps
  and indigo thread relief; S uses richest layers and two compact violet
  sparks. Smoke was explicitly prohibited, along with people, heads/faces,
  bodies/mannequins, floor/shadow, text, duplicates, and magenta in the object
  on `#ff00ff`.
- Extraction/QA: magenta border auto-key, soft matte, thresholds 12/220,
  despill; transparent corners and exactly one empty hood per master. Checked
  128px and hard-alpha 32px candidates were built. No rejection/retry;
  runtime/mobile untouched.
