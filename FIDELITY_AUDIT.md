# Fidelity audit — authored resolution vs on-screen render

**Owner rule (2026-08-24):** a master sprite should be **≥ 2× the size it renders at in game**.
**Tolerance ruling (2026-08-25): strict 5%.** ≥1.90× is acceptable drift — document, don't fix
(archer at 1.95× was the canonical call). **Below 1.90× is a MUST-FIX.** Explicit per-asset
owner rulings override in both directions. Benchmark: base classes ~2.1–2.35×.

**Tooling** — re-run any time (formulas + method in `tools/INDEX.md`):
```bash
# 1. dump live entity scale/placement (a quick Godot boot; run OFF the Codex box)
tools/Godot_v4.4.1-stable_win64_console.exe --headless --path game --script res://fidelity_dump.gd -- entities.json
# 2. audit (summoned adds count as placed via boss-def "summons" keys)
python tools/art/fidelity_audit.py --entities entities.json --csv fidelity.csv
```
`ratio = authored_px / rendered_screen_px`, flag `< 2.0`, must-fix `< 1.90`. Render formulas
(× camera base zoom **1.12**): hero body `52·1.7`; mob cell `scale·1.7·16`; **boss cell
`scale·1.7·16`** (corrected 2026-08-25 — enemy.gd:312 applies CHAR_RENDER_SCALE to mobs AND
bosses; the old "bosses skip the 1.7" was a stale var comment that understated every boss
render 1.7×, hiding 9 under-bar bosses); npc body `body_target·1.7·nsize` (legacy no-target
NPCs render frame WIDTH at `3.0·1.7·nsize·16`; the old dump hardcoded body_target 46 for
everyone and mis-scored every non-46 NPC); critter `cell·_scale`; prop width =
`Balance.SCENERY_RENDER_WIDTH` (**variants render at the FAMILY width and are audited too** —
the tall `*3` slivers at 0.51–0.91× hid behind base-only auditing).

**The strip-metric rule** (matters for any regen): a mob/boss's strips share one body metric —
if the idle cell changes, every ACTION strip (attack/death/boss abilities) must scale by the
same factor (enemy.gd renders actions at the idle cell's scale); WALK strips are normalized by
their own cell (only the body/cell fraction matters) and never need to move.

---

## 2026-08-25/26 remediation — RESULTS

The full work list (everything except the 18 legacy skins) was executed autonomously on
2026-08-25/26; masters/briefs/reproduce scripts archived in `art_src/fidelity_2026-08-25/`.
Corrected-formula baseline was **119 / 263 under 2.0×**; after the pass: **see the table
below** (re-run stamped at the bottom).

### What was fixed (all vetted old-vs-new + independent drift review)
- **Mobs — the 192px batch (18/18)**: rebuilt at 256-cell. 7 robe mobs deterministically from
  the archived 2026-08-08 masters; 11 via identity-anchored idle regens (refs = current strip
  + own hi-res walk/attack master); attacks rebuilt from masters at the new metric; **all 17
  deaths regenerated** (2x2 collapse masters, new idle as identity authority) + banshee's
  attack (its baked scream FX removed — the game spawns it). `stone_broken`'s keep-legacy
  ruling was **rescinded by the owner mid-session** and fixed via a design-LOCKED re-roll
  (flat vent-grill head + restrained core preserved). Body/cell fractions preserved ≤3%.
- **Props (54 rows incl. variants)**: root cause was `install_prop_hires.py`'s min(320)/384
  clamps storing every big prop at ~1× (slivers at 0.5–0.9×) — clamps fixed (2.5× render_w,
  never-upscale guard), all 54 regenerated as faithful repaints and stored at ~2.2–2.5×.
  **All 21 leafy trees now carry authored 4-frame canopy-rustle `_anim` strips** (trunk
  pixel-locked — one 2x2 gen yields static + anim; trunk-band drift 0 on the audit). Dead/bare
  trees stay static by design. Fire/glow props kept their motion (2x2 motion masters for the
  authored ones, re-derives for the rest). Tall slivers re-rolled as portrait statics
  (1.95–2.23×; they keep the runtime wind-shear lean). `audit_prop_anims.py` gained a
  FOLIAGE_PROPS band (trunk-base 12%, `--fix` never realigns authored foliage);
  `build_terrain_art_fix.py` boxes doubled; autotest's tiered-art pins became floors.
- **Critters (7/7)**: re-authored at 2–4× cells (hawk 256, most 128, butterfly 96) with
  `ambience.gd _scale()` divided by the same factors — on-screen sizes unchanged. All ≥2.38×.
- **NPC/misc**: `pilgrims_schism` rebuilt from its own 1536px master (0.56×→~2.5×;
  `art_src/schism_tableau/build_runtime.py` now defaults to the hi-res build); `fallen_bell`
  keyed from its 1254px source; `mill` 640w; `bones`/`rock` regenerated at 256w;
  `choir_censer` 256 + a new 4-frame smoulder anim (and its `asset_dump.gd` phantom
  "player projectile" row removed).
- **Bosses (6)** — per-frame ~1024px remasters (idle + walks; the only lane past the 627px
  multi-frame gen ceiling), actions metric-aligned ×k:
  | boss | before | after |
  |---|---|---|
  | veyx | **0.94×** (art smaller than render) | **1.53×** — its ImageGen ceiling, owner-accepted (below) |
  | stormmouth | 1.37× | **2.01×** |
  | vargoth | 1.58× | **2.02×** |
  | auroch_minotaur | 1.79× | **2.06×** |
  | halla | 1.87× | **2.09×** |
  | fangmaw | 1.89× | **2.42×** |
  Dead legacy `_ability` families (veyx/stormmouth/vargoth/halla/fangmaw, 204–258px cells,
  unreachable via BOSS_FLAT_ANIMATION_LOCOMOTION) purged from both trees.
- **Drift review** (independent second pass per `tools/art/DRIFT_AUDIT.md`) caught and fixed:
  orc_rogue death gore (despotted), orc/skeleton_warrior weapon pop-in/out (re-rolled with
  continuity locks), veyx FX inconsistency frames (re-rolled), stormmouth tabard flicker
  (deterministic brightness match), royal_knight great-helm / vow_sentinel tabard identity
  drift (re-rolled with attire locks + chained deaths). Accepted as design pushes: warm-shift
  convergence toward each mob's hi-res attack palette, elf_druid's extra blooms, softer death
  Laplacians.

### Documented remainder (intentional — owner rulings + 5% tolerance)
- **Skins 18** — excluded from this pass; the planned full skin regen covers them (CLAUDE.md).
- **veyx ~1.53×** — owner-accepted 2026-08-25. A true 2× needs 1340px cells; ImageGen's
  per-frame ceiling is ~1024. **A PixelLab /v2/resize pass (needs owner authorization) could
  close the gap** — the `pixellab_resize_soft_clips.py` lane is the template.
- **archer 1.95×** (benchmark class; "we wont fix a 2.5 percent drift"). SEPARATE finding
  2026-08-26: the archer set shipped FACELESS (hair drawn over the face in every front
  clip, vs her clear-faced splash) — the IDLE was face-restored (portrait-locked per-frame
  regen); **walk/attack/cast still faceless + per-frame gear drift — scope for the future
  full archer pass** (masters in art_src/fidelity_2026-08-25/archer_face_stages/). **ashpriest /
  cinderhide / kaethra / saint_varo 1.96×**, **suli 1.97×**, **warden_corin 1.99×** — all
  inside the 5% tolerance.
- ~~elder 1.89× / caged_beastkin 1.87×~~ — **FIXED 2026-08-26** (owner promoted the to-do):
  full 8-direction regen per NPC (each facing anchored to its current pose still + the
  remastered south master; beastkin's symmetric w/nw/sw as exact mirrors), built at the
  roster recipe (256² canvas, 223px body → 2.35×). suli 1.97× / warden_corin 1.99× remain
  the same-shape candidates if ever wanted (inside tolerance).
- **Boss/mob ACTION strips** at their pre-existing authored resolutions (metric-aligned
  upscales, no new detail): veyx arc/summon/enrage, stormmouth bolt/cast/enrage, auroch's
  four action families, halla's bolt/enrage/freeze/summon — a future per-frame or PixelLab
  pass can lift them; idle+walk (what a player stares at) carry real detail now.
- **Judged-lint warns inherited from shipped geometry**: veyx_walk_s ANCHOR (the funnel
  sways by design), auroch melee / fangmaw leap FEETSLIDE (genuine lunges), fangmaw attack
  EDGECUT (arc extreme). Boss-strip BLEED = painterly soft-alpha FX (benign class).

### Final numbers (re-run 2026-08-26, corrected formulas)

| Category | n | median | min | under 2.0× | under 1.90× (must-fix bar) |
|---|---|---|---|---|---|
| Class | 6 | 2.12× | 1.95× | 1 (archer — tolerance, owner-ruled) | 0 |
| Skin | 23 | 1.22× | 1.17× | 18 (EXCLUDED — planned skin regen) | 18 (excluded) |
| **Mob** | 41 | **2.63×** | **2.03×** | **0** | 0 |
| Boss | 21 | 2.06× | 1.53× | 5 (veyx accepted ceiling + 4 at 1.96×) | 1 (veyx — owner-accepted) |
| NPC | 42 | 2.31× | 1.97× | 2 (suli/warden_corin — tolerance) | 0 (elder + caged_beastkin fixed 08-26 via the 8-dir pass) |
| **Critter** | 7 | **2.80×** | **2.38×** | **0** | 0 |
| Prop | 123 | 2.23× | 1.95× | 1 (tree_winter3 — tolerance) | 0 |
| **TOTAL** | 263 | | | **27** (was 119 at the corrected baseline) | |

Every remaining under-bar row is excluded (skins), owner-ruled (veyx, archer), inside the 5%
tolerance, or the confirmed elder/caged_beastkin 8-dir to-do. **No unaccounted must-fixes.**

- Full sortable data: the `--csv` output (session CSVs archived beside the masters).
- Re-run after any resize/regen to confirm an asset crossed 2×.
