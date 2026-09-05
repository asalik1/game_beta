# Visual overhaul — 2026-09-03/04 (branch `claude/visual-overhaul-2026-09-03`)

Owner brief: "walks of mobs/bosses/classes are robotic, visuals aren't up to par
in fluidity/motion, the capital is pending a visual update; ultimate freedom;
I will review all work at the end." This is the review board: what changed,
where to look, and what is still open. Every item below is on the branch and
gated (compile + test_quick per commit; the full suite and the mobile re-sync
are the merge gates and are recorded at the bottom).

## How to review

- **Before/after GIFs** of every changed sprite: `~/Downloads/ba_gifs_visual_overhaul/`
  (417, built by `tools/art/ba_gifs.py --base 7fd27a4`). Palette-quantized and
  above game scale — for CHANGE review, not colour judgement.
- **Travel GIFs** (old vs new walk over scrolling ground at the mob's real
  speed): `~/Downloads/travel_gifs_visual_overhaul/` (zombie, royal_knight,
  wolf, cultist, stone_broken, plus mage_walk_e and warlock_walk_e old vs new).
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

## 6. Final QA round (2026-09-05) — 9 read-only audits, every finding re-checked by hand before acting

Fixed on the branch:
- mage cast E/W: frames 0/1/6 were drawn ~15% small (the hero renderer locks a clip to
  frame 0, so the whole cast ballooned); row normalised to frame 2's body, re-installed
  into a 320px cell (`install_gait_row --cell`) so the raised crystal is no longer cut.
- mage anim E/W: hip pouch pasted from walk_e (every other E clip + the S idle carry it —
  it blinked off whenever she stopped). mage attack E/W: v2 re-roll (staff stayed in the far
  hand and the last three frames were 13% compressed). mage attack_walk_s: aligned to
  walk_s (12px sideways hop when firing on the move); sleeve fleck dropped.
- warlock walk E/W: the floating skull existed in only 2 of 6 frames — composited from f0.
  warlock attack_walk_n: a second skull at the elbow in f2/f3 — regen queued.
- serane S: frame 2 was a redrawn, 10% larger figure (dropped → 5-frame glide); the
  idle's two floating shoulder shards were absent (composited); slivers dropped.
- nullwarden: the IDLE sat 51px off-centre (a sideways jump on every idle↔walk
  transition) — recentred; the N walk lifted the right boot in 4 of 6 frames — rebuilt as
  a mirrored-half cycle (R R R / L L L; the back view is symmetric).
- korrag: E family, N and S walks tone-matched to the idle (13-26% darker before; the boss
  dimmed on every step). stormmouth N v3: a real stride + the family's blue-steel plate.

Verified but NOT fixed (owner's eye / cheap later):
- stormmouth N reads ~15% slimmer across the pauldrons than S and the idle (three rolls,
  the generator will not give back-view pauldron mass; the crest on the E helm is absent
  from behind). paladin walk_n: the regen's f6 ≈ f2 and a slightly right-dominant leg
  cycle (owner call already flagged above; the re-sliced old cycle is the swap).
- warlock attack_walk_e trim reads ~5° yellower than walk_e; echo N carries a teal cast on
  the wings; serane N is ~12% brighter than the idle (pre-existing); cinderhide attack f3
  keeps ~100px of sub-alpha residue from the claw erase (sub-pixel in play).

### 6b. Second pass on the wave-1 mob/boss walks (two auditors, findings hand-checked)
- Fixed: ashpriest S carried an opaque green keying patch inside the flail gap (keyed out);
  vent_skitter and deep_stalker frames 3/7 were botched renders (lava tips / crystal plating
  gone) — dropped to 6-frame cycles; auroch_minotaur S/N were an ice-blue palette —
  graded toward the idle; fungus_long S/E and stone_base N/S rendered 12-22% larger than
  their siblings — reseated; vow_sentinel's warhammer vanished in 2 of 6 frames — filled
  from the neighbour frames; bandit_scout walk 30% brighter than its idle — tone-matched;
  casket_creeper fragment, royal_knight ice motes dropped.
- Re-rolls queued (wave 4/5, crossing-hardened briefs): blightwolf (teal palette, lost its
  lime shoulder vein), choirmother N (invented glowing hands), hrolgar N (missing skull
  pauldron), and the seven bipeds whose new walks still scissor without a passing frame
  (elf_ranger, royal_knight, skeleton, zombie, elf_druid, skeleton_rogue, bandit_scout).
- Left as-is (P3): wolf/rotmaw/veyx/duneprowler/casket hue nits, cultist boot swap,
  fungus_heavy N 8% small, stone_base pebble blink, korrag spiked-ball reinterpretation.

## 7. Wave 3 (2026-09-05): the rest of the placed 4-frame walks + fire-on-move alternates

- **Fire-on-move `attack_walk_b`** for the base mage, warlock and assassin (S/E/N, copies +
  mirrors, flat = S): the alternate the owner asked for on 08-23 and the base classes never
  had — mage rising flick, warlock two-hand shove, assassin sidearm flick. Mage + assassin
  installed; the warlock's first rolls dropped his grimoire during the shove and are
  re-rolled with the book pushed between both hands — v2 installed for S/E/N.
- **Warrior walk E/W**: the flaming greatsword had dimmed to a plain thin blade that changed
  size frame to frame; edit-in-place roll (`tools/art/edit_in_place_brief.py`: reproduce the
  row, change only the sword) — the gait the owner approved is untouched.
- **Wave-3 gait regens (17 rows)**: mummy S/E/N, mummy_mage S/E/N, skeleton_warrior E/N
  (S from the re-run fix-up job), rat_mage, flux_hound, rime_wolf, slag_hound,
  void_hound, fangmaw, root_spiderling, bog_lurker, plus cinderhide (the three-headed lava
  hound boss) — 4-frame pose-steps → 6/8-frame strides/trots. fangmaw, bog_lurker and
  cinderhide were rolled as two-row grids (`gridify_brief.py` + `grid_to_row.py`) so their
  560-627px cells install without an upscale.
- Remaining 4-frame placed walks are gliders/floaters by design (banshee, word_wisp,
  waking_shard, verdict_drone, pollen_drifter, riftling, elara_vessel, static_caller, vess,
  null_acolyte, skeleton_mage, forgemistress, sexton, morwen) — a drift loop is correct there.

## 8. Waves 4-5 (2026-09-05): re-rolls of the audited drift/scissor walks

- Wave 4: blightwolf back in the idle's near-black olive with its lime shoulder vein;
  choirmother N with plain hands and a navy gown; hrolgar N with the skull pauldron.
- Wave 5 (crossing-hardened briefs): elf_ranger, royal_knight, skeleton, zombie, elf_druid,
  skeleton_rogue, bandit_scout — each now lifts alternate boots with bent knees where the
  wave-1 rows slid (per-frame lifted-side metric in `tools/art/gait_metrics.py`; the old
  rows are in `art_src/mob_gait_wave5_2026-09-05/old_backup/`).

## 9. Corpus seam sweep (2026-09-05): off-grid idles and walks

A scan of every enemy's idle-vs-walk seam (centre, feet, luminance, body size, per-frame
jitter) found a whole class the earlier audits only met once (nullwarden): **older 4-frame
idles and walks sliced off the frame grid**, so the figure slides 15-30% of the cell across
the loop (storm_adept, bannerman, drowned_warden, archon_vassik, the choir_* set, ~70
idles and ~100 legacy walks — mostly Act-2/capital reserve bodies). Fixed with
`tools/art/recenter_strip.py --apply` on 68 idles + 97 legacy walks (feet-band anchor;
backups in `art_src/_backups/recenter/`). Walks produced by the gait-transfer lane were
left torso-anchored (the feet-band anchor would add torso wobble to a real stride).
Two idles still report a 4-6px residual (grove_horror, nullwarden) and bannerman's 4th
idle frame was already clipped in the source (a regen would be needed to recover it).
- Seam fixes from the same scan: 14 walks tone-matched to their idles (cold_pilgrim,
  elf_ranger, fungus_immature, skeleton, royal_knight, orc_rogue, heart_of_the_root,
  static_caller, skeleton_mage, bog_lurker, fangmaw, skeleton_warrior S/E/N); the four
  hounds (flux/rime/slag/void) reseated to their idle's body size (they shrank ~25% on the
  first step); seven walks centred on their idle (rat_mage was 19% of the cell off).

## 10. Death clips (2026-09-05): 21 placed mobs that only collapsed procedurally

`tools/art/death_briefs.py` + `install_death_row.py` (see tools/INDEX.md): a 6-frame
hit → stagger → buckle → fall → ground → still row per mob, identity from its idle, installed
at the idle's scale with each frame's own extent (the last frame lies flat and is held, then
fades — the engine path shipped on 09-03). wolf, winterfang, blightwolf, duneprowler,
deep_stalker, casket_creeper, vent_skitter, bog_lurker, cultist, mummy_rogue, mummy_warrior,
rat_rogue, rat_warrior, zombie_overweight, greyrun_lurker, grove_horror, fungus_immature,
spider, cold_pilgrim, stormcult, flame_pilgrim; then blooming_convert, choir_pilgrim,
elf_wild, ragged_soldier, ridge_deserter, vale_mourner (27 in all). Every row was eye-checked
on a sheet beside its idle before install. Bosses keep their own death sequences (untouched);
the tiny legacy placeholders (beastkin, sentry, verdant_*) and the tick critters were skipped.

## 11. Boss windup postures + boss death clips (2026-09-05)

- **Tell WINDUP posture** (`Balance.BOSS_TELL` "windup", knobs `BOSS_WINDUP_K` /
  `BOSS_WINDUP_LEAN`): through a tell's fuse each boss now holds a per-kind posture and
  snaps on release — brutes crouch and widen (vargoth, nullwarden, stormmouth, auroch,
  fangmaw, cinderhide, saint_varo, whitepelt, icebound, first_howl), casters and floaters
  draw up (morwen, choirmother, vess, forgemistress, ashpriest, sleepkeeper, gardener,
  unnamed_echo), skirmishers lean into the aim (stormwarden, sexton), serpents coil
  (curetwisted, stormdrake_veyx). Hue and shape said WHAT was coming; this says WHO. Rides a
  held pose channel in the render tail; visual only (no timing/radius/damage change);
  guarded by autotest (a real boss in the tree must carry the crouch to its sprite).
  Review: `shot.bat tells --bosses --phase=0.85` vs `--phase=0.02`.
- **Boss death clips** for the 20 bosses that still collapsed procedurally (ashpriest,
  auroch_minotaur, hrolgar, kaethra, korrag, rotmaw, serane, veyx, choirmother, echo,
  forgemistress, halla, morwen, nullwarden, saint_varo_standing, sexton, stormmouth,
  vargoth, vess, first_howl): two-row grid rows at their cells, each eye-checked before
  install. The 32px placeholders (whitepelt, icebound, stormwarden) were skipped.

## Open / not done

- **Mage E column DONE**: anim/walk/attack/cast E regenerated as a true right
  profile (`tools/art/profile_clip_briefs.py`; identity = her front idle, view
  ref = blighted_healer's profile idle, action = the old clip frame by frame),
  W = per-cell mirror. Her walk_e reads at stride 0.14 bodies/cycle — the same
  marching-in-place family as every hero walk (assassin 0.22, archer 0.22),
  which the owner ruled to keep at 14 fps; travel GIF old-vs-new in
  `~/Downloads/travel_gifs_visual_overhaul/mage_walk_e_old_vs_new_travel.gif`.
  Her `attack_walk_e` family (built from the OLD front-facing walk) was
  regenerated from the new profile walk and installed (E/SE/NE + W mirrors).
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
- Base warrior walk E/W flaming blade — DONE (§7 edit-in-place roll).
- **Base warlock walk E/W DONE**: was a 3/4 front view against his full-profile
  side idle (hood snapped to camera on the first step); regenerated as a true
  profile with the same lane as the mage (stride 0.50 → 0.61). His
  `attack_walk_e` (built on the old walk) regen queued (`art_src/warlock_aw_2026-09-04`).
- attack_walk_b variants — DONE (§7).
- Boss facings round 3: **serane S** installed (was a byte copy of the idle;
  now a 4-frame glide with hem flutter — the row's first cell crammed two
  undersized figures, dropped; a clean re-roll is queued and replaces it if
  it lands). **stormmouth N** (byte copy of E) and **nullwarden N** (front helm
  on a back view) first rolls REJECTED on identity — stormmouth grew a glowing
  orb on its back and lost its pauldrons, nullwarden gained a slung greatsword
  its idle/E walk never carry (my briefs described both from memory, not the
  idle — the CLAUDE.md rule, re-learned). Re-rolls with the front-only parts
  named landed clean; then, because a 6-figure row comes back ~2100px wide
  (≈400px figures against their 920/1084px cells), both were re-requested as a
  TWO-ROW grid (3+3, `grid_to_row.py` flattens it) — ~870px figures, installed
  at 0.65×/1.07×, no upscale. **Both INSTALLED from the hi-res grids**
  (stormmouth: gunmetal plate, plain back, wide pauldrons; nullwarden: empty
  fists, no sword). Stormmouth's back view still reads a little slimmer than
  his E strip's massive pauldrons; owner's eye on the turn. Lane rule learned:
  for cells ≥ 900px request the grid, not the row.
- Not addressed from the audits: assassin walk_e cloak balloon + walk_s
  bootless frames, archer walk_n cape green-on-content, saint_varo_blade
  fidelity (192px cell beside 627px siblings), greyrun_lurker attack 0.86x.
- Done since first draft: warlock_ledgerbound duplicated frames (trimmed),
  elf_ranger_attack f2's baked in-flight arrow (erased; the game spawns it).
- Mobile re-sync: see Gates.

## Gates

- Every commit: compile gate + `test_quick` green.
- Full suite: **AUTOTEST PASS, 172 sections** three times — 2026-09-04 at 252547e, 2026-09-05 12:38 (db80ef6) after waves 3-6 and the seam sweep, and **2026-09-05 18:18 (29bd760) with the boss windup code and all 47 death clips**.
- Final desktop pass (2026-09-05 12:00, after wave 3-6 + the seam sweep): `--import` (the long one segfaulted at its shutdown tail — the known box crash — and a confirming re-import exited 0), **AUTOTEST QUICK PASS**, **PREFLIGHT OK** (IMPORT MODULES BALANCE PHYSICS RIGS ARTQA).
- Mobile: `sync_mobile.py --apply --gate` → **GATE OK** six times (2026-09-05 05:17: 341 files; 12:24: 287; 13:17: 29; 15:19: 21; 16:30: 42; **18:36 after the windup + boss deaths: 47 files**; mobile compile 121 scripts + quick suite passed each time). Final desktop pass (18:40): confirming `--import` exit 0, PREFLIGHT OK, AUTOTEST QUICK PASS. Note for the next sync after a big PNG batch: the gate's first `--import` can exceed its 600s watchdog; run the mobile import by hand once, then re-run the gate.
