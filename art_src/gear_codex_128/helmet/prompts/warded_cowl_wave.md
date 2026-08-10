# Warded Cowl continuation wave

## `h_warded_cowl_A`, `h_warded_cowl_B`, `h_warded_cowl_S`

- Sources: one built-in ImageGen output per key, retained untouched as
  `../generated/<key>.png`; masters are `../alpha/<key>.png`.
- Prompts: exactly one empty charcoal leather-and-cloth assassin cowl with a
  narrow empty face cavity, asymmetric folded brow, collarless edge and silver
  ward discs. B uses masterwork folds and one cold-blue glint; A adds layered
  shadow leather and ward plates; S has richest layers and two glints. Every
  prompt prohibits people, heads/faces/bodies/mannequins, floor/shadow, text,
  duplicates and green in the object on `#00ff00`.
- Extraction/QA: green border auto-key, soft matte, thresholds 12/220, despill;
  transparent corners and a single empty cowl per master. Checked 128px and
  hard-alpha 32px candidates were built. No rejection/retry; runtime/mobile
  untouched.
