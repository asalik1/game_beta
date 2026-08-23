# Elite-skin generation — failure modes + the per-frame QA gate

Findings from generating the five era-3 class concepts as elite skins (2026-08-21,
`build_skin_family.py`). The ImageGen masters look fine on a contact sheet and pass
`verify_art`, yet still ship visible in-game defects. **verify_art and a facing glance
are NOT sufficient QA.** Every frame of every clip must be inspected before install.

## The gate: scrutinize EVERY frame of EVERY clip

For each frame, in each of the 5 authored rows, confirm ALL of:

1. **Weapon/prop held** — the staff / bow / dagger / ledger is in hand in *every* frame,
   including windup and recovery. Generators drop it in settle frames or swap it for a
   free-floating orb.
2. **Face intact + identical** — same clean face every frame. Generators melt/smear/age
   the face in scattered frames (esp. recovery).
3. **Facing consistent** — the figure faces the row's ONE direction in every frame. It must
   NOT turn to the opposite direction in the windup and turn back to act (see Facing flip).
4. **Feet read** — for walks, feet visibly ALTERNATE below the hem; opposite feet lead in
   the two contact frames. Not a glide.
5. **Clean gutters** — nothing (projectiles, FX, stray limbs) floats in the green gutters
   between figures; that breaks the slicer (see Mis-slice).
6. **No green content where you need the figure** — fade/ghost frames drawn IN green get
   keyed out (see Green fade).

`verify_art` catches #5 (GHOST vertical + HSPLIT lateral), the dash size pulse (FRAMEDEV),
and edge alpha (BLEED). #1-4 and #6 are eyes-only.

7. **Constant body height in the dash** — the hero renderer locks a strip's on-screen scale to
   FRAME 1's body height (`player_core _measure_hero_frame`: on-screen height of frame i =
   target * bh_i / bh_1). A dash whose body height varies frame to frame therefore renders as a
   size PULSE, and NO per-frame post-fix resolves it (normalizing to constant height blows up the
   width of wide dive/ball frames). Brief dashes as an UPRIGHT cape-flourish at one baseline
   (like the base archer dash), never a tumble/roll or horizontal dive. `verify_art` FRAMEDEV
   flags a dash frame >22% off frame 1.

## Observed failure modes and the brief fix

| # | Failure | Where it bit | Fix in the brief |
|---|---|---|---|
| Facing flip | windup frames face the OPPOSITE direction, figure turns to act, turns back | mage attack/cast (E row: f1-2 faced W) | "the figure faces the row's ONE direction in ALL frames; do NOT turn/rotate/pivot; f1 and fN already face that direction" |
| Weapon dropped | staff missing / replaced by a bare-hand orb in some frames | mage attack (front row cupped an orb), mage cast (f6-7 dropped staff) | "the staff is GRIPPED in EVERY frame of EVERY row; the bolt comes from the STAFF tip; never a free-floating orb" |
| Face distortion | face melts/changes in scattered frames | mage cast recovery | "identical clean face in every frame; do not distort/melt/smear/age" |
| Mis-slice | released projectiles drawn FAR out into the gutters; slicer cuts through the figure (bow left in the neighbor cell, bowless archer + stray arrows) | archer Multishot (attack2) — got GHOST warns that were wrongly dismissed | "do NOT draw released/flying projectiles; the game spawns them; NOTHING in the gutters; every column is one clean figure" |
| Lateral stray | a second weapon/limb floats BESIDE the figure in the SAME rows (a duplicate bow to the archer's left in walk/ult). GHOST misses it (no vertical gap); if a cape bridges the columns, HSPLIT misses it too | archer walk_s (stray bow), archer ult (loose arrows) | same "nothing beside the figure, one clean silhouette per cell". When it ships, remove it surgically (`scratchpad/despur_strays.py`, keep the largest component / keep bow limbs >=160px) rather than re-rolling |
| Dash size pulse | body height varies across dash frames → engine's frame-1 scale lock renders later frames up to 1.4x → the hero grows/shrinks mid-dash | archer Tumble (188..333px), assassin dive (0.74x/1.43x) | brief an UPRIGHT constant-height cape-flourish, one baseline; or reuse the clean walk cycle as the dash (constant height). Never a tumble/roll/horizontal-dive dash |
| Glide walk | floor-length robe hides the legs → no foot alternation, figure slides | mage walk_e/w | "feet + lower legs VISIBLE below the hem and clearly ALTERNATING; front hem lifts with each step; opposite feet lead in the two contact frames" |
| Green fade | teleport/ghost frame drawn as translucent GREEN → green-key deletes it | mage dash (Blink) f4 | acceptable when a vanish is wanted (reads as the teleport); if a visible ghost is needed, brief "pale translucent, NOT green" |
| Diagonal-walk quality | authored SE/NE/SW/NW walks read wrong | archer | owner ruling: STOPGAP by duplicating cardinal walks as ASSETS (SE/NE=E, NW/SW=W), never a builder flag — a code flag silently clobbers future distinct diagonal art |

## Fix patterns

- **Targeted rebuilds, never a full-skin rebuild for a one-clip fix.** A full
  `build_skin_family.py <skin>` recomputes the shared cell and regenerates every strip,
  silently clobbering hand-placed assets (e.g. the archer's duplicated diagonal walks).
  Instead rebuild one clip: `scratchpad/build_one_clip.py <base> <clip> <stem> <cols>`
  (5-row sheets) or `rebuild_walk_dir.py <base> <dir> <cols>` (one walk direction + mirror).
  Copy the changed strips to mobile by name.
- **Different cells are fine.** A clip rebuilt in isolation gets its own cell (e.g. 249px vs
  the skin's 429px). The hero render measures each strip's ~235px body per-clip
  (`_with_render_meta`), so on-screen size is identical; cells need not match.
- **Duplicated assets > code stopgaps** (owner ruling 2026-08-21). A builder flag that
  re-derives a stopgap on every rebuild will silently overwrite real art wired in later.
  Prefer explicit duplicated PNGs that a future asset naturally replaces.
- **Re-roll with the specific negative constraint.** Each failure above has an explicit
  brief clause; add it and re-roll rather than trying to salvage a bad frame by compositing.
- **Trust the gate you already have.** The archer GHOST warn was real; dismissing it as
  "benign arrows" shipped the mis-slice. A GHOST warn on an ability that throws something =
  investigate, don't wave off.
- **Surgical stray removal (`scratchpad/despur_strays.py`) beats a re-roll for detached
  fragments.** A stray bow / arrow fragment is a separate connected component; deleting it
  (keep the largest component for loco, or the largest + limbs >=160px for actions) yields a
  clean frame instantly and deterministically, where a fresh gen risks new problems. Re-roll
  only when the figure ITSELF is wrong, not when a loose fragment rode along.
- **A detached component is NOT automatically a stray -- compare the BASE sprite first.**
  Some detached components are CONVENTION: the base archer bakes a small arrow at loose (f7),
  the base warrior's tabard hangs as its own component between the legs, and casters may show
  a spell orb at release. Scan the matching `<class>_<clip>_s.png` base strip the same way; a
  detached component the base ALSO has is legit (keep it), one only the skin has is the
  mis-slice (remove it). The warrior skin's floating SWORD TIP (waist-left, frames 4-6) had no
  base equivalent and was removed; its tabard, which the base shares, was left. When the base
  bakes nothing but the skin bakes a coherent projectile (warlock orb), that is a skin-only
  inconsistency -- flag it for the owner rather than silently deleting a possible design beat.
- **Melee basic attacks ALTERNATE (attack <-> attackb).** Both swings are separate clips and
  BOTH need the per-frame gate; QAing only `attack` misses the cleave/second-swing. A melee
  skin must ship a complete 8-dir `attackb` or the alternation silently falls back to one
  swing (autotest `_test_swing_alternation` now asserts this for the elite skins).
- **When a defect ships, add the test, then answer "why didn't it catch it" honestly.** The
  walk stray shared the figure's vertical band (GHOST is vertical-only) → added HSPLIT
  (lateral). The dash was never body-gated (dash is not in BODY_GATE_CLIPS) and CLIPSCALE uses
  the MEDIAN while the engine uses FRAME 1 → added FRAMEDEV (frame-1 deviation, dash-scoped).
  Both were calibrated to ZERO false positives across accepted base-hero art before shipping.

## An ability plays a DIFFERENT clip than its name (player_core ABILITY_CLIP)

QA the clip the ability actually plays, not the one its name suggests. From `ABILITY_CLIP`:
- mage Frost Nova = **cast**, mage Meteor (ult) = **cast** too (one clip, both abilities);
  mage Blink = **dash**.
- archer Arrow Storm (ult) = **cast** (NOT the `ult` clip -- despurring the ult clip did
  nothing for the arrow-storm specks; they were in `cast`).
- warlock Shadowbolt = **attack**, warlock Hex = **ult**, warlock Void Rift (ult) = **cast**.
- warrior berserk swaps the a1 cleave onto the **ult** clip (red blade) -- so "the ult" plays
  during a normal cleave under berserk.

## Fire-on-move: the `attack_walk` clip (owner 2026-08-22)

Spamming a low-cd basic WHILE MOVING used to lock the standing swing pose sliding over the
floor. `player.gd` already swaps `action_clip -> "attack_walk"` when a basic is cast moving
(`velocity > 20`), and a mid-cycle re-cast lets the stride finish instead of restarting -- so
the gait stays continuous under spam. Art-driven: no `<base>_attack_walk` strip = the standing
swing, exactly as before. Registered in `art.gd` HERO_CLIP_FILES + FPS (12).

- The swap fires for `action_clip in ["attack","attackb","attack2"]`. Per `ABILITY_CLIP` the
  enhanced-base basics land there: mage Firebolt=`attack`, warlock Shadowbolt=`attack`,
  archer Quick Shot=`attack`, **assassin Fan of Knives=`attack2`**. All four covered.
- Build lane = `scratchpad/attack_walk_codex.py` (stage/build/install). 8-frame WALK-AND-FIRE
  row: the feet ALTERNATE below the hem while the upper body fires ONCE per cycle. NO baked
  projectile (the game spawns it -- just the fire MOTION at the hand/bow).
- **THE TECHNIQUE (owner 2026-08-23): it's the WALK clip + a firing arm, not a from-scratch walk.**
  `stage()` uses `<base>_walk_<dir>` as Image 1 (the leg-cycle ref) and the brief says "reproduce
  this exact walk -- same crossing gait, closed garment -- change ONLY the hand to fire." From-
  scratch walk briefs (even with a per-frame boot storyboard) glided or never crossed the legs, AND
  a "front-slit" instruction made ImageGen draw bare/exposed legs -- BOTH rejected. Referencing the
  real walk carries its crossing gait for free and keeps the garment closed. Keep the brief SHORT.
- Author S/E/N; E serves SE/NE; **left MIRRORS right** (W/NW/SW = mirror of E, owner ruling); flat = S.
- Per-direction best version: `build <skin> <dir> <vNN>` picks that source (else newest). Judge each
  by eye -- legs must CROSS like the walk, garment stays closed (no exposed legs), no baked flame.
  The mage firebolt spark shares her skin/gold palette (un-maskable except its bright-yellow core),
  so keep it out at gen time rather than trying to erase it after.

## verify_art gates added for this class of defect (2026-08-21..22)

- **FRAMEDEV** (dash): a frame rendering >22% off frame 1 -- the engine locks a strip's scale
  to frame 1, so an uneven dash body height plays as a size pulse (archer/assassin dashes).
- **HSPLIT** (loco): a horizontally-disjoint band in a walk/idle frame -- lateral mis-slice
  (GHOST is vertical-only).
- **STRAY** (idle/walk/attack/attackb/attackc only -- clips that should be ONE clean figure):
  a detached component (>=240px, or >=380px total) off the figure = baked projectile / mis-slice.
  Scoped OFF attack2/cast/dash/ult because those legitimately bake AoE/FX (base-hero casts carry
  2-3k px of authored effect) and gating them floods -- their strays are an EYES-ONLY review
  item: the game spawns projectiles, so DESPUR baked ones before install.
- **PARTIAL** (attack/attack2/attackb/attackc/cast/ult): a frame whose figure MASS is <35% of
  the clip median = a butchered slice (thin sliver, cut-off body, or a projectile-only cell
  counted as a frame -- the warlock hex). Mass not height, so a full-height sliver still trips.
- **ANCHOR (attack_walk exemption)**: `attack_walk` classifies as `walk` (last token), so it
  runs the loco ANCHOR checks -- but the bow/staff/arm DRAW legitimately raises the bbox top
  (archer S draw = 235..268px, 12%), the same reason plain attack strips are drift-exempt. The
  render scale-locks to frame 1, so the BODY stays constant and only the raised weapon grows the
  box. So the bbox-HEIGHT drift is exempt for attack_walk; feet-line and centroid stay active (a
  real walk keeps its feet planted -- that's the check that catches a bad walk).
- These are ADVISORY WARNs, calibrated to ~zero false positives on accepted base-hero art.

## Deterministic frame fixes (no re-roll) -- scratchpad helpers

- **despur_strays.py** `<glob> largest|keepbig [min_keep]` -- drop detached mis-slice
  components (keep the figure, or figure + parts >= min_keep). Baked projectiles, stray weapons.
- **frame_swap.py** `<glob> <dst> <src>` -- overwrite a bad frame with a good neighbour (the
  warrior dash f4 crouch+fragment -> f3; the mage cast f6 warped staff -> f5). Owner's
  "overwrite that frame with the previous frame".
- **frame_reorder.py** `<glob> "1,3,4,4,5,6,7"` -- re-time a clip (mage Blink: front-load the
  vanish so she blinks out early, not mid-dash). Frame 1 of the result MUST be non-empty (the
  renderer measures it for scale).

See `IMAGEGEN_SPRITE_PIPELINE.md` for the full generation→build→install pipeline; this file
is the skin-specific QA addendum learned from the era-3 elite-skin batch.
