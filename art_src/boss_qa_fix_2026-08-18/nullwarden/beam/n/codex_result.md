Generated one source sheet using built-in ImageGen:

- [Raw master PNG](C:/Users/asali/Projects/MMO/art_src/boss_qa_fix_2026-08-18/nullwarden/beam/n/beam_master_2x2_v1.png) — **1254×1254 px**, byte-identical to generated output.
- [Keyed RGBA PNG](C:/Users/asali/Projects/MMO/art_src/boss_qa_fix_2026-08-18/nullwarden/beam/n/beam_master_2x2_v1_keyed.png) — auto-key border sampling with despill.

All four poses are visibly different:

1. Both fists raised overhead, hands spread.
2. Fists pulled beside the head, elbows flared.
3. Fists raised higher and closer together in the release pose.
4. Arms lowered with residual sparks.

Defects:

- The background is not uniform `#00ff00`; only 6 pixels match it exactly. It varies around `#05f808`.
- Keying leaves a severe bright-green fringe: approximately 15,330 bright-green-dominant pixels remain.
- The character is noticeably taller, slimmer, and less squat than the binding reference.
- Frames 1/3 sit roughly 20 px left of frames 2/4. Foot baseline is otherwise stable.
- No weapons, emitted projectile, edge-touching effect, extra limbs, or visible face. All four views correctly face away.

No slicing or installation was performed.