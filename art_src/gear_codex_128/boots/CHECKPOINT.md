# Boots regeneration checkpoint

- Audited coverage: **138 / 180** transparent masters.
- In-progress Venomtread coverage: neutral and B are accepted and alpha-cleaned,
  bringing the filesystem to **140 / 180**. Exact pending key is
  `b_venomtread_A`.
- The current built-in generation context became category-unstable on
  `b_venomtread_A`: five retries (including two explicit accepted-B edit-path
  retries) produced pants/greaves or amulets instead of footwear. All wrong
  outputs are preserved under `generated/rejected_b_venomtread_A_*`. Resume
  this exact key from a fresh ImageGen context; do not accept or install a
  wrong-category output.
- Runtime and mobile assets were not installed or modified by this pass.
- Latest approved waves:
  - `b_trailboots` family (6 assets; coverage 138/180)
  - `b_starstep` family (6 assets; coverage 132/180)
  - `b_slipsteps` family (6 assets; coverage 126/180)
  - `b_skirmishers_boots` family (6 assets; coverage 120/180)
  - `b_sabatons_of_the_oath` family (6 assets; coverage 102/180)
  - `b_shadowstep_wraps` family (6 assets; coverage 108/180)
  - `b_sigil_sandals` family (6 assets; coverage 114/180)
- Both `tmp/gear_codex_128/boots/qa_codex.png` and
  `tmp/gear_codex_128/boots/qa_gameplay.png` were rebuilt and visually
  inspected at 138/180.
- Preserved rejection:
  `generated/rejected_b_sabatons_of_the_oath_white_field.png` (the first
  neutral Oath attempt ignored the mandatory chroma field).
- Additional preserved Skirmisher rejections:
  `rejected_b_skirmishers_boots_pants.png`,
  `rejected_b_skirmishers_boots_B_pants.png`,
  `rejected_b_skirmishers_boots_B_badge.png`,
  `rejected_b_skirmishers_boots_S_badge.png`, and
  `rejected_b_skirmishers_boots_S_badge_v2.png`.

## Exact continuation point

Next family is `Venomtread`, in this six-key wave:

1. `b_venomtread`
2. `b_venomtread_B`
3. `b_venomtread_A`
4. `b_venomtread_S`
5. `u_glassfang_treads`
6. `u_last_dose_boots_of_the_perfect_poison`
