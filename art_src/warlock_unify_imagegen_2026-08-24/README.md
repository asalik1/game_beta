# Warlock full-unify via ImageGen — 2026-08-24

## Why
The base warlock was **two generations stitched together**: `idle`, `walk`,
`attack`, `attack2` were the crisp ImageGen generation (slender, clean face,
smooth vertical gold tabard); `cast`, `ult`, `death` were older **PixelLab-r2**
art (`f0ed5ea2`, stocky, crossed-strap robe, softer face) that commit `9911ac7`
only **scale-matched** to the crisp clips — never proportion/face-matched. The
owner noticed the idle "looks cleaner/more slender/better face" than the action
clips and ruled: **full unify** — regenerate the r2 clips to match the crisp idle.

(The warlock has **no** `run`/`dash` clips, so the r2 set is exactly cast + ult
+ death. `idle`/`walk`/`attack`/`attack2` were already crisp and were left alone.)

This supersedes the interim PixelLab r2 ult drift-fix (`backup/warlock_ult_drift_2026-08-24`),
which fixed the purple-robe drift but stayed on the stocky r2 design.

## What
ImageGen (Codex) regeneration of **cast (8 dir), ult (8 dir), death (flat)** —
17 direction-strips, 9 frames each — matching the crisp idle:
- lean/slender build, clean gaunt face, deep hood
- near-black robe, smooth vertical gold tabard + gold V-collar + red throat-gem,
  gold hem/cuff trim
- violet-flamed bone skull familiar (left shoulder), open red grimoire (right hand)
- **cleaner, smaller baked FX** (owner ruling): the game spawns the void-rift /
  hex ring + beams + burst separately, so the strips carry only body motion +
  the persistent skull/grimoire + a small violet hand-glow.

Ability→clip mapping (unchanged, `player_core.gd` ABILITY_CLIP): warlock
`a2` Hex → `ult` strip; `ult` Void Rift → `cast` strip.

## How (reproduce)
1. Identity refs = the crisp idle per direction (`refs/idle_<dir>.png`, extracted
   from `warlock_anim_<dir>` frame 0) + `refs/idle_s.png` as a front consistency ref.
2. Briefs: `make_briefs.py` writes one stage per `<clip>_<dir>` (a horizontal
   9-frame row, green chroma, per-direction facing + per-clip storyboard).
   `cast_s` was the hand-authored de-risk proof; `cast_nw` was re-rolled once with
   an added anti-touch spacing rule (arms-spread frames were bridging gutters).
3. Generate: `tools/art/run_codex_batch.ps1 -MaxParallel 1 -MinFreeGB 1.3
   -TimeoutSec 600 -ExtraArgs "--dangerously-bypass-approvals-and-sandbox"`.
   Raw + keyed sources land in each stage dir (`<stem>_v1.png`, `<stem>_v1_keyed.png`).
4. Build + install: `python tools/art/build_warlock_unify.py --install` — detects
   the 9 figures (splits over-wide spans at internal valleys when frames touch),
   crops, normalizes on ONE frame-0-derived scale (preserve motion) to the crisp
   idle body height (~205px content), feet-anchors to a common baseline, packs to
   a 277 cell, hard-alpha + green-rim despill, writes `game/` + `mobile/`
   (originals backed up to `backup/warlock_unify_2026-08-24`).
5. QA sheets: `qa/warlock_<stem>.png` (built strips). Full drift-audit review done
   frame-by-frame before install — all 17 on-model, correct facings, feet aligned,
   no clipped frames, FX modest violet.

## QA status
- `verify_art warlock`: 0 geometric FAIL; WARNs are the benign baseline only
  (STRAY = the skull familiar + FX props; BLEED = soft-alpha FX glow) per the
  CLAUDE.md WARN-triage doctrine. No FEETSLIDE / anchor / HEROBODY / CLIPSCALE.
- Each direction is engine-normalized independently (`player_core._measure_hero_frame`),
  so the strips render at the idle's on-screen body size.

## Owner QA focus (in-game)
Watch cast (Void Rift) + hex (a2) + death in-game at 1x; confirm the warlock now
reads as the same slender character across idle → attack → cast → ult → death.
