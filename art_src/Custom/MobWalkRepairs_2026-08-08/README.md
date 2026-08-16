# Mob locomotion repair (built-in ImageGen, 2026-08-08)

These are the preserved source masters for the owner-flagged mob walk pass.
Rebuild production assets with:

```powershell
python tools/art/build_mob_walk_repairs.py
```

Generation used the live static sprite as the binding identity reference and
the old walk strip only as a negative timing/layout reference. Walk prompts
requested four left-facing frames with explicit A-contact, passing,
B-contact, passing timing; quadrupeds used opposing front/rear contacts and
crawlers used alternating diagonal leg groups. Every installed pose is a
complete generated frame. Per the owner rule, the builder never cuts, mirrors,
pastes, or otherwise edits individual limbs/body regions.

The special-note override is binding: `null_acolyte` keeps its existing
floor-length identity; the nine `*_idle_master.png` designs have a continuous
floor-length hem and no visible legs or feet. All ten now use dedicated
`*_motion_master.png` four-frame glide/breathing loops instead of legged walk
strips. These are complete generated poses with readable breathing,
arm/equipment travel, and robe-fold/hem sweep while the head, torso, facing,
height, and ground point remain locked. Both the first overly subtle attempts
and a later over-exaggerated leaning/bobbing pass were rejected and are not
installed. The builder also
rejects any robe loop with fewer than three distinct complete frames.
`qa_robe_motion.png` compares the identity and all four installed motion poses.
Their matching `*_attack_master.png` strips
use the same full-height identity and keep legs/feet covered in every complete
generated frame. `qa_robe_attacks.png` compares each installed attack directly
against its accepted idle. The Static Caller and Plague Chanter first
attempts were rejected (invented halo; visible toe) and are not retained.

`skeleton_rogue_master.png` is a complete upright Barrow Wight redesign in a
strict 4x4 idle/walk/attack/defeat grid. Its dedicated
`skeleton_rogue_walk_master.png` isolates the gait, and
`skeleton_rogue_walk_opposite_master.png` supplies the separately generated
opposite step (raised screen-left knee, planted screen-right boot). This keeps
the lead leg visibly alternating without mirroring the cape or sword.
`fungus_heavy_walk_n_master.png` and
`fungus_heavy_walk_s_master.png` are isolated four-frame replacements for the
two specifically flagged Spore Shambler directions. The oversized pale claw
is identity-locked to screen-right in the north/back strip and screen-left in
the south/front strip (the same anatomical arm viewed from opposite sides),
while the other arm remains the thin root arm in every complete frame.

Every prompt required a perfectly flat `#00ff00` screen, broad gutters,
stable scale/center/ground line, the exact input identity and equipment, no
crop/shadow/text/grid/watermark, and no new or missing limbs. The builder
removes the key, hardens alpha, restores live canvas/scale/ground metrics, and
writes `qa_walk_contact.png` for four-frame review.
The accepted canvas, anchor, and body-scale metrics are frozen in
`references/`; rebuilds never measure their own prior output, preventing
one-pixel scale drift across repeated runs. Walks use the idle reference—not
the legacy walk canvas—so locomotion cannot change apparent body size.
Robe sheets are separated only through transparent ImageGen gutters, then each
complete pose is aligned by its upper-body and ground anchors. Flowing cloth
therefore cannot drag the character core sideways, and nominal quarter-width
cuts cannot create detached weapon or robe fragments.

The consistency follow-up preserves complete legacy frames for Cinder Whelp,
Storm Harrier, and Frozen Guard, translating only the whole frame to a common
ground point. Bog Lurker's walk, Grove Horror's
attack, and Marsh Spider's attack use dedicated complete-pose ImageGen masters
so no limb or artifact is repaired by compositing partial body regions. The
Grove and Spider action canvases are allowed to grow to contain the widest
pose instead of clipping it. At runtime, the first idle cell is the persistent
body-scale reference; action changes cannot overwrite it, and every strip is
ground-anchored even when its cell size happens to match the current strip.
Bog Lurker's oversized walk canvas is explicitly rendered at that persistent
idle body scale.
Marsh Spider bypasses its older direction set because those sheets vary in
subject scale (most visibly west); the installed complete-frame flat walk has
the same 386px cell and idle-body scale and uses the normal horizontal-facing
path instead.

The follow-up attack pass replaces the legacy Spore Shambler, Hollow Soldier,
Wildfang Howler, Wildkin Ranger, and Void Shade strips with four complete
ImageGen poses apiece. Those old strips contained below-feet or horizontal
neighbor fragments and/or inconsistent body anchors. The builder accepts these
masters only when it detects three genuinely empty chroma gutters, then locks
each complete pose by upper body and ground point. A first Void Shade rerender
was rejected for isolated violet pixels, and two horizontal rerenders were
rejected for unsafe gutter separation; none of those results is installed. Its
accepted source uses a
padded 2x2 layout so the single screen-left sword can remain entirely within
each complete pose without overlapping the neighboring pose's x extent. The
builder validates transparent margins around all four quadrants before
assembling the horizontal runtime strip. Foliage-bearing Wildkin uses
a magenta key, and the chroma remover selects green or magenta despill from the
sampled border instead of leaving colored edge pixels. Review all seven strict
attack replacements in `qa_consistency_attacks.png`.
`qa_idle_only_contact.png` separately proves the owner-priority robe set,
including the unchanged Null Acolyte reference.
`qa_barrow_walk.png` is a nearest-neighbor enlargement of the installed
Barrow Wight strip for explicit contact-pose review.

## 2026-08-15 owner pass (Wildfang Raider / Frost-Bound Soldier / Bog Lurker / Vow Sentinel)

Owner report: "Wildfang Raider walk is bad, attack shifts up and shows a piece
of another frame under his feet; Frost-Bound Soldier's attack doesn't slash in
the direction he faces; Bog Lurker's attack is not vicious enough; Vow Sentinel
disappears when walking." Headless Codex `image_gen` (`codex exec`, briefs
archived beside the masters as `*_codex_brief_2026-08-15.txt`), one master per
clip, deterministic build via this directory's builder:

- **Vow Sentinel** — no regeneration. `vow_sentinel_walk.png` had shipped 100%
  transparent on 2026-08-13: `normalize_locked_motion` measured the upper-body
  anchor on the WHOLE 4-frame `_anim` reference (median x ≈ 355 on a 192 cell),
  the extents clamp went negative and every frame scaled to nothing. The builder
  now crops the reference to its first cell, splits this master at its real
  gutters (poses 2-4 crossed the quarter-width cuts), and `save_strip` refuses
  any fully transparent frame. Rebuilt from the existing 2026-08-13 master.
- **Wildfang Raider (`orc`) walk** — `orc_walk_master.png` is now ONE ROW of
  EIGHT phase-labelled figures (contact / load / pass / reach for each leg).
  Two 2x2 four-frame re-rolls (the storyboard wording that had "solved" it on
  08-14, and a wide/tight/open/opposite variant) both came back with the same
  leg leading in both stride cells and the body ~11% short; neither is
  retained. The previous installed master is kept as
  `orc_walk_master_rejected_2026-08-14.png`. Installed as an 8-frame 192px strip
  through `normalize_locked_motion` (torso locked, idle body height, 1.5x width
  allowance) — the engine's strip reader is frame-count agnostic; at the 2x
  walk clock the loop runs 0.67 s. The attack was NOT touched: the current
  `orc_attack.png` (2026-08-14 19:05 regen) is clean; the ghost chunk under the
  feet + 30 px lift the owner described are the pre-08-14 strip (frame 1 had a
  detached band at rows 158-188 and frames 2-4 sat 30 px higher than frame 1).
- **Frost-Bound Soldier (`skeleton_warrior`) attack** — new 2x2 master: ready →
  wind-up (blade high behind the helm) → forward diagonal slash toward the
  facing with a frost arc → low follow-through. The old strip (kept as
  `skeleton_warrior_attack_master_rejected_2026-08-09.png`) was a horizontal
  poke whose shaft stuck out BEHIND the soldier. Same `install_robe_attack` path.
- **Bog Lurker attack** — new 2x2 master: coil → rear (front legs raised, fangs
  spread) → strike (low lunge left, fangs to the ground, venom flecks) → recoil.
  Old master kept as `bog_lurker_attack_master_rejected_2026-08-13.png`. The
  strike runs a few px past the nominal quadrant edge, so the builder cuts at
  the REAL per-row gutters (`four_grid_subjects_gutters`), and because a spider
  that coils/rears/lunges has no stable bbox height it is normalized by its
  body core (`normalize_core_anchored`: one clip scale from the median eroded-
  body area, abdomen-rear x anchor, hem on the idle ground line; cell 386→546,
  rendered by enemy.gd at the idle body scale). `verify_art` reports a
  CLIPSCALE 0.74 WARN on it — three of the four poses are legitimately low.
- **Edge despill** added to `remove_green` (2 px rim only): every ImageGen-keyed
  strip carried a dark-green antialias rim (~1-3k px per strip; the PixelLab-
  era idles ~200). Only the four strips above were rebuilt with it; other
  installed strips keep their bytes until they are next rebuilt.

`qa_mobqa_<sprite>_2026-08-15.png` are in-engine filmstrips from the new
`game/shot_mobqa.gd` rig (idle / walk / attack, 4 frames each, real
`_apply_strip` path): the feet line is identical across the three states for
all four mobs and every frame is visible.

The 2026-08-10 follow-up adds strict padded 2x2 complete-pose attack masters
for Waking Wolf, Wildkin Ranger, Dune Prowler, Null Acolyte, Barrow Wight,
Slagbound Brute, Storm Harrier, and Plague Chanter. The prompts explicitly
require full face/muzzle/tail/robe/equipment containment, a locked planted
ground point and torso position, and the established native screen-left facing
for Wildkin and Barrow. Plague Chanter keeps exactly one staff continuously
gripped by the same hand while the free hand casts. Slagbound preserves its
accepted old idle strip whole: frame zero is now its one-frame idle and all
four former idle frames are now its walk loop. No pose was mirrored or
assembled from body pieces. Waking Wolf's accepted walk master uses opposing
foreleg contact poses; two earlier generations without a decisive contact
reversal (one also containing divider bars) were rejected and never installed.
The 2x2 extractor requires a fully transparent perimeter around each complete
pose before assembling the runtime strip.
