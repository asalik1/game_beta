# Crownless — September 29 session handoff

Owner-authorized orchestrator round on `codex/crownless-wayfinder`
(`C:/Users/asali/Projects/MMO/.codex/worktrees/crownless-wayfinder`), 2026-09-28 ~22:00 UTC to
2026-09-29, before the 21:00 UTC (17:00 America/New_York) deadline. Starting HEAD `437217c`.
Owner priority for the round: **the visual look of the game**. The 46 preserved unrelated files
(two tracked `shot_road_hunt.gd` edits and 44 untracked) were left alone and stay uncommitted;
byte-identity vs `build/qa/session-sept26/initial-preservation.json` re-verified at close (result
in the final-state section).

## How the work was done
The root session (Claude Fable, orchestrator only) ran the v2 architecture from
`tools/orchestration/ARCHITECTURE.md`: Codex (headless `codex exec`, astra high) implemented 25
tasks in sparse lane worktrees under the one-heavy-run lock policy; every lane went through a
tiered Claude Workflow review (`build/qa/session-sept29/tools/review_v2.js` — R2 = 3 Opus lenses,
R1 = 1; a fixer; a receipt-reading Opus judge), with every agent's model pinned (Opus 5.5 /
Sonnet 5, never Fable). Conflicting lanes were merged by Codex in-lane (8 merges, 2 of them
semantic reconciliations the judges pre-identified). The root squash-applied accepted lanes one
train at a time with a quick suite after each train and batch full+mobile gates every few lanes.
Two usage-limit outages killed 11 in-flight review agents; all six workflows resumed from cache
with zero loss. Session evidence, notes and ~466 owner-review captures are local under
`build/qa/session-sept29/`. The experiment log for the round is appended to
`tools/orchestration/ARCHITECTURE.md` §8.

## Delivered — the world and presentation (the visual round)
- **Walls with mass** (`a7d9b26`): north walls rise to hero height with shaded faces, an
  ambient-occlusion seam and a warm top lip; everything beyond a wall sinks to dark stone so the
  floor is the brightest shape on screen; pilasters read as relief; doorways never show the void;
  collision, door lanes and torch anchors unchanged.
- **Room light composition** (`e173bc2`): floors ease toward a dim frame at walls and corners
  (cached per-cell vignette, value-floor safe on both renderers, corridors and previews included);
  torches, braziers and hearths cast warm visible pools with contact rings even on bright stone.
- **World read** (`aa44002`): roads meander with varying width per room seed while holding door
  lanes, bridges and the arcade arch straight; no more smoke-band roads on dark floors; capital
  paths read as laid stone; the keep and capital palettes shift warm at the same value; arcade
  backdrops sit on foundations with contact shadows.
- **Floor composition** (`1a43d72`): room-scale wear patches biased to walls and corners, rubble
  and moss clustered along the inner wall line, and the capital's planters, banners and damp
  patches genuinely visible; capgap 0.
- **Light coherence** (`993ce0a`): flame strips, halos and floor pools share one illumination
  clock per light with stable phases inside the 10-12%/25% contract; sealed gates freeze; torch
  shadows stop resyncing every frame.
- **Weather depth** (`f7a7ec1`): rain, snow and leaves fall in a distant layer behind the actors
  and a sparse near layer in front, fading instead of popping, never dragging with the hero.
- **Enemy readability** (`343de51`, `14072ea`): hostiles carry a warm rim lit away from the key
  light, scaled by floor luminance (owner look pending — see below); hit flashes moved to a
  hue-preserving highlight channel so windup tells, enrage tints and statuses stay visible under
  sustained fire, and status tints end exactly with their status.
- **Combat feel** (`fe23b92`, `d8b111d`): camera shake is a deterministic damped recoil (same at
  30/60/144 fps, 0% comfort = perfectly still); damage numbers stack per target, merge rapid hits
  into popping totals, keep crits standalone in gold, and killing blows stay visible.
- **Safe-zone danger** (`0dd03a3`): a thin pulsing elliptical rim plus a world saturation drain
  replaces the old 70%-of-screen red flood; restores on every exit path; comfort slider calms but
  never removes the warning.
- **HUD** (`da9cbff`, `2709471`, `47ea5ff`): bars sit in bronze troughs with enamel shading; the
  menu shortcut row hides in combat; duplicate log lines collapse with a count; side panels dodge
  the hero; co-op chat stays above the feed on every canvas; dialogue centers on all aspects.
- **First impression & story** (`5b50f1f`, `fb22646`, `6b349be`): the painted title screen
  drifts with sparse embers and persists behind the roster and class selection; story plates keep
  their exact on-screen blend when advanced mid-dissolve and dissolve in register; painterly
  scenery samples linearly so it stops shimmering on pans.

- **Menu reskin** (`21deb4b`, `c2a3d82`): every menu trades the flat navy dashboard for a
  painted bronze frame kit generated against the cover chrome (two art rounds, gated by an
  independent art review), with grade-tinted slot rims replacing the "[F]/[S]" prefix text, a
  five-piece forged divider, compact slices that fit 25px controls, warm ground colors, and a
  field-by-field flat fallback when textures are missing. Sliders and scrollbars stay
  deliberately flat for affordance. Masters, prompts, rejected round 1 and both contact sheets
  are in `art_src/ui_frame_2026-09-29/`.

## Delivered — correctness and UX
- **Duels** (`6a385cf`, `c122089`): stuns show Stunned (Ice freezes stay Frozen); crits roll
  against the defender's real CritRes; Meteor's true portion survives evasion/resist; mixed
  builds refused at the handshake (NET_VERSION 0.3.19).
- **Player data** (`b32cd46`, `dc7cff0`, `dbaa188`): Grand potions survive save/load (and loot
  recovery, defensively); daily rewards mail their overflow instead of vanishing on a full bag,
  with exactly-once claiming across crashes.
- **Combat math** (`a945520`, `1b73762`, `cb8e022`): Arrow Storm uniform across skins with the
  Advance proc reaching it; guest burn/bleed use current crit stats after gear changes; the ward
  healing tax and Rust sting reach regeneration, lifesteal and every routed heal.
- **UX** (`bde9653`): forge refusals name the exact gold shortfall; mail notices point at the
  HUD envelope; the daily claim is keyboard-accessible.
- **Mobile**: synced and gated after each batch (`78c1697`, `1127744`, plus the final sync below).

## Validation
Every lane: compile gate + its own quick suite and targeted rig through the machine lock, first
by the implementer (one heavy run), again by the review fixer, receipts verified by the judge
against the exact committed tree. On the integrated branch: quick suite after every train (7/7
PASS), full suite + mobile gate batches (2/2 PASS mid-session), and the final full + mobile +
strict preflight block at close (results in the final-state section). A load-sensitive timing
flake in the safe-zone test was root-caused (SceneTree fires timers before tweens) and hardened.

Limits: coverage is headless suites plus ShotRig captures; no physical phone, controller or live
multi-process dedicated server; reviewers judged visuals from rig captures — the owner has not
seen any of this in-game.

## Owner should look at (aesthetic calls made without your eyes)
Captures for all of these are under `build/qa/session-sept29/owner-review/` (per-lane subdirs):
1. **The whole environment pass in motion** — walls, vignette, roads, dressing and palette
   together change how every room reads. `shot.bat polish --tour` is the quickest in-game look.
2. **Enemy rim light** (lane-q `hit_highlight/`, `polish/rim_*`): reads as a crisp warm contour
   on near-black bodies; the judge explicitly left the exact look to you (knobs in balance.gd:
   ENEMY_RIM_*; easy to soften or disable).
3. **Keep/capital warm palette shift** and the **camera recoil feel** (deliberately restored
   closer to the old energy, cap 12px).
4. **Damage-number stacking** and the **HUD diet** (menu row hidden in combat) — behavior
   changes you may want tuned.

## Remaining follow-ups (found by reviewers, deliberately not done)
- S9 menu 9-slice reskin (warm forged frame replacing the navy dashboard look) — the last big
  item from the art-director review; needs generated art, flagged for a dedicated round.
- S12 boss ACTION strip remaster (vargoth/veyx families render below their idle fidelity).
- Party frames don't share the enamel bar dressing; the navy info box keeps an empty band while
  the menu row hides; capital planters have no colliders; landmark clearance still uses the
  straight road lane; ally-marker hysteresis and net_test stage 12 (both from 9/28) remain open.
- Copy tasks: character-sheet crit tooltip (PvE-only DoT crits), ward-pants "20% shorter" text
  vs cc_mult 0.5 mismatch.

## Final state
- This round: 26 reviewed tasks (incl. the two-commit menu reskin) + 4 mobile syncs + the close
  commits. A bonus round after the first close added the menu reskin (T52): art generated and
  twice art-reviewed, wiring reviewed like every other lane.
- Closing gates ran TWICE (once at the first close, again after the menu reskin): full desktop
  suite PASS (357s final), mobile import/compile/quick gate PASS, strict preflight PASS (178s
  final). Quick suites passed after every integration train.
- Note for the next session: the workshop-preview geometry oracle
  (professions_visual_geometry._texture) exempts only GradientTexture rules — it will flag the
  forged divider's stretched AtlasTexture rails; add the exemption when that rig next runs.
- One incident, contained: a round-1 art agent strayed into the owner's main MMO checkout and
  committed there; the stray commit (art files only, unpushed tip) was removed with a mixed
  reset and the checkout's own modifications left untouched. Briefs for main-worktree work now
  pin the absolute working directory.
- The 46 preserved unrelated files verified byte-identical against
  `build/qa/session-sept26/initial-preservation.json` (46/46, none missing, none changed); the
  two tracked `shot_road_hunt.gd` edits remain uncommitted working-tree modifications.
- Lane worktrees `cw-lane-n/p/q/r/s/t` removed (junctions unlinked first; the main asset count
  read 20,267 after every removal) and their `sept28/lane-*` branches deleted.
- Evidence, briefs, provider outputs, orchestrator notes and the owner-review captures are local
  under the ignored `build/qa/session-sept29/`.
- The branch was pushed to `origin/codex/crownless-wayfinder` at close (fast-forward, no merge),
  matching the September 28 close.
