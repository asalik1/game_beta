# Visual overhaul — 2026-09-03/04 (branch `claude/visual-overhaul-2026-09-03`)

Owner brief: "walks of mobs/bosses/classes are robotic, visuals aren't up to par
in fluidity/motion, the capital is pending a visual update; ultimate freedom;
I will review all work at the end." This is the review board: what changed,
where to look, and what is still open. Every item below is on the branch and
gated (compile + test_quick per commit; the full suite and the mobile re-sync
are the merge gates and are recorded at the bottom).

## How to review

- **Before/after GIFs** of every changed sprite: `~/Downloads/ba_gifs_visual_overhaul/`
  (158, built by `tools/art/ba_gifs.py --base 7fd27a4`). Palette-quantized and
  above game scale — for CHANGE review, not colour judgement.
- **Travel GIFs** (old vs new walk over scrolling ground at the mob's real
  speed): `~/Downloads/travel_gifs_visual_overhaul/` (skeleton, zombie,
  royal_knight, wolf, cultist, stone_broken).
- **In-game**: `shot.bat capital` (nine rooms), `shot.bat tells` (every boss's
  telegraph on one sheet), then play: any mob pack in ch1 (walk juice, dust,
  real deaths, windup crouch), an elite (it stays big now), Crownfall, and any
  ranged class firing while moving.
- The verified QA findings the work was driven by: `art_src/QA_FINDINGS.md`.

## 1. Motion (code) — `enemy.gd`, `boss.gd`, `game_base.gd`, `balance.gd`

- **Stride-locked juice for mobs and bosses**, ported from the hero lane per
  body ARCHETYPE (`Art.MOB_GAIT_SHAPE`): biped = chest rise per step + bank into
  travel; quad = one lope-bob per cycle + nose pitch; glide (robed/floating) =
  lean only. Keyed to the strip's own clock, never a free-running sine.
- **Composed transforms**: every per-frame write to the body sprite goes
  through `_render_tail` as multipliers over the strip's base scale, so the hit
  squash, a windup crouch, the bounce, a spawn-in and the death collapse no
  longer stomp each other or a strip swap.
- **Real deaths**: 21 shipped `<sprite>_death` clips that nothing ever played
  now play (last frame held, then fade); sheetless bodies collapse feet-pinned
  instead of inflating x1.3 and vanishing.
- Footfall dust on contact crossings (budgeted), boss stomp rumble, 8-direction
  turn hysteresis, walk entry on a planted frame, bite-windup crouch + snap,
  pounce stretch, summon spawn-in.
- **Bugs fixed under the same read**: elites reverted to base size on their
  first step (sprite.scale vs art_scale); every Act-1 boss GLIDED on co-op
  guests (the mirror never read `_dir_walk`); the hit squash lifted the feet;
  the walk clock was only half speed-coupled.
- **Boss tells**: 22 bosses each get a hue + ground figure (ring/cone/line/
  cross/square, `Balance.BOSS_TELL`) and a fuse-readable fill. The disc stays
  the hit test — the shapes are accents, so no boss's danger area changed.
  Guarded by autotest `_test_tell_shapes`; reviewed with `shot.bat tells`.

## 2. Walks (art)

Lane: `tools/art/gait_briefs.py` → Codex row → `gait_row_sheet.py` (eyes) →
`install_gait_row.py`. Every install was reviewed on a full-body AND legs-crop
sheet against the outgoing strip first.

- **Mobs (23 files, 4f pose-steps → 6-8f real gaits)**: cultist, elf_druid,
  elf_ranger, royal_knight, orc_rogue, skeleton, skeleton_rogue, zombie,
  vow_sentinel, bandit_scout, stone_broken (its "walk" was the idle ×4),
  wolf, winterfang, blightwolf, duneprowler, storm_harrier, deep_stalker,
  vent_skitter, casket_creeper, fungus_long (8 dirs), stone_base (8 dirs),
  fungus_heavy (S/N).
- **Bosses (walk facings)**: ashpriest S+N, auroch_minotaur S+N, choirmother N,
  hrolgar E+N, kaethra E+N (she had NO north — walked away showing her face),
  korrag E, rotmaw E (was a slender stranger), veyx E, echo N.
- **Geometry re-seats, no regen** (`reseat_strip.py`): nullwarden's walks
  played at ~60% size and 0.2 of the cell off centre; saint_varo_standing E/W on
  the wrong cell; sexton N / serane E+W off centre; morwen 7% small; vess and
  vargoth N tone-matched to their idles.
- **Paladin north walk was BROKEN** (six cells each holding 1⅓ figures) — regen
  queued; see Open.
- Frame edits: bog_lurker f2's floating leg, casket_creeper's sliced tips,
  vent_skitter/veyx speckle.

## 3. Fire-on-move — `mage/warlock/archer/assassin_attack_walk_*`

All 72 attack_walk PNGs lived under `skins/elite/`; the base classes shipped
none, so the feature had been dark for every default character. 12 clips
generated with the documented walk-plus-firing-arm technique and installed
(S/E/N + copies/mirrors + flat).

## 4. Capital

- **The real contrast problem was the floor**: holystone at luminance 188 (3rd
  brightest floor in the game) under buildings at 44. Graded to 151.
- **All 26 capital pieces repainted painterly** (silhouette, footprint and
  parts preserved; tight-crop and 4-frame anim contracts hold; stored at 2.3×
  their render width, was 1.0-1.4×).
- Light sockets on every flame (9 defs; `derive_light_sockets.py`), the depths
  portal's 57% strobe fixed, the room-tour rig fixed (it had shot room 0 nine
  times).

## 5. Corpus hygiene

- 63 sprites stripped of a green keying ring (`despill_rim.py`), including 19
  warlock attack strips the standing triage had ruled out. The scan is at 0.
- 8 candy-bright props graded into the house palette (`palette_grade.py`).

## Open / not done

- **Mage E column DONE**: anim/walk/attack/cast E regenerated as a true right
  profile (`tools/art/profile_clip_briefs.py`; identity = her front idle, view
  ref = blighted_healer's profile idle, action = the old clip frame by frame),
  W = per-cell mirror. Her walk_e reads at stride 0.14 bodies/cycle — the same
  marching-in-place family as every hero walk (assassin 0.22, archer 0.22),
  which the owner ruled to keep at 14 fps; travel GIF old-vs-new in
  `~/Downloads/travel_gifs_visual_overhaul/mage_walk_e_old_vs_new_travel.gif`.
  Her `attack_walk_e` was built from the OLD front-facing walk — regen from the
  new profile walk queued (`art_src/mage_aw_2026-09-04`, chain_aw.sh).
- **Paladin north walk — OWNER CALL**: main's strip was an 8-figure row saved
  6 cells wide (every cell showed 1⅓ paladins), so the north walk he ruled
  "old cycle only" was never actually playable. Two candidates, both built:
  (a) main's own row re-sliced at its real gutters into 8 cells
  (`art_src/paladin_n_2026-09-03/old_cycle_resliced/paladin_walk_n.png`) —
  faithful to the ruling, but two of its frames swing the shield ~40px off the
  body (the placement-jump class he flagged in the E/W rounds);
  (b) a gait-transfer regen (`paladin__n/paladin_walk_n_row.png`): back view,
  shield held on the arm in every frame, silver face + gold cross visible from
  behind per the idle. **(b) is INSTALLED** as walk_n (+ walk_b_n byte copy);
  swapping to (a) is one copy.
- Base warrior walk E/W: the flaming blade degenerates frame to frame
  (classwalk P1) — not addressed.
- Base warlock walk E/W: hood turns to camera vs the profile idle (P1) — not addressed.
- attack_walk_b variants (mage/warlock/assassin) — not generated; the primary
  plays every cycle (art-driven, no defect).
- Queued regens (chain_fix3): stormmouth N (its N was a byte copy of E),
  serane S (was a byte copy of the idle), nullwarden N (front helm on a back
  view) — install with `install_gait_row.py` if the rows landed after hand-off.
- Not addressed from the audits: assassin walk_e cloak balloon + walk_s
  bootless frames, archer walk_n cape green-on-content, saint_varo_blade
  fidelity (192px cell beside 627px siblings), greyrun_lurker attack 0.86x.
- Done since first draft: warlock_ledgerbound duplicated frames (trimmed),
  elf_ranger_attack f2's baked in-flight arrow (erased; the game spawns it).
- Mobile re-sync (`python tools/sync_mobile.py --apply --gate`) — run at merge.

## Gates

- Every commit: compile gate + `test_quick` green.
- Full suite: **AUTOTEST PASS, 172 sections, exit 0** (2026-09-04, on the tree at 252547e: all motion/tell code + the art up to that point).
- preflight --fast: **0 fail apart from the pending --import** (MODULES BALANCE PHYSICS RIGS ARTQA all clean).
- Mobile: (recorded below)
