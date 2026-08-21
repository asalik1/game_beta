Generated exactly one master with the built-in ImageGen tool.

Files:

- [beam_master_2x2_v1.png](C:/Users/asali/Projects/MMO/art_src/boss_qa_fix_2026-08-18/nullwarden/beam/s/beam_master_2x2_v1.png) — raw, unchanged, **1254×1254 px**
- [beam_master_2x2_v1_keyed.png](C:/Users/asali/Projects/MMO/art_src/boss_qa_fix_2026-08-18/nullwarden/beam/s/beam_master_2x2_v1_keyed.png) — RGBA, auto-corner key sampling and despill

All four poses are visibly different:

1. Hands raised outward with attached palm nodes.
2. Fists pulled tightly beside the helmet in a charge pose.
3. Both fists thrust together toward the viewer; no beam.
4. Arms lowered in recovery.

Blunt defects:

- The character is recognizable but off-model: taller and narrower than the binding reference, with altered belt, torso, and armor details.
- Anchoring fails. Frame 3 is visibly shorter and its crown sits roughly 45 px lower; bottom-row feet are about 10 px lower. Cell-relative horizontal centers alternate by roughly 60 px.
- Frames 2 and 4 contain detached cyan sparkles, violating the projectile rule.
- The raw background is neither uniform nor literal `#00ff00`; sampled key was `#05f807`.
- A thin dark-green fringe remains after despill.
- No sword, beam, wrong facing, extra character, extra head, obvious extra limb, or edge-touching attack effect was produced.

The prompt followed the supplied brief, with frame 3 explicitly reconciled to the higher-priority projectile rule. No slicing or installation was performed.