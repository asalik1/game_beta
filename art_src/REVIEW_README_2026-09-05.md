# Crownless visual overhaul, 2026-09-03 to 09-05: review guide

Branch `claude/visual-overhaul-2026-09-03`, worktree `.claude/worktrees/epic-panini-3fd8fd`,
78 commits on top of main 7fd27a4, 0 behind main. NOT merged; that is your call after this
review (`git merge --ff-only claude/visual-overhaul-2026-09-03` from the main checkout).
The full record is `VISUAL_OVERHAUL_2026-09-03.md` at the branch root. This guide is
organised the way the GIF folders are, one entry per subject, each with: what changed, the
defect that drove it and how it was found, the lane or tool used, and what to look for.

## How to read a GIF

OLD (branch base) plays on the left, NEW (branch head) on the right, feet aligned, above
game scale, palette-quantized. A GIF with only a NEW side is a strip that did not exist
before (every death clip, the base classes' fire-on-move clips, kaethra's north walk). Judge
motion, identity and frame-to-frame consistency here; judge colour and softness in-game
(the Forward+ tonemap darkens PNGs, and GIF palettes lie).

Two facts about how strips render, so a GIF reads correctly:
- Enemies play a strip at MEDIAN BODY HEIGHT over CELL (the "CLIPSCALE" model): what
  matters between an idle and a walk is the body/cell RATIO, not the raw pixel height.
- Heroes lock a clip's on-screen scale to FRAME 0's content box and play the whole clip at
  it ("HEROBODY"): a clip whose first frame is drawn small balloons for its whole length.
Walks march in place by your 08-28 ruling (the treadmill regen was rejected); a
"marching" read is by design, the stride shape is what changed.

Every generated row in this set was reviewed on a contact sheet beside its idle (and a
legs crop for bipeds) before install; every audit finding below was re-checked by hand
before anything was changed. Numbers quoted are the measurements that were taken, not
estimates.

---

## classes/

The 18 real hero skins were not touched (your 08-22 ruling). Only the six base classes
and, where a lane needed a reference, the five enhanced-base skins.

### classes/mage (16 GIFs)

**anim_e / anim_w, walk_e / walk_w, attack_e / attack_w, cast_e / cast_w**
- Defect: the whole E column was FRONT art wearing the E name (she stood square to the
  camera in all four clips), and W was a mirror of E, so the mage had no side view at all.
  Found by the 2026-09-03 drift audit (classwalk P1) and confirmed on a sheet: E frame 0
  was identical in silhouette to S frame 0.
- Fix: `tools/art/profile_clip_briefs.py`, a new lane. Per clip three references: her front
  idle (identity), the blighted_healer skin's true-profile idle (what "side view" means),
  and the outgoing clip laid out as a labelled row (the per-frame ACTION, kept frame for
  frame). Installed at the old geometry with `install_gait_row.py`; W = per-cell mirror.
- QA round on the result (2026-09-05, 9 audits + hand verification), all fixed:
  - cast_e frames 0, 1 and 6 were drawn 14 to 17 percent small while standing (head-top 48
    and 32 px vs 21 for the idle at feet 220). Because the hero renderer locks to frame 0,
    the whole cast played 16 percent enlarged and she visibly grew mid-cast facing E/W.
    Fixed by normalising those figures to frame 2's body in the row (a scratch tool,
    `scale_row_figures.py`) and re-installing.
  - cast_e frames 4 and 5 lost the staff crystal at the top cell edge (alpha touched row
    0). Fixed by installing the cast into a 320 px cell instead of 228 (`install_gait_row
    --cell`); the hero renderer measures per clip, so a taller cell costs nothing.
  - anim_e had no hip pouch while walk_e, attack_e, cast_e and the S idle all carry one,
    so the pouch blinked off every time she stopped. The pouch was pasted from walk_e
    frame 0 (a 143 px component at x 80 to 100, y 90 to 116) onto all five idle frames and
    cast frame 0, torso-anchored.
  - attack_e held the staff in the FAR hand behind her for the whole clip (the idle, walk
    and cast hold it in the near hand, matching the S canon), and its last three frames
    were compressed 13 percent. Re-rolled (v2) with both named as hard requirements; the
    installed clip's head-top is 23 px in all seven frames.
  - anim_e reads 5 percent dimmer than the S idle by body-mean luminance (115 vs 122) and 4
    percent brighter than its own walk; inside the 8 percent bar, left alone.
- Look for: a genuine profile in every frame (one eye, near arm in front), the staff in the
  near hand in all four clips, the pouch on the hip in all four, no size change on the
  S-to-E turn (feet at 220, head at 19 to 23 in every E clip).

**attack_walk, attack_walk_e/n/nw (+ se, ne, w, sw not shown), attack_walk_b family**
- Defect: fire-on-move (the walk-while-firing clip `player.gd` plays when a ranged basic
  is spammed while moving) existed only for the elite skins; every default character had
  the feature dark and slid the standing pose over the floor.
- Fix: `tools/art/attack_walk_briefs.py`, the documented technique (give the character's
  own walk strip as the image reference and change ONLY the free hand). S/E/N authored,
  SE/NE copies of E, W-family mirrors of E, flat = S. After the E column became a profile,
  attack_walk_e was rebuilt from the NEW walk (the first one was built on the old front
  walk and would have snapped to a different view mid-stride).
- attack_walk_s sat 12 px to the right of walk_s (bbox centre +6 percent vs 0), a sideways
  hop when firing south; aligned by a constant shift. A 53 px detached sleeve stroke on
  frame 6 dropped.
- attack_walk_b (S, E family, N): the alternate you asked for on 08-23, a rising flick of
  the free hand instead of the level thrust, so spamming while moving alternates two clips.
  The N row lost the staff in frame 3; filled from frame 2 into the transparent pixels only.
- Look for: legs identical to walk_e frame for frame, the arm moving through one thrust
  (or one flick) and returning, no baked bolt (a small hand glow was accepted; the game
  spawns the projectile).

### classes/warlock (28 GIFs)

**walk_e / walk_w**
- Defect: walk_e was a three-quarter FRONT view (face and hood turned to camera, body
  angled) against a full-profile side idle, so the hood snapped toward the camera on the
  first step and back on the last. Found on a walk-vs-idle sheet after the mage case.
- Fix: the same profile lane, with his OWN profile idle as the view reference and a `--keep`
  clause so the floating skull and the open grimoire (his signature props, the STRAY-benign
  class in CLAUDE.md) survive. Stride rose from 0.50 to 0.61 bodies per cycle.
- QA round: the floating skull existed in only 2 of the 6 new frames (purple flame pixels
  779 and 805 on frames 0 and 3, 235 to 280 on the rest). Composited from frame 0 onto the
  other four at the same position (a 1251 px component at x 79 to 114, y 52 to 111).
- Look for: hood in profile every frame, the skull floating behind the head in all six, the
  grimoire in the near hand, boots alternating below the hem.

**attack, attack2 and their eight facings (19 GIFs)**
- Defect: every one of the 19 warlock basic and attack2 strips carried a #00FF00 keying
  ring on the silhouette (a design with no green in it at all), invisible on a dark contact
  sheet, a halo over grass. Found by the corpus scan `despill_rim.py --scan` (rim-band
  green with an empty interior), which also corrected the 08-23 triage that had scoped the
  "no rim on base heroes" finding to cast/ult.
- Fix: rim-band despill only (it cannot dull green garments); the scan returns 0 now.
- Look for: no green edge on the sleeves or skull over the grass-coloured GIF background.

**attack_walk family (8 GIFs) and attack_walk_b family**
- Built as for the mage. attack_walk_e was rebuilt after walk_e became a profile; the job
  then iterated the baked hand-flame out of the thrust frames on its own (the final row was
  installed). attack_walk_n from the earlier install carried a SECOND floating skull at the
  elbow of the extended arm in frames 2 and 3 (audit finding, confirmed on a 2x crop);
  regenerated from walk_n.
- attack_walk_b: the first S/E/N rolls dropped the grimoire entirely for a two-hand shove
  (both hands empty), and S held the shove in every frame instead of once. Re-rolled with
  the book pushed between both hands and the shove peaking mid-cycle; those v2 rows are
  installed.
- The E family's gold trim reads about 5 degrees yellower than walk_e (hue 44 vs 39);
  left alone, noted for you.

### classes/assassin (8 GIFs)
- attack_walk family: new (fire-on-move for Fan of Knives).
- attack_walk_b family: the sidearm flick alternate; distinct from the primary's overhand
  throw; daggers kept in both hands. Look for the legs matching walk frame for frame.

### classes/archer (4 GIFs)
- attack_walk family: new (fire-on-move for Quick Shot). No `_b` by your 08-23 ruling (a
  bow draw has one proper form). Its STRIDE warning (29 percent contact sweep) is the same
  marching-in-place family as every hero walk; parity, not a defect.

### classes/warrior (2 GIFs)
- walk_e (and its mirror family): the flaming greatsword had dimmed to a thin plain blade
  that changed size frame to frame (the classwalk audit's P1; visible in the OLD half of
  the GIF as a white sliver). Because you ruled the warrior keeps the new gait-transfer
  walk, the fix is an EDIT-IN-PLACE roll (`tools/art/edit_in_place_brief.py`: reproduce
  this row exactly, change only the sword to the idle's flaming blade). Legs and poses are
  frame-for-frame the approved ones; only the blade changed.

### classes/paladin (1 GIF, walk_b_n; walk_n is a byte copy)
- Defect: on main, walk_n was an 8-figure row saved 6 cells wide, so every cell showed one
  and a third paladins (the north walk was unplayable, not just stiff). Confirmed from the
  base commit's file: 6 cells of 277 px, 8 content runs of ~135 px.
- Two candidates were built. (a) main's own row re-sliced at its real gutters into 8 cells
  (`art_src/paladin_n_2026-09-03/old_cycle_resliced/`), faithful to your "paladin = old
  cycle" ruling, but two of its frames swing the shield 40 px off the body (the placement
  jump you flagged in the E/W rounds). (b) a gait-transfer back-view regen: shield on the
  arm every frame, silver face and gold cross visible from behind as in the idle.
  (b) is installed; swapping to (a) is one copy. The audit's note on (b): frame 6 is close
  to frame 2 and the right boot leads slightly more often. YOUR CALL.

---

## bosses/

Layout rule used for every boss regen: author S, E and N; SE/NE are byte copies of E,
W/NW/SW per-cell mirrors of E (your 08-28 ruling). Cells of 900 px and more were requested
as two-row grids (`gridify_brief.py`, flattened by `grid_to_row.py`) after the first
stormmouth and nullwarden rows came back at ~400 px figures and upscaled 1.4 to 2.2x at
install; the grids landed at ~870 px and installed at 0.65 to 1.07x.

Boss tells and the windup posture are code, not strips; see "In-game" below.

### bosses/ashpriest (walk S, walk N, death)
- walk_codex_s / walk_codex_n: the S and N facings were missing or byte copies; regenerated
  as a glide (robed floater: hem sway and censer drift). The identity description was
  written from the idle sheet (bronze mask under the hood, the burning censer on its chain,
  the hand flame).
- Audit B finding on S: an opaque bright-green keying patch sat INSIDE the silhouette
  between the flail chain and the robe in frames 0 to 4 (95 to 351 px per frame), which the
  rim gates cannot see. Keyed out with a strict mask everywhere plus a loose mask and a
  green-cast neutraliser confined to that gap (the loose mask alone would have eaten 1336
  legitimate olive pixels, measured on the idle).
- death: new. Six frames, hit to still, hand flame kept (it is part of his design).

### bosses/auroch_minotaur (walk S, N, E family, death)
- walk S and N regenerated (he walked toward and away from the viewer with the E art).
- Audit B: the S walk came back in an ICE-BLUE palette (body hue 218 degrees at saturation
  0.46 and luminance 84, vs the idle's hue 20, 0.29, 57: 45 percent brighter) and N in a
  milder blue. Both graded toward the idle with `palette_grade.py --toward` (S: sat x0.62,
  val x0.63); after grading S/N/E all sit within 2 luminance points of the idle.
- The E family's frames were among the 97 legacy walks recentred in the seam sweep (feet
  anchor drift 54 px).
- death: new (the axe stays in hand to the ground).

### bosses/choirmother (walk S, walk N, death)
- walk N regenerated (the matriarch had no back view). The first roll gave every one of
  her six hands a cyan glow and a lighter royal-blue gown (audit B); re-rolled with plain
  silver-grey hands and a navy gown named as hard requirements (v2 installed).
- walk S: centred on the idle in the seam pass (it sat 6 percent of the cell to the right).
- death: new (six hands, sinks into a heap).

### bosses/cinderhide (attack, walk)
- walk: the three-headed lava hound had 4 stiff poses; now a 6-frame trot from a two-row
  grid (627 px cell, installed at 0.69x, no upscale). Described from the idle sheet
  (three snarling heads, horns on the central one, lava veins).
- attack frame 3: a detached claw sliver from the neighbouring cell at the left edge
  (1317 px) erased; verified by diffing against the backup that nothing on the body moved.

### bosses/echo (walk E, walk N + NW mirror, death)
- walk N regenerated; the first roll came back as a plain hooded shroud because I had
  described him from memory. Rule learned and written into CLAUDE.md: describe FROM the
  idle sheet. The installed N is the winged flame-skull from behind, dagger in hand every
  frame. Audit B notes a teal cast on the wings vs the idle's violet-grey (P3, left).
- death: new (wings fold and drag as he goes down).

### bosses/fangmaw (anim, walk)
- walk: 4 stiff poses to a 6-frame trot. The first roll was a plain row and upscaled 1.5x
  at install; re-requested as a grid and re-installed at 0.7x. My first identity text for
  him was wrong (I had swapped him with halla on the sheet); the grid brief was corrected
  from the idle (emaciated black hound, exposed ribs, chains, red eyes) before it ran.
- Seam pass: the walk sat 9 percent of the cell off the idle's centre and 12 percent darker;
  centred and tone-matched.
- anim: recentred in the corpus sweep.

### bosses/first_howl (death)
- death: new, a dire wolf lying down in six frames (quadruped storyboard).

### bosses/forgemistress (walk N, death)
- walk N: among the 97 legacy walks recentred (a 4-frame glide loop is correct for her).
- death: new (fire queen sinks, hand flames kept).

### bosses/glacius, smelter_lord_thrain, thornfather_grael (anim, walk)
- Act-2 content bosses whose 4-frame idles and walks were sliced off the frame grid (the
  figure slid sideways across the loop); recentred in the corpus sweep. No regen.

### bosses/halla (anim, death)
- anim: recentred. death: new (the moth wings droop and fold over the candle).

### bosses/hrolgar (walk E, walk N + NW mirror, death)
- walk E and N regenerated (the frost jarl had no north). Audit B: the first N had no skull
  pauldron on his right upper arm (present in the idle and every E frame); re-rolled with
  it mandated on the correct side (v2 installed).
- death: new.

### bosses/kaethra (walk E, walk N + NW mirror, death)
- She had NO north walk at all: she walked away showing her face. E and N regenerated
  (bone mask, knives, bindings, from the idle). death: new.

### bosses/korrag (walk E family, walk N, walk S, death)
- walk E regenerated; the first roll lost his lightning arcs (described from memory);
  re-rolled from the idle with the arcs mandated.
- Seam pass: E, N and S walks were 13 to 26 percent darker than the idle he co-displays
  with (he dimmed on every step); all tone-matched to the idle, E family copies/mirrors
  rebuilt. N still reads slightly dark (P3, noted).
- death: new.

### bosses/morwen (walk, death)
- walk: re-seated (7 percent small vs her idle) in the geometry pass. death: new.

### bosses/nullwarden (anim, walk S, walk E family, walk N, death)
- Geometry pass: his walks played at ~60 percent size and 0.2 of the cell off centre
  (`reseat_strip.py`, no regen).
- walk N: was FRONT art wearing the N name. Roll 1 invented a slung greatsword his idle and
  E walk never carry (my description again); roll 2 from the idle (empty fists, no sword)
  landed at ~400 px figures and was upscaled 2.2x; the two-row grid re-request installed
  near-native (1.07x). The audit then measured the right boot lifted in 4 of 6 frames; the
  back view is symmetric, so the cycle was rebuilt as frames 0 to 2 plus their mirrors
  (R R R / L L L, a proper 3+3).
- anim_codex: sat 51 px (8 percent of the cell) off centre, a sideways jump on every
  idle-to-walk transition; centred. The later corpus recentre then EMPTIED its last frame
  (1 px of alpha; caught by `verify_art` BODYSCALE) and it was restored to the centred
  version. Look at anim_codex for four whole frames.
- walk N frames 0 and 3 carried a 31 px fleck of the tabard hem between the legs (the
  audit's last open item on him); dropped while this guide was written, the final edit on
  the branch.
- death: new.

### bosses/rotmaw (walk E family, walk S, death)
- walk E regenerated: the first row came back as a slender stranger; re-rolled with the
  hulk's bulk named. death: new (the mushroom caps stay on the shoulders).

### bosses/saint_varo (standing walk E + NW mirror, standing death)
- walk E/W: the standing form's E and W were on the wrong cell (geometry pass, no regen).
- standing death: new (the throne form keeps its own sequence).

### bosses/serane (walk E + NW mirror, walk S, death)
- walk S was a byte copy of the idle. The first row crammed two undersized figures into one
  cell (the known row defect; `normalize_row.py` was written for it but touching figures
  cannot be split, so a 4-frame salvage went in), then a clean 6-figure re-roll replaced it.
- QA round: frame 2 of the re-roll was a redrawn, 10 percent larger figure (a scale pop
  once per 0.43 s), and the idle's two floating shoulder shards were absent from every
  frame (they popped out when she started gliding). Frame 2 dropped (5-frame glide), the
  shards composited from the idle at their positions, two sliver orphans dropped.
- walk E/W re-centred in the geometry pass. death: new.

### bosses/sexton (walk E family, walk N, death)
- walk N centred in the geometry pass; E family recentred in the sweep. death: new.

### bosses/stormmouth (walk E family, walk S, walk N, death)
- walk N was a byte copy of E. Three rolls: v1 invented a glowing orb on the BACK and
  shrank the pauldrons (my brief called the chest maw a "core"); v2 named the maw as
  front-only and was clean but ~400 px figures; the grid re-request landed at 890 px and
  installed at 0.65x. The audit then measured the boots side by side in every frame (sole
  flips, no stride) and the plate charcoal; v3 with the stride storyboard hardened has a
  real stride (rear boot lifts 25 to 70 px vs plus or minus 4 before) and the family's
  blue-steel plate.
- Still open: the back view reads about 15 percent narrower across the pauldrons than the
  S walk and idle (three rolls; the generator will not give back-view pauldron mass), and
  the E helm's rear crest is absent from behind. YOUR CALL on the turn.
- death: new.

### bosses/vargoth (anim, walk E family, walk N, death)
- walk N: tone-matched to the idle in the geometry pass (it had been re-authored on main
  the day before this branch). anim and the walks were recentred in the sweep. death: new.

### bosses/vess (walk E, walk N, walk W, death)
- Walks recentred in the sweep; N tone-matched in the geometry pass. death: new (banshee
  crumples).

### bosses/veyx (walk E family, walk S, death)
- walk E regenerated; the first roll lost his bulk, re-rolled with it named. Audit B: hue
  225 to 232 vs the idle's 206 to 214 (a steel-blue cast), inside the idle's own lightning
  flicker range; left. death: new.


---

## mobs/  (103 subjects, 214 GIFs)

### The diagnosis behind every walk regen

Of 140 mob and boss walk families, 110 were 4-frame strips, and the day-1 audit measured most
of them as TWO poses ping-ponging: the leg-band XOR between frame 0 and frame 2 sits at 0.13
to 0.19 where a real cycle reads 0.41 to 0.52. In plain terms the same leg led every step,
there was no passing frame, and the knees never bent. That is the "robotic" read. Every walk
below was regenerated through the gait-transfer lane (`tools/art/gait_briefs.py` writes a
brief with the identity taken FROM the idle sheet, a per-frame gait storyboard and the old
strip as a layout reference; a Codex image job returns one row of same-size figures;
`gait_row_sheet.py` puts old and new side by side, full body and a legs crop;
`install_gait_row.py` keys, despills, scales to the idle's body, anchors the torso or the
centroid, pins the feet and tone-matches). Every row was looked at on that sheet before
install, and every install was measured afterwards by `verify_art`.

Frame counts: bipeds 6 (8 where the old strip was 8), quadrupeds 6, arachnids 8. Walks
march in place (your 08-28 ruling), so judge the stride, not the travel.

### Regenerated walks, by subject

**Wave 1 (2026-09-03), seven creatures**
- elf_druid (walk): the old strip did not just pose-step, it SWAPPED ANATOMY mid-cycle:
  frame 0 stood on root-claw feet under the root skirt, frames 1 to 3 on smooth bare legs
  with human toes and no skirt, and the leg colour drifted from dark bark to yellow-olive
  across the four frames. 4 to 6 frames, the skirt and root feet held in every frame at the
  idle's body mass. Re-rolled again in wave 5 (below) because the first regen still slid.
- elf_ranger (walk): frame 2 was frame 0 translated 8 px with an identical leg
  configuration; frame 0 alone carried a bright yellow nocked arrow (a 1-in-4 blink). 4 to 6
  frames; re-rolled in wave 5. Its attack strip (attack GIF) lost the baked in-flight arrow
  in frame 2, which doubled the arrow the game spawns.
- royal_knight (walk): same leg leading in both halves, legs straight columns, both boots
  flat in every frame. 4 to 6 frames; re-rolled in wave 5. Its ice motes (loose specks
  around the armour) were dropped in the audit-A fix.
- blightwolf (walk): 4 to 6 frame diagonal trot. The first regen came back teal and
  steel-blue with thin yellow veins everywhere and lost the single lime shoulder vein the
  idle has; the wave-4 re-roll named the near-black olive coat and the one vein as hard
  requirements, heights were normalised and the row graded toward the idle.
- duneprowler (walk): the old "walk" was a bound, three poses in which the far foreleg and
  both hinds never led. 4 to 6 frames. Installed with centroid anchoring: torso anchoring
  flat-cut the tail at the cell edge (141 edge px), centroid gives 0 edge px for 6 px of
  torso wander on a 386 cell.
- deep_stalker (walk): frames 0 and 2 were the same wide spread and 1 and 3 the same bunch,
  so the pairs never alternated, and the crystal plating on the mid leg flashed on in one
  frame only. 4 to 8 frame tetrapod crawl, re-seated against the IDLE rather than the
  outgoing walk, which had played 16 percent small (body over cell 0.84 to 1.00). Audit B
  then found frames 3 and 7 were botched renders (crystal plating gone, body darker, the
  same leg lifting twice); both dropped, a 6-frame cycle.
- fungus_long (walk + 8 facings): 2-pose ping-pong in every direction, the S/SE/E facings
  drawn 11 to 13 percent bigger than the idle with root arms the idle does not have, and the
  trunk crown cut off at the top cell edge in S and E frames. 4 to 6 frames, authored S/E/N,
  SE/NE copies of E, W family mirrors. Audit B: the S/E family still rendered 12 to 22
  percent larger than the N siblings and was reseated to the idle's body.

**Wave 2 (2026-09-04), eleven more plus two 8-direction sets**
- cultist (walk): frames 0 and 2 were the same viewer-left-leg split (the closest pair in
  the strip, mean diff 27 vs 43 to 45 for every other pair), 1 and 3 the same feet-together.
  The first two rows crammed several undersized figures into one cell (the brief now says
  every figure is the same size and the image gets wider); the third roll installed. The
  idle's spiked ring staff head with a red gem is still the odd one out against the walk and
  attack's plain ring (P3, left).
- casket_creeper (walk): the coffin and head were drawn smaller in every walk frame
  (height 202 to 210 vs 242 in the idle at the same 378 cell) and the rear leg reached past
  the cell so 430 px of leg tips re-entered as orphans in frames 1 and 2; the coffin top also
  lurched 28 px across the loop. Re-seated 30 percent up to the idle's body; the orphans
  dropped (`frame_fix.py --drop-orphans`); one more fragment dropped in audit B.
- stone_broken (walk, walk_s): the played flat walk WAS the idle pose four times (height
  184, feet 229, centre 138.7 to 139.2 in every frame, onion overlays solid grey apart from
  the chest ember). Now a 6-frame stomp; autotest's Slagbound Brute contract moved from 4
  to 6 frames. The seam pass then centred it (it sat 8 percent of the cell off the idle).
  walk_s was among the recentred legacy strips (27 px).
- vow_sentinel (walk): frames 0 and 2 the same stride (onion overlay 6.9 percent
  different), one crossing frame, the same leg leading twice. 4 to 6 frames. Audit A: the
  warhammer vanished in frames 2 and 5 of the new row; filled from the neighbour frames.
  Centred in the seam pass (7.7 percent of the cell).
- zombie (walk, attack): frame 3 was byte-identical to frame 0 and frame 2 had the SAME leg
  forward as frame 1, so one leg never stepped. 4 to 6 frame shamble (the brief asks for a
  dragging corpse walk, not a march); re-rolled in wave 5. The walk (44 percent green rim)
  and attack (40 percent) were despilled.
- wolf (walk): 4 articulated poses were judged acceptable, but a 59 percent green keying
  rim on the walk (absent on the idle) showed as a dark-olive outline on sand and stone.
  Regenerated as a 6-frame trot and despilled. The attack's frame-4 lunge (about 150 px
  left in its cell) was left for your in-game look.
- winterfang (walk): same class as the wolf, 4 to 6 frame trot; the attack's leap offset
  left for your look.
- storm_harrier (walk, attack): every walk body was plainly smaller than the idle (height
  79 to 82 vs 96 to 98, 0.81 to 0.84) and sat right of the idle's centre. Regenerated and
  re-seated 16 percent up to the idle. The attack strip was despilled.
- vent_skitter (walk): idle and attack shared one body (height 220 to 222) while every walk
  frame was a smaller, lower, rounder spider (183 to 184, 0.78 to 0.80 of the mass) with a
  different crack pattern, so it shrank on move and popped back on bite; 48 percent green
  rim. Regenerated at the idle's body, despilled; audit B dropped frames 3 and 7 (the lava
  tips had vanished), a 6-frame cycle.
- bandit_scout (walk): the knee-plated leg was the front leg in all four frames and the head
  swayed 27 px across the loop. 4 to 6 frames; audit A found the new row 30 percent brighter
  than its idle (tone-matched); re-rolled in wave 5; the seam pass centred it (5.9 percent
  of the cell).
- stone_base (walk E/N/NW/S): the 256-cell 8-direction walk was a different generation
  from the 192-cell idle (7 to 10 percent shorter, head raised, bared teeth, many small
  spikes), and E/W were four near-identical bodies with a head bob. S, E and N regenerated
  at the idle's body; SE/NE copies of E, W family mirrors. Audit B: N/S rendered 12 to 22 percent
  larger than the siblings and were reseated. A pebble blink on one frame was left (P3).
- fungus_heavy (walk S, walk N): two-stance shuffle with the cap and skeletal arm 9 to 13
  percent smaller than the idle in every direction. S and N regenerated (E kept: a slow
  shambler); despilled. N still reads about 8 percent small (P3, left).

**orc_rogue, skeleton_rogue, skeleton (2026-09-04)**
- orc_rogue (walk): both feet flat on the ground line in all four frames, legs straight
  columns, no knee bend, no foot ever lifted. 4 to 6 frames; tone-matched in the seam pass
  (8 percent darker to meet its idle).
- skeleton_rogue (walk, walk_n): a near-duplicate pair in the old cycle. 4 to 6 frames;
  re-rolled in wave 5; walk_n was among the recentred legacy strips (29 px).
- skeleton (walk, attack): frames 1 and 3 were byte-identical (a 3-pose loop on the
  chapter-1 base mob) and both walk and attack carried a 19 to 21 percent green rim. The
  first regen row gave him a shield the idle never carries (my description; the rule
  "describe from the idle" was written into CLAUDE.md for this), the second roll installed
  without it; re-rolled in wave 5; both strips despilled; walk tone-matched (12 percent
  darker to meet the idle).

**Wave 3 (2026-09-05), the rest of the placed 4-frame walks**
- mummy (walk + E/N/NW): 4 pose-steps with the same leg leading every step. S/E/N
  authored, 6 frames, E family copies and mirrors.
- mummy_mage (walk + S/E/N/NE/NW): same defect, same layout, 6 frames.
- skeleton_warrior (walk + S/E/N/NW): same defect. E and N from wave 3, S (and the flat)
  from the re-run fix-up job; the E family was rebuilt in the seam pass and all three
  facings tone-matched to the idle (E 10 percent, S 7 percent, N 3 percent darker). After
  a restore mistake of mine (a frame-count mismatch against the old backups) the S strip
  was re-installed from its row.
- rat_mage (anim, walk): the idle carried a dark-green fringe along the robe, staff and tail
  (22 to 25 percent of the rim) and was despilled; the walk was 4 pose-steps, now 6 frames,
  and it sat 19 percent of the cell (35 px) to the right of the idle, the biggest seam
  offset in the corpus; centred.
- flux_hound, rime_wolf, slag_hound, void_hound (anim, walk): 4 stiff poses, no trot; now
  6-frame trots. The seam scan then found all four walks played about 25 percent smaller
  than their idles on the first step (the rows came back with small figures); reseated to
  the idle body (flux +35, rime +24, slag +26, void +33 percent by my measurement), rime_wolf
  and void_hound also centred (14 and 8 percent of the cell). Idles recentred in the sweep
  (rime 33, void 32, slag 38, flux 37 px of drift).
- root_spiderling (anim, walk): 4 stiff poses, legs did not cycle; 8-frame crawl. Idle
  recentred (28 px).
- bog_lurker (walk): 4 stiff poses, one frame with a whole lower-leg segment (1305 px)
  floating in open air under the abdomen (dropped with `frame_fix` on day 1). 8-frame
  crawl from a two-row grid (560 px cell, no upscale); two botched raised-leg frames
  dropped; tone-matched (2 percent); re-installed once after the restore mistake.

**Wave 5 (2026-09-05), the seven bipeds that still scissored**
- elf_ranger, royal_knight, skeleton, zombie, elf_druid, skeleton_rogue, bandit_scout: the
  wave-1/2 rows lifted no boot; the leading boot slid forward and back on the ground and no
  frame showed the swing leg passing the planted one (a "scissor shuffle"). Re-rolled with
  a crossing-hardened brief: two passing frames per loop, one per leg, swing boot crossing
  in front with the knee bent and the sole showing, "two boots flat side by side in more
  than one frame = wrong". `tools/art/gait_metrics.py` reports the lifted side per frame;
  each installed row alternates. The wave-1 rows are in
  `art_src/mob_gait_wave5_2026-09-05/old_backup/`. Look for: alternate boots lifting, a bent
  knee on the swing leg, and the elf_druid's root skirt present in all six frames.

### Frame edits and despills (no regeneration)
- spider (attack, walk + 8 facings, death): all eight walk facings and the attack ringed
  green; despilled. spider_walk was among the recentred legacy strips (63 px of drift, SE/SW
  39).
- orc (attack, walk_n, walk_s): the attack carried a green halo on every frame (43 to 53
  percent of rim pixels, absent on the idle); despilled. walk_n and walk_s recentred (49 and
  37 px). The 8-frame orc walk is the biped gait donor and was not touched.
- cold_pilgrim (anim, attack, walk, death): all despilled; the unused walk file was 18
  percent brighter than the idle and was tone-matched (it is not wired: the pilgrim is an
  idle-only glider). death new.
- stormcult (static, anim, attack, death): despilled; idle recentred (9 px). death new.
- vale_mourner (static, anim, death): despilled; idle recentred (10 px). death new. The
  attack strip's 8 percent size pop was not addressed.
- royal_knight walk_n despilled; walk_s recentred (30 px). elf_druid walk_n recentred
  (29 px).
- static_caller (walk): 22 percent brighter than its idle, tone-matched. Its death strip's
  bronze ring over the head (audit finding) was not addressed.
- skeleton_mage (walk): 19 percent brighter than its idle, tone-matched.
- heart_of_the_root (walk): 5 percent darker to meet its idle; idle recentred (41 px).
- fungus_immature (walk, death): walk tone-matched; death new.
- greyrun_lurker (anim, death): idle recentred (55 px); death new. Its attack strip's
  0.86x shrink per bite was not addressed.
- grove_horror (anim, walk, death): idle and walk recentred (11 and 46 px); death new.

### Corpus seam sweep: recentred idles and legacy walks

A scan of every enemy's idle-to-walk seam (centre offset, feet line, luminance, body ratio,
per-frame jitter) found a class of defect the earlier audits met only once, on nullwarden:
older 4-frame idles and walks were sliced off their frame grid, so the figure slid 15 to 30
percent of the cell across the loop, a constant jitter at rest. `recenter_strip.py --apply`
re-anchored every frame on its feet band: 68 idles and 97 legacy walks (backups in
`art_src/_backups/recenter/`). Gait-lane walks were NOT recentred: the feet-band anchor adds
torso wobble to a real stride, and the 14 that had been were restored. Two idles keep a
4 to 6 px residual (grove_horror, nullwarden); bannerman's 4th idle frame was already
clipped in the source and needs a regen to recover. The table lists every mob subject whose
only change is this recentre, with the drift that was removed (max per-frame feet-anchor
offset, px):

| subject | idle drift px | walk drift px |
|---|---:|---:|
| aldric_burned_out | 34 | 31 |
| anchor_vine | 23 | - |
| archon_vassik | 56 | 46 |
| bannerman | 56 | 63 |
| bellows_imp | 33 | - |
| bloat_leech | 33 | 32 |
| broodmother_yskara | 13 | - |
| burned_kings_echo | 56 | 26 |
| choir_ascendant | 35 | 43 |
| choir_of_frost | 30 | 38 |
| choir_radical | 38 | 44 |
| chorister_of_frost | 51 | 47 |
| cindersmith | 25 | - |
| cistern_mimic | 29 | 30 |
| commander_drayce | 33 | 39 |
| conductor_acolyte | 41 | 40 |
| converted | 39 | 47 |
| crusade_zealot | 36 | 45 |
| cure_seeker_heretic | 31 | - |
| drowned_warden | 46 | 38 |
| elara_vessel | 48 | 45 |
| field_chirurgeon | 38 | 31 |
| forge_zealot | 30 | 26 |
| foundry_thrall | 48 | 46 |
| glasshide_stalker | 22 | 27 |
| grove_tender | 28 | 35 |
| high_artificer_maeven | 42 | 43 |
| hollow_knight | 49 | 44 |
| korrag_reborn | 31 | 32 |
| morwyn_hollow_flame | 37 | 39 |
| mouth_of_the_storm | 19 | - |
| oathbound_knight | 39 | 45 |
| overgrown_gatewarden | 36 | 36 |
| pale_nursery | 26 | - |
| pollen_drifter | 48 | - |
| riftling | 34 | 41 |
| rootspawn | 39 | 36 |
| rootweaver | 41 | 32 |
| sand_revenant | 43 | 62 |
| shardcaller | 22 | 25 |
| shattered_vow | 34 | 36 |
| sleepwalker | 40 | 41 |
| sluice_lurker | 30 | 40 |
| storm_adept | 64 | 64 |
| thorn_howler | 25 | 27 |
| unfinished_sentence | 47 | 55 |
| verdant_anvil | 24 | - |
| verdict_drone | 55 | 53 |
| waking_shard | 40 | 59 |
| word_wisp | 15 | - |

(50 subjects; a dash means that strip was already on its grid.)

Look for: the figure standing still in the idle loop and not hopping when it starts to
walk. The OLD half of each GIF shows the slide.

### Death clips (27 mobs; every one is NEW, so the GIF has only a right half)

Until this branch no mob death strip was ever played (nothing called
`play_action("death")`); a mob froze on its walk frame, inflated 1.3x and faded. The engine
now plays `<base>_death` (last frame held, then fade) and the lane
(`tools/art/death_briefs.py` + `install_death_row.py`) built the missing ones: a 6-frame row
per mob, identity = idle frame 0, storyboard per archetype (biped: hit, stagger, knees,
topple, ground, still; quadruped: head jerk, front legs buckle, chest drops, rolls to the
side, flat, still; arachnid: jolt, legs curl, sinks, tips, curls, still; glide: recoil, cloth
sags, sinks, folds, crumples, heap). Installed at the idle's scale with each frame's own
extent, feet on the idle's feet line, no blood or particles (the game adds its own).
- Quadrupeds: wolf, winterfang, blightwolf, duneprowler, grove_horror. Scale = the geometric
  mean of the length and height ratios to the idle (a howl in frame 0 changes the height,
  not the length). winterfang's and blightwolf's lying figures touched in the row, so they
  were sliced at equal widths instead of at gutters; duneprowler too (gutter slicing gave
  it blank cells).
- Arachnids: deep_stalker, casket_creeper, vent_skitter, bog_lurker, greyrun_lurker, spider.
  spider's row had unevenly spaced figures and was sliced by 2-D connected components
  (figures grouped by x-overlap, specks dropped, a merged pair split at its thinnest column).
- Bipeds: cultist, mummy_rogue, mummy_warrior, rat_rogue, rat_warrior, zombie_overweight,
  fungus_immature, flame_pilgrim, blooming_convert, elf_wild, ragged_soldier, ridge_deserter,
  vale_mourner (and choir_pilgrim under npcs/). First installs scaled frame 0 by its full
  bbox and a raised hand or weapon made the body about 10 percent small; the installer now
  scales by the body height in the central column band and all sixteen bipeds were
  re-installed with frame-0 body within 5 percent of the idle. cultist's two lying frames
  touched (equal-width slice); mummy_warrior, rat_rogue, rat_warrior and zombie_overweight
  needed the component slicer.
- Gliders: cold_pilgrim, stormcult (a robe collapsing into a heap).
- Skipped on purpose: the 32 px legacy placeholders (beastkin, sentry, verdant_*) and the
  tick critters.
Look for: the standing frame matching the idle's size, a continuous fall with no slide, the
last frame lying flat and wide.

### Left as-is in mobs/ (verified, not changed)
- wolf, rotmaw, veyx, duneprowler, casket_creeper hue nits vs their idles (P3).
- cultist idle staff head vs walk/attack; fungus_heavy N about 8 percent small; stone_base
  pebble blink; wolf and winterfang attack lunge offsets (your in-game look first).
- greyrun_lurker attack 0.86x, null_acolyte attack 1.07x, vale_mourner attack 1.08x,
  static_caller death ring, skeleton_warrior death hem, mummy/rat_mage death attire
  (Fangmoot-only exposure).
- banshee front facings lack the hood eye-glint the idle has; 4-frame gliders (banshee,
  word_wisp, waking_shard, verdict_drone, pollen_drifter, riftling, elara_vessel,
  static_caller, null_acolyte, skeleton_mage, mummy_mage idle) keep their drift loops: that
  is the right motion for a floater.


---

## npcs/  (7 GIFs)

- npc_bandit_tracker, npc_villager_f, npc_villager_m, npc_scholar_a, npc_scholar_b, villager:
  the day-1 props/NPC audit measured a dark-olive keying fringe along skirt, trouser and boot
  edges on the chapter-2 wanderer bodies (npc_bandit_tracker 589 rim px, 37 percent of the
  2 px silhouette rim; npc_villager_f 393; villager 294; npc_villager_m 256; npc_scholar_a
  244). Rim-band despill only, so npc_scholar_b's green coat (his own colour) is untouched.
  Sub-pixel on grass, visible on dark floors at 4x. Look for: no olive line on the hem.
- choir_pilgrim (death): new, from the death lane (the hub uses this sprite as an NPC body,
  which is why it sorts here). Look for the plump robed figure sinking, hands still clasped.
- Not done from the audit: merchant and onna are 1.50x masters (a regen each), piet's se/sw
  facings pop 14 percent on turn (the raised spear inflates the alpha box the NPC facing
  path normalises by). All in `art_src/QA_FINDINGS.md` under props-npcs.

## capital/  (42 GIFs: 26 pieces, 15 animated strips, the floor)

The capital was "pending a visual update". Three layers, in the order they landed:

1. **Light sockets and the portal strobe (code + data, no art).** Every capital structure
   carried a fire flag but no light list, so the braziers burned over dead stone. Nine
   definitions now carry sockets derived from the art itself (`derive_light_sockets.py`
   clusters the flame cores and converts them through the placement math; calibrated on
   torch_pillar's hand-authored socket, off by 1 to 3 px): crown_spire_gate, emberward_gate,
   ashfire_forge, ashen_tankard, market_stall, sable_hall, proving_gate, portal_crucible,
   great_hearth. The story gate gets a pale-blue pool. capital_portal_depths animated
   bright/bright/bright/dim, a 57 percent swing every 0.67 s (the fire ceiling is 25) with
   frame 2 a byte copy of frame 0; both portal strips were re-derived (depths swirl, story
   flicker), worst swing now 16.5 and 15.6 percent, silhouette byte-stable.
2. **The floor.** No audit had opened a ground tile. The plaza's holystone field tile read
   luminance 188 (third brightest floor in the game after snow 223 and sand 190) under a
   building kit at 44 to 47: a 4.2x ratio, which is why the plaza read as black cutouts on
   gold. Graded (saturation x0.62, value x0.78) to 151: still the brightest civic stone,
   the gold cooled toward stone. `ground_field_holystone.gif` is this one file. It took
   three shot cycles to see because ground tiles load through the resource importer.
3. **All 26 pieces repainted painterly** (the capital was crisp pixel-art architecture
   beside a painterly cast): brief = a painterly sibling as the STYLE reference, the old
   piece as the SUBJECT (silhouette, footprint, every part in place, muted palette).
   Installed keyed, saturation minus 14 percent, tight-cropped (the autotest contract), at
   2.30x their authored world width (was 1.0 to 1.4x; the city arcade stays 0.92x, a
   1650 px backdrop the generator cannot reach). Every fire/water/portal `_anim` was
   re-derived from the new static at 4 frames on the static's canvas with the fire ceiling
   respected. Pieces: accord_longhouse, alembic_station, ashen_tankard, ashfire_forge,
   chartered_hall, city_arcade, city_bench, city_directory, crown_fountain,
   crown_spire_gate, emberward_gate, grand_archive, great_hearth, market_stall,
   portal_crucible, portal_depths, portal_story, proving_gate, rot_chapel, sable_hall,
   stables, undercroft, vault_chest, watchtower, wellspring, wildfang_fangmoot.
   Look for: identity held (the vet sheet in `art_src/capital_painterly_2026-09-03/` shows
   each piece beside its old self), no black outlines, the flame-only motion on the anim
   strips. Judge the whole plaza in-game: `shot.bat capital` shoots nine rooms (the tour
   rig used to shoot room 0 nine times; fixed).

## props/  (9 subjects, 11 GIFs)

- tree_green2, tree_green4 (+ anims): canopy saturation 0.72 and 0.76 with 88 to 92 percent
  of pixels above 0.6, against tree_green 0.47 (3 percent) and tree_green3 0.43 (1 percent):
  lime candy-green beside olive siblings. Graded over a green mask only (the caramel trunks
  are untouched), the same transform applied to the static and every anim cell so nothing
  drifts frame to frame.
- grass2, grass3: value 0.45 and 0.44 vs grass 0.27; darkened and desaturated toward grass.
- toadstool, mushroom2, mushroom3: a fire-engine fly-agaric, a golden cluster and pastel
  lavender caps beside mushroom's brick; about 30 percent desaturated and 15 percent
  darkened (matching the reference's palette means was tried and rejected: it wanted a 45
  percent darkening and a saturation INCREASE for mushroom3).
- cactus2: a clean-green clip-art saguaro beside the scarred cactus; graded.
- bridge: green keying ring despilled.
- Verified in all eight grades: alpha and canvas byte-identical before and after,
  `audit_prop_anims` still 0 flagged.

## travel/  (7 GIFs)

Old vs new walks over scrolling ground at the mob's real in-game speed, the only way to see
foot skating: cultist, royal_knight, stone_broken, wolf, zombie, and the mage and warlock
walk_e. Walks march in place by your ruling, so a foot that slides is expected; what changed
is the stride shape. The mage's new walk_e reads at 0.14 bodies per cycle, the same
marching family as the assassin (0.22) and archer (0.22).

---

## In-game only (no GIF can show these)

- **Enemy motion stack** (`enemy.gd`, `boss.gd`, `game_base.gd`, `balance.gd`): the hero
  lane's stride-locked juice ported to mobs and bosses per body archetype (biped chest rise
  per step and bank into travel; quadruped one bob per cycle and nose pitch; glide lean
  only), keyed to the strip's own clock. One per-frame transform writer composes every
  transient (bounce, lean, hit squash, windup crouch, pounce stretch, spawn-in, death
  collapse) as multipliers, so a strip swap can no longer strand a stale scale. Footfall
  dust on contact crossings (budgeted, range-culled), boss stomp rumble under the hit kick,
  8-direction turn hysteresis (an orbiting player used to strobe a boss between two strips
  every physics tick), walk entry on a planted frame, bite-windup crouch that snaps on the
  bite, summon spawn-in. Real deaths: the 21 death clips that already shipped are played
  (nothing ever called them), sheetless bodies collapse feet-pinned instead of inflating.
- **Four bugs fixed under that read**: elites reverted to base size on their first step
  (the promotion wrote the sprite scale the strip swap recomputes); every Act-1 boss GLIDED
  for co-op guests (the network mirror never read the directional walk set); the hit
  squash lifted the feet; the walk clock was only half speed-coupled (a 0.35 slow played
  at 67 percent).
- **Boss tells**: all 47 telegraph sites painted the same rimmed disc and seven bosses
  shared one pale blue. Each of 22 bosses now has a hue and a ground figure (ring, cone,
  line, cross, square) drawn INSIDE the danger disc, and the fill ramps over the fuse and
  snaps twice at the end so time-to-pop is readable. The disc is still the only hit test
  (a cone as a hit shape would have cut some danger areas to 17 percent; not a balance
  pass). `shot.bat tells` shoots one frame per boss.
- **Boss windup posture**: through a tell's fuse each boss holds a per-kind body posture
  and snaps on release. Brutes crouch and widen (vargoth, nullwarden, stormmouth, auroch,
  fangmaw, cinderhide, saint_varo, whitepelt, icebound, first_howl); casters and floaters
  draw up (morwen, choirmother, vess, forgemistress, ashpriest, sleepkeeper, gardener,
  unnamed_echo); skirmishers lean into the aim (stormwarden, sexton); serpents coil
  (curetwisted, stormdrake_veyx). Knobs: crouch 11 percent, lean 0.17 rad. Visual only;
  autotest spawns a real vargoth and asserts the crouch reaches the sprite. Review:
  `shot.bat tells --bosses --phase=0.85` against `--phase=0.02` (the sheet
  `art_src/_qa_final/tells_windup_compare.png` has both).
- **Capital light sockets and the portal strobe**: above.

## Your calls (also in the board's Open list)

- paladin walk_n: the installed back-view regen vs the re-sliced old cycle beside it.
- stormmouth N: about 15 percent slimmer across the pauldrons than S and the idle after
  three rolls, and no rear crest on the helm from behind.
- bannerman idle frame 4 was already clipped in the source; only a regen recovers it.
- Tone and hue nits left on purpose: korrag N still slightly dark, serane N 12 percent
  brighter than the idle, echo N teal wings, veyx steel-blue cast, warlock attack_walk_e
  trim 5 degrees yellower, mage anim_e 5 percent dim, wolf/rotmaw/veyx/duneprowler hue.
- Not addressed from the audits: assassin walk_e cloak balloon and walk_s bootless frames,
  archer walk_n cape green-on-content, saint_varo blade fidelity (192 px cell beside 627 px
  siblings), greyrun_lurker attack 0.86x, merchant/onna 1.5x masters, the twelve landmark
  structures rendered at 1.17 to 1.65x.

## Gates on the final tree

Full suite AUTOTEST PASS (172 sections) three times, the last with the windup code and all
47 death clips; PREFLIGHT OK; a confirming desktop import (exit 0) and quick suite; mobile
`sync_mobile --apply --gate` GATE OK six times (the last after the boss deaths, 47 files);
corpus `verify_art` sweep over 312 bases with zero non-import FAILs; the green-rim scan at 0.
Every commit on the branch passed the compile gate and the quick suite.

Where things are: `VISUAL_OVERHAUL_2026-09-03.md` (the board), `art_src/QA_FINDINGS.md`
(the day-1 audit, 840 lines), `art_src/<lane>_2026-09-0x/` (every brief, row, codex log and
old backup), `art_src/_backups/` (every replaced strip), `tools/INDEX.md` (every tool named
above).

---

## Appendix A. Per-subject change log

Every GIF subject with the commits that touched its sprites (subjects appear in their folder
order; a commit is listed once per subject).

- **classes/archer** (4 GIFs: archer_attack_walk, archer_attack_walk_e, archer_attack_walk_n, archer_attack_walk_nw)
  - Art wave 2: 11 more mob walks, 12 boss walk facings, the 26-piece capital repaint, and fire-on-move for the base classes
- **classes/assassin** (8 GIFs: assassin_attack_walk, assassin_attack_walk_b, assassin_attack_walk_b_e, assassin_attack_walk_b_n, assassin_attack_walk_b_nw, assassin_attack_walk_e, assassin_attack_walk_n, assassin_attack_walk_nw)
  - Wave 3: 16 placed mob/boss walks regenerated (mummy S/E/N, mummy_mage S/E/N, skeleton_warrior E/N, rat_mage, flux_hound, rime_wolf, slag_hound, void_hound, fangmaw, ...
  - Art wave 2: 11 more mob walks, 12 boss walk facings, the 26-piece capital repaint, and fire-on-move for the base classes
- **classes/mage** (16 GIFs: mage_anim_e, mage_anim_w, mage_attack_e, mage_attack_w, mage_attack_walk, mage_attack_walk_b, mage_attack_walk_b_e, mage_attack_walk_b_n, mage_attack_walk_b_nw, mage_attack_walk_e, mage_attack_walk_n, mage_attack_walk_nw, mage_cast_e, mage_cast_w, mage_walk_e, mage_walk_w)
  - ashpriest S: green keying patch fully neutralised (strict mask everywhere, loose mask + de-green confined to the flail gap); mage attack_walk_b N (frame 3's missing ...
  - Audit B fixes (quad/creature mobs + boss facings, each re-checked by hand) + mage attack_walk_b S/E
  - QA round on the last installs (findings from a 9-subject audit, each verified by hand before acting)
  - Mage attack_walk E family regenerated from the new profile walk (the shipped one was built on the old front-facing walk); SE/NE copies, W/NW/SW mirrors
  - Mage E column as a true profile + paladin north walk re-slice
  - Art wave 2: 11 more mob walks, 12 boss walk facings, the 26-piece capital repaint, and fire-on-move for the base classes
- **classes/paladin** (1 GIF: paladin_walk_b_n)
  - Paladin walk_n: install the gait-transfer back-view regen (shield stable on the arm every frame); the re-sliced old cycle stays beside it as a one-copy swap. ...
  - Mage E column as a true profile + paladin north walk re-slice
  - Boss walk geometry re-seats (nullwarden 60%-size walk, saint_varo E/W cell, 5 more) + the paladin's broken north walk
- **classes/warlock** (28 GIFs: warlock_attack, warlock_attack2, warlock_attack2_e, warlock_attack2_n, warlock_attack2_ne, warlock_attack2_nw, warlock_attack2_s, warlock_attack2_se, warlock_attack2_sw, warlock_attack2_w, warlock_attack_e, warlock_attack_n, warlock_attack_ne, warlock_attack_nw, warlock_attack_s, warlock_attack_se, warlock_attack_sw, warlock_attack_w, warlock_attack_walk, warlock_attack_walk_b, warlock_attack_walk_b_e, warlock_attack_walk_b_n, warlock_attack_walk_b_nw, warlock_attack_walk_e, warlock_attack_walk_n, warlock_attack_walk_nw, warlock_walk_e, warlock_walk_w)
  - Corpus seam sweep + fix-up batch installs
  - Warlock attack_walk N regenerated from walk_n (the old one carried a second skull at the elbow in f2/f3)
  - QA round on the last installs (findings from a 9-subject audit, each verified by hand before acting)
  - Warlock attack_walk E family from the job's final row (it iterated the baked hand-flame out of the thrust frames; the game spawns the bolt)
  - Warlock attack_walk E family regenerated from the new profile walk (SE/NE copies, W/NW/SW mirrors)
  - Warlock walk E/W as a true profile (was a 3/4 front view against his full-profile side idle; hood snapped to camera on the first step). Same profile lane as the mage; ...
  - Art wave 2: 11 more mob walks, 12 boss walk facings, the 26-piece capital repaint, and fire-on-move for the base classes
  - Green keying-ring sweep (63 sprites) + orphan frame edits + the QA findings board
- **classes/warrior** (2 GIFs: warrior_walk_e, warrior_walk_nw)
  - Wave 3: 16 placed mob/boss walks regenerated (mummy S/E/N, mummy_mage S/E/N, skeleton_warrior E/N, rat_mage, flux_hound, rime_wolf, slag_hound, void_hound, fangmaw, ...
- **bosses/ashpriest** (3 GIFs: ashpriest_death, ashpriest_walk_codex_n, ashpriest_walk_codex_s)
  - Boss tell WINDUP posture: each boss holds a per-kind body posture through a tell's fuse and snaps on release
  - ashpriest S: green keying patch fully neutralised (strict mask everywhere, loose mask + de-green confined to the flail gap); mage attack_walk_b N (frame 3's missing ...
  - Audit B fixes (quad/creature mobs + boss facings, each re-checked by hand) + mage attack_walk_b S/E
  - Art wave 2: 11 more mob walks, 12 boss walk facings, the 26-piece capital repaint, and fire-on-move for the base classes
- **bosses/auroch_minotaur** (5 GIFs: auroch_minotaur_death, auroch_minotaur_walk_codex_e, auroch_minotaur_walk_codex_n, auroch_minotaur_walk_codex_nw, auroch_minotaur_walk_codex_s)
  - Boss tell WINDUP posture: each boss holds a per-kind body posture through a tell's fuse and snaps on release
  - Corpus seam sweep + fix-up batch installs
  - Audit B fixes (quad/creature mobs + boss facings, each re-checked by hand) + mage attack_walk_b S/E
  - Art wave 2: 11 more mob walks, 12 boss walk facings, the 26-piece capital repaint, and fire-on-move for the base classes
- **bosses/choirmother** (3 GIFs: choirmother_death, choirmother_walk_codex_n, choirmother_walk_codex_s)
  - Boss death clips: rotmaw, serane, veyx, choirmother, echo, forgemistress, halla (12 of 20 in)
  - Idle-to-walk seam fixes: 14 walks tone-matched to their idles, the four hounds reseated to idle body size, seven walks centred on their idle (rat_mage was 19% of the ...
  - Wave 4 re-rolls installed: blightwolf walk back in the idle's near-black olive with the lime shoulder vein (heights normalised, graded toward the idle); choirmother N ...
  - Art wave 2: 11 more mob walks, 12 boss walk facings, the 26-piece capital repaint, and fire-on-move for the base classes
- **bosses/cinderhide** (2 GIFs: cinderhide_attack, cinderhide_walk)
  - cinderhide walk: 6-frame three-headed trot from a two-row grid (was 4 stiff poses); skeleton_warrior S walk (+flat) from the re-run fix-up job
  - cinderhide attack f3: erase the neighbour-cell claw sliver at the left edge
- **bosses/echo** (4 GIFs: echo_death, echo_walk_codex_e, echo_walk_codex_n, echo_walk_codex_nw)
  - Boss death clips: rotmaw, serane, veyx, choirmother, echo, forgemistress, halla (12 of 20 in)
  - Corpus seam sweep + fix-up batch installs
  - echo N walk: the winged flame-skull from behind, dagger in one hand every frame
- **bosses/fangmaw** (2 GIFs: fangmaw_anim_codex, fangmaw_walk)
  - Idle-to-walk seam fixes: 14 walks tone-matched to their idles, the four hounds reseated to idle body size, seven walks centred on their idle (rat_mage was 19% of the ...
  - Corpus seam sweep + fix-up batch installs
  - Wave 3: 16 placed mob/boss walks regenerated (mummy S/E/N, mummy_mage S/E/N, skeleton_warrior E/N, rat_mage, flux_hound, rime_wolf, slag_hound, void_hound, fangmaw, ...
- **bosses/first_howl** (1 GIF: first_howl_death)
  - Boss death clips: morwen, nullwarden, saint_varo_standing, sexton, stormmouth, vargoth, vess, first_howl (20 of 20); board 11 (windup postures + boss deaths)
- **bosses/forgemistress** (2 GIFs: forgemistress_death, forgemistress_walk_codex_n)
  - Boss death clips: rotmaw, serane, veyx, choirmother, echo, forgemistress, halla (12 of 20 in)
  - Corpus seam sweep + fix-up batch installs
- **bosses/glacius** (2 GIFs: glacius_anim, glacius_walk)
  - Corpus seam sweep + fix-up batch installs
- **bosses/halla** (2 GIFs: halla_anim_codex, halla_death)
  - Boss death clips: rotmaw, serane, veyx, choirmother, echo, forgemistress, halla (12 of 20 in)
  - Corpus seam sweep + fix-up batch installs
- **bosses/hrolgar** (4 GIFs: hrolgar_death, hrolgar_walk_codex_e, hrolgar_walk_codex_n, hrolgar_walk_codex_nw)
  - Boss tell WINDUP posture: each boss holds a per-kind body posture through a tell's fuse and snaps on release
  - Wave 4 re-rolls installed: blightwolf walk back in the idle's near-black olive with the lime shoulder vein (heights normalised, graded toward the idle); choirmother N ...
  - Art wave 2: 11 more mob walks, 12 boss walk facings, the 26-piece capital repaint, and fire-on-move for the base classes
- **bosses/kaethra** (4 GIFs: kaethra_death, kaethra_walk_codex_e, kaethra_walk_codex_n, kaethra_walk_codex_nw)
  - Boss tell WINDUP posture: each boss holds a per-kind body posture through a tell's fuse and snaps on release
  - Art wave 2: 11 more mob walks, 12 boss walk facings, the 26-piece capital repaint, and fire-on-move for the base classes
- **bosses/korrag** (5 GIFs: korrag_death, korrag_walk_codex_e, korrag_walk_codex_n, korrag_walk_codex_nw, korrag_walk_codex_s)
  - Tells rig --bosses mode (a real boss per kind fires its tell with AI silenced) for windup review; windup knobs 0.11 / 0.17 rad; korrag death clip
  - Corpus seam sweep + fix-up batch installs
  - QA round on the last installs (findings from a 9-subject audit, each verified by hand before acting)
  - korrag E (with his lightning), skeleton (without the invented shield), veyx E (with his bulk)
- **bosses/morwen** (2 GIFs: morwen_death, morwen_walk)
  - Boss death clips: morwen, nullwarden, saint_varo_standing, sexton, stormmouth, vargoth, vess, first_howl (20 of 20); board 11 (windup postures + boss deaths)
  - Boss walk geometry re-seats (nullwarden 60%-size walk, saint_varo E/W cell, 5 more) + the paladin's broken north walk
- **bosses/nullwarden** (6 GIFs: nullwarden_anim_codex, nullwarden_death, nullwarden_walk_codex_e, nullwarden_walk_codex_n, nullwarden_walk_codex_nw, nullwarden_walk_codex_s)
  - nullwarden idle: the recentre pass had emptied its last frame (1px of alpha) -- restored to the centred pre-recentre version; bog_lurker/cinderhide/skeleton_warrior S ...
  - Boss death clips: morwen, nullwarden, saint_varo_standing, sexton, stormmouth, vargoth, vess, first_howl (20 of 20); board 11 (windup postures + boss deaths)
  - Corpus seam sweep + fix-up batch installs
  - QA round on the last installs (findings from a 9-subject audit, each verified by hand before acting)
  - Nullwarden N from the two-row hi-res request (850px figures, installed near-native at the E strip's geometry)
  - Nullwarden N: the job's final row (leg phases resolved as one 3-frame step + mirror); grid_to_row.py for two-row hi-res requests; board caveats
  - Nullwarden walk N: true back view with empty fists (v2 roll; v1 invented a slung greatsword his idle/E walk never carry; the old N was front art)
  - Boss walk geometry re-seats (nullwarden 60%-size walk, saint_varo E/W cell, 5 more) + the paladin's broken north walk
- **bosses/rotmaw** (4 GIFs: rotmaw_death, rotmaw_walk_codex_e, rotmaw_walk_codex_nw, rotmaw_walk_codex_s)
  - Boss death clips: rotmaw, serane, veyx, choirmother, echo, forgemistress, halla (12 of 20 in)
  - Corpus seam sweep + fix-up batch installs
  - rotmaw E walk: the hulk is a hulk again; docs for the new lanes and the lessons
- **bosses/saint_varo** (3 GIFs: saint_varo_standing_death, saint_varo_standing_walk_codex_e, saint_varo_standing_walk_codex_nw)
  - Boss death clips: morwen, nullwarden, saint_varo_standing, sexton, stormmouth, vargoth, vess, first_howl (20 of 20); board 11 (windup postures + boss deaths)
  - Boss walk geometry re-seats (nullwarden 60%-size walk, saint_varo E/W cell, 5 more) + the paladin's broken north walk
- **bosses/serane** (4 GIFs: serane_death, serane_walk_codex_e, serane_walk_codex_nw, serane_walk_codex_s)
  - Boss death clips: rotmaw, serane, veyx, choirmother, echo, forgemistress, halla (12 of 20 in)
  - QA round on the last installs (findings from a 9-subject audit, each verified by hand before acting)
  - Serane S: the clean 6-figure re-roll replaces the 4-frame salvage
  - Serane S walk: 4-frame glide from the fix3 row (was a byte copy of the idle); normalize_row.py for crammed rows; stormmouth/nullwarden N first rolls archived as rejected ...
  - Boss walk geometry re-seats (nullwarden 60%-size walk, saint_varo E/W cell, 5 more) + the paladin's broken north walk
- **bosses/sexton** (4 GIFs: sexton_death, sexton_walk_codex_e, sexton_walk_codex_n, sexton_walk_codex_nw)
  - Boss death clips: morwen, nullwarden, saint_varo_standing, sexton, stormmouth, vargoth, vess, first_howl (20 of 20); board 11 (windup postures + boss deaths)
  - Corpus seam sweep + fix-up batch installs
  - Boss walk geometry re-seats (nullwarden 60%-size walk, saint_varo E/W cell, 5 more) + the paladin's broken north walk
- **bosses/smelter_lord_thrain** (2 GIFs: smelter_lord_thrain_anim, smelter_lord_thrain_walk)
  - Corpus seam sweep + fix-up batch installs
- **bosses/stormmouth** (5 GIFs: stormmouth_death, stormmouth_walk_codex_e, stormmouth_walk_codex_n, stormmouth_walk_codex_nw, stormmouth_walk_codex_s)
  - Boss death clips: morwen, nullwarden, saint_varo_standing, sexton, stormmouth, vargoth, vess, first_howl (20 of 20); board 11 (windup postures + boss deaths)
  - Corpus seam sweep + fix-up batch installs
  - Stormmouth N v3: a real stride (rear boot lifts 25-70px vs +-4 before) and the family's blue-steel plate; hi-res grid; bulk still slimmer than the S walk (generator ...
  - Stormmouth N from the two-row hi-res request: 890px figures (installed at 0.65x, no upscale), wider pauldrons closer to the idle
  - Stormmouth walk N: true back view (v2 roll with the chest maw named front-only; was a byte copy of E)
- **bosses/thornfather_grael** (2 GIFs: thornfather_grael_anim, thornfather_grael_walk)
  - Corpus seam sweep + fix-up batch installs
- **bosses/vargoth** (5 GIFs: vargoth_anim_codex, vargoth_death, vargoth_walk_codex_e, vargoth_walk_codex_n, vargoth_walk_codex_nw)
  - Boss death clips: morwen, nullwarden, saint_varo_standing, sexton, stormmouth, vargoth, vess, first_howl (20 of 20); board 11 (windup postures + boss deaths)
  - Corpus seam sweep + fix-up batch installs
  - Boss walk geometry re-seats (nullwarden 60%-size walk, saint_varo E/W cell, 5 more) + the paladin's broken north walk
- **bosses/vess** (4 GIFs: vess_death, vess_walk_codex_e, vess_walk_codex_n, vess_walk_codex_w)
  - Boss death clips: morwen, nullwarden, saint_varo_standing, sexton, stormmouth, vargoth, vess, first_howl (20 of 20); board 11 (windup postures + boss deaths)
  - Corpus seam sweep + fix-up batch installs
  - Boss walk geometry re-seats (nullwarden 60%-size walk, saint_varo E/W cell, 5 more) + the paladin's broken north walk
- **bosses/veyx** (4 GIFs: veyx_death, veyx_walk_codex_e, veyx_walk_codex_nw, veyx_walk_codex_s)
  - Boss death clips: rotmaw, serane, veyx, choirmother, echo, forgemistress, halla (12 of 20 in)
  - Corpus seam sweep + fix-up batch installs
  - veyx E walk installed (the first attempt refused a speck cell; re-sliced at --frames 6)
  - Boss walk geometry re-seats (nullwarden 60%-size walk, saint_varo E/W cell, 5 more) + the paladin's broken north walk
- **mobs/aldric_burned_out** (2 GIFs: aldric_burned_out_anim, aldric_burned_out_walk)
  - Corpus seam sweep + fix-up batch installs
- **mobs/anchor_vine** (1 GIF: anchor_vine_anim)
  - Corpus seam sweep + fix-up batch installs
- **mobs/archon_vassik** (2 GIFs: archon_vassik_anim, archon_vassik_walk)
  - Corpus seam sweep + fix-up batch installs
- **mobs/bandit_scout** (1 GIF: bandit_scout_walk)
  - Idle-to-walk seam fixes: 14 walks tone-matched to their idles, the four hounds reseated to idle body size, seven walks centred on their idle (rat_mage was 19% of the ...
  - Wave 5: the seven scissoring bipeds re-rolled with crossing-hardened briefs (elf_ranger, royal_knight, skeleton, zombie, elf_druid, skeleton_rogue, bandit_scout) -- ...
  - Audit A fixes: vow_sentinel's warhammer vanished in f2/f5 (filled from the neighbour frames); bandit_scout walk tone-matched to its idle (was 30% brighter); royal_knight ...
  - Art wave 2: 11 more mob walks, 12 boss walk facings, the 26-piece capital repaint, and fire-on-move for the base classes
- **mobs/bannerman** (2 GIFs: bannerman_anim, bannerman_walk)
  - Corpus seam sweep + fix-up batch installs
- **mobs/bellows_imp** (1 GIF: bellows_imp_anim)
  - Corpus seam sweep + fix-up batch installs
- **mobs/blightwolf** (2 GIFs: blightwolf_death, blightwolf_walk)
  - Death clips (first eight): wolf, winterfang, blightwolf, duneprowler, deep_stalker, casket_creeper, vent_skitter, bog_lurker -- 6-frame collapses from the death lane ...
  - Idle-to-walk seam fixes: 14 walks tone-matched to their idles, the four hounds reseated to idle body size, seven walks centred on their idle (rat_mage was 19% of the ...
  - Wave 4 re-rolls installed: blightwolf walk back in the idle's near-black olive with the lime shoulder vein (heights normalised, graded toward the idle); choirmother N ...
  - Mob walks wave 1: seven creatures regenerated as real gaits (gait-transfer lane)
- **mobs/bloat_leech** (2 GIFs: bloat_leech_anim, bloat_leech_walk)
  - Corpus seam sweep + fix-up batch installs
- **mobs/blooming_convert** (1 GIF: blooming_convert_death)
  - Death installer: bipeds scale by a central-band body height (a raised hand/weapon in frame 0 no longer shrinks the body); the sixteen biped deaths re-installed, frame-0 ...
  - Death clips batch 2: blooming_convert, choir_pilgrim, elf_wild, ragged_soldier, ridge_deserter, vale_mourner (27 death clips total from the lane); board 10
- **mobs/bog_lurker** (2 GIFs: bog_lurker_death, bog_lurker_walk)
  - Death clips (first eight): wolf, winterfang, blightwolf, duneprowler, deep_stalker, casket_creeper, vent_skitter, bog_lurker -- 6-frame collapses from the death lane ...
  - Idle-to-walk seam fixes: 14 walks tone-matched to their idles, the four hounds reseated to idle body size, seven walks centred on their idle (rat_mage was 19% of the ...
  - Corpus seam sweep + fix-up batch installs
  - Wave 3: 16 placed mob/boss walks regenerated (mummy S/E/N, mummy_mage S/E/N, skeleton_warrior E/N, rat_mage, flux_hound, rime_wolf, slag_hound, void_hound, fangmaw, ...
  - Green keying-ring sweep (63 sprites) + orphan frame edits + the QA findings board
- **mobs/broodmother_yskara** (1 GIF: broodmother_yskara_anim)
  - Corpus seam sweep + fix-up batch installs
- **mobs/burned_kings_echo** (2 GIFs: burned_kings_echo_anim, burned_kings_echo_walk)
  - Corpus seam sweep + fix-up batch installs
- **mobs/casket_creeper** (2 GIFs: casket_creeper_death, casket_creeper_walk)
  - Death clips (first eight): wolf, winterfang, blightwolf, duneprowler, deep_stalker, casket_creeper, vent_skitter, bog_lurker -- 6-frame collapses from the death lane ...
  - Audit B fixes (quad/creature mobs + boss facings, each re-checked by hand) + mage attack_walk_b S/E
  - Art wave 2: 11 more mob walks, 12 boss walk facings, the 26-piece capital repaint, and fire-on-move for the base classes
  - Green keying-ring sweep (63 sprites) + orphan frame edits + the QA findings board
- **mobs/choir_ascendant** (2 GIFs: choir_ascendant_anim, choir_ascendant_walk)
  - Corpus seam sweep + fix-up batch installs
- **mobs/choir_of_frost** (2 GIFs: choir_of_frost_anim, choir_of_frost_walk)
  - Corpus seam sweep + fix-up batch installs
- **mobs/choir_radical** (2 GIFs: choir_radical_anim, choir_radical_walk)
  - Corpus seam sweep + fix-up batch installs
- **mobs/chorister_of_frost** (2 GIFs: chorister_of_frost_anim, chorister_of_frost_walk)
  - Corpus seam sweep + fix-up batch installs
- **mobs/cindersmith** (1 GIF: cindersmith_anim)
  - Corpus seam sweep + fix-up batch installs
- **mobs/cistern_mimic** (2 GIFs: cistern_mimic_anim, cistern_mimic_walk)
  - Corpus seam sweep + fix-up batch installs
- **mobs/cold_pilgrim** (4 GIFs: cold_pilgrim_anim, cold_pilgrim_attack, cold_pilgrim_death, cold_pilgrim_walk)
  - Death installer: bipeds scale by a central-band body height (a raised hand/weapon in frame 0 no longer shrinks the body); the sixteen biped deaths re-installed, frame-0 ...
  - Death clips for the remaining 13 placed mobs (cultist, mummy_rogue/warrior, rat_rogue/warrior, zombie_overweight, greyrun_lurker, grove_horror, fungus_immature, spider, ...
  - Idle-to-walk seam fixes: 14 walks tone-matched to their idles, the four hounds reseated to idle body size, seven walks centred on their idle (rat_mage was 19% of the ...
  - Green keying-ring sweep (63 sprites) + orphan frame edits + the QA findings board
- **mobs/commander_drayce** (2 GIFs: commander_drayce_anim, commander_drayce_walk)
  - Corpus seam sweep + fix-up batch installs
- **mobs/conductor_acolyte** (2 GIFs: conductor_acolyte_anim, conductor_acolyte_walk)
  - Corpus seam sweep + fix-up batch installs
- **mobs/converted** (2 GIFs: converted_anim, converted_walk)
  - Corpus seam sweep + fix-up batch installs
- **mobs/crusade_zealot** (2 GIFs: crusade_zealot_anim, crusade_zealot_walk)
  - Corpus seam sweep + fix-up batch installs
- **mobs/cultist** (3 GIFs: cultist_anim, cultist_death, cultist_walk)
  - Death installer: bipeds scale by a central-band body height (a raised hand/weapon in frame 0 no longer shrinks the body); the sixteen biped deaths re-installed, frame-0 ...
  - Death clips for the remaining 13 placed mobs (cultist, mummy_rogue/warrior, rat_rogue/warrior, zombie_overweight, greyrun_lurker, grove_horror, fungus_immature, spider, ...
  - Corpus seam sweep + fix-up batch installs
  - Art wave 2: 11 more mob walks, 12 boss walk facings, the 26-piece capital repaint, and fire-on-move for the base classes
  - Green keying-ring sweep (63 sprites) + orphan frame edits + the QA findings board
- **mobs/cure_seeker_heretic** (1 GIF: cure_seeker_heretic_anim)
  - Corpus seam sweep + fix-up batch installs
- **mobs/deep_stalker** (2 GIFs: deep_stalker_death, deep_stalker_walk)
  - Death clips (first eight): wolf, winterfang, blightwolf, duneprowler, deep_stalker, casket_creeper, vent_skitter, bog_lurker -- 6-frame collapses from the death lane ...
  - Audit B fixes (quad/creature mobs + boss facings, each re-checked by hand) + mage attack_walk_b S/E
  - Mob walks wave 1: seven creatures regenerated as real gaits (gait-transfer lane)
  - Green keying-ring sweep (63 sprites) + orphan frame edits + the QA findings board
- **mobs/drowned_warden** (2 GIFs: drowned_warden_anim, drowned_warden_walk)
  - Corpus seam sweep + fix-up batch installs
- **mobs/duneprowler** (3 GIFs: duneprowler_attack, duneprowler_death, duneprowler_walk)
  - Death clips (first eight): wolf, winterfang, blightwolf, duneprowler, deep_stalker, casket_creeper, vent_skitter, bog_lurker -- 6-frame collapses from the death lane ...
  - Mob walks wave 1: seven creatures regenerated as real gaits (gait-transfer lane)
  - Green keying-ring sweep (63 sprites) + orphan frame edits + the QA findings board
- **mobs/elara_vessel** (2 GIFs: elara_vessel_anim, elara_vessel_walk)
  - Corpus seam sweep + fix-up batch installs
- **mobs/elf_druid** (2 GIFs: elf_druid_walk, elf_druid_walk_n)
  - Corpus seam sweep + fix-up batch installs
  - Wave 5: the seven scissoring bipeds re-rolled with crossing-hardened briefs (elf_ranger, royal_knight, skeleton, zombie, elf_druid, skeleton_rogue, bandit_scout) -- ...
  - Green keying-ring sweep (63 sprites) + orphan frame edits + the QA findings board
- **mobs/elf_ranger** (2 GIFs: elf_ranger_attack, elf_ranger_walk)
  - Idle-to-walk seam fixes: 14 walks tone-matched to their idles, the four hounds reseated to idle body size, seven walks centred on their idle (rat_mage was 19% of the ...
  - Wave 5: the seven scissoring bipeds re-rolled with crossing-hardened briefs (elf_ranger, royal_knight, skeleton, zombie, elf_druid, skeleton_rogue, bandit_scout) -- ...
  - elf_ranger attack f2: erase the baked in-flight arrow (the game spawns one -> it doubled); board: gates + open list
  - Green keying-ring sweep (63 sprites) + orphan frame edits + the QA findings board
- **mobs/elf_wild** (1 GIF: elf_wild_death)
  - Death clips batch 2: blooming_convert, choir_pilgrim, elf_wild, ragged_soldier, ridge_deserter, vale_mourner (27 death clips total from the lane); board 10
- **mobs/field_chirurgeon** (2 GIFs: field_chirurgeon_anim, field_chirurgeon_walk)
  - Corpus seam sweep + fix-up batch installs
- **mobs/flame_pilgrim** (1 GIF: flame_pilgrim_death)
  - Death installer: bipeds scale by a central-band body height (a raised hand/weapon in frame 0 no longer shrinks the body); the sixteen biped deaths re-installed, frame-0 ...
  - Death clips for the remaining 13 placed mobs (cultist, mummy_rogue/warrior, rat_rogue/warrior, zombie_overweight, greyrun_lurker, grove_horror, fungus_immature, spider, ...
- **mobs/flux_hound** (2 GIFs: flux_hound_anim, flux_hound_walk)
  - Idle-to-walk seam fixes: 14 walks tone-matched to their idles, the four hounds reseated to idle body size, seven walks centred on their idle (rat_mage was 19% of the ...
  - Corpus seam sweep + fix-up batch installs
  - Wave 3: 16 placed mob/boss walks regenerated (mummy S/E/N, mummy_mage S/E/N, skeleton_warrior E/N, rat_mage, flux_hound, rime_wolf, slag_hound, void_hound, fangmaw, ...
- **mobs/forge_zealot** (2 GIFs: forge_zealot_anim, forge_zealot_walk)
  - Corpus seam sweep + fix-up batch installs
- **mobs/foundry_thrall** (2 GIFs: foundry_thrall_anim, foundry_thrall_walk)
  - Corpus seam sweep + fix-up batch installs
- **mobs/fungus_heavy** (2 GIFs: fungus_heavy_walk_n, fungus_heavy_walk_s)
  - Art wave 2: 11 more mob walks, 12 boss walk facings, the 26-piece capital repaint, and fire-on-move for the base classes
  - Green keying-ring sweep (63 sprites) + orphan frame edits + the QA findings board
- **mobs/fungus_immature** (2 GIFs: fungus_immature_death, fungus_immature_walk)
  - Death clips for the remaining 13 placed mobs (cultist, mummy_rogue/warrior, rat_rogue/warrior, zombie_overweight, greyrun_lurker, grove_horror, fungus_immature, spider, ...
  - Idle-to-walk seam fixes: 14 walks tone-matched to their idles, the four hounds reseated to idle body size, seven walks centred on their idle (rat_mage was 19% of the ...
- **mobs/fungus_long** (5 GIFs: fungus_long_walk, fungus_long_walk_e, fungus_long_walk_n, fungus_long_walk_nw, fungus_long_walk_s)
  - Audit B fixes (quad/creature mobs + boss facings, each re-checked by hand) + mage attack_walk_b S/E
  - Mob walks wave 1: seven creatures regenerated as real gaits (gait-transfer lane)
  - Green keying-ring sweep (63 sprites) + orphan frame edits + the QA findings board
- **mobs/glasshide_stalker** (2 GIFs: glasshide_stalker_anim, glasshide_stalker_walk)
  - Corpus seam sweep + fix-up batch installs
- **mobs/greyrun_lurker** (2 GIFs: greyrun_lurker_anim, greyrun_lurker_death)
  - Death clips for the remaining 13 placed mobs (cultist, mummy_rogue/warrior, rat_rogue/warrior, zombie_overweight, greyrun_lurker, grove_horror, fungus_immature, spider, ...
  - Corpus seam sweep + fix-up batch installs
- **mobs/grove_horror** (3 GIFs: grove_horror_anim, grove_horror_death, grove_horror_walk)
  - Death clips for the remaining 13 placed mobs (cultist, mummy_rogue/warrior, rat_rogue/warrior, zombie_overweight, greyrun_lurker, grove_horror, fungus_immature, spider, ...
  - Corpus seam sweep + fix-up batch installs
- **mobs/grove_tender** (2 GIFs: grove_tender_anim, grove_tender_walk)
  - Corpus seam sweep + fix-up batch installs
- **mobs/heart_of_the_root** (2 GIFs: heart_of_the_root_anim, heart_of_the_root_walk)
  - Idle-to-walk seam fixes: 14 walks tone-matched to their idles, the four hounds reseated to idle body size, seven walks centred on their idle (rat_mage was 19% of the ...
  - Corpus seam sweep + fix-up batch installs
- **mobs/high_artificer_maeven** (2 GIFs: high_artificer_maeven_anim, high_artificer_maeven_walk)
  - Corpus seam sweep + fix-up batch installs
- **mobs/hollow_knight** (2 GIFs: hollow_knight_anim, hollow_knight_walk)
  - Corpus seam sweep + fix-up batch installs
- **mobs/korrag_reborn** (2 GIFs: korrag_reborn_anim, korrag_reborn_walk)
  - Corpus seam sweep + fix-up batch installs
- **mobs/morwyn_hollow_flame** (2 GIFs: morwyn_hollow_flame_anim, morwyn_hollow_flame_walk)
  - Corpus seam sweep + fix-up batch installs
- **mobs/mouth_of_the_storm** (1 GIF: mouth_of_the_storm_anim)
  - Corpus seam sweep + fix-up batch installs
- **mobs/mummy** (4 GIFs: mummy_walk, mummy_walk_e, mummy_walk_n, mummy_walk_nw)
  - Wave 3: 16 placed mob/boss walks regenerated (mummy S/E/N, mummy_mage S/E/N, skeleton_warrior E/N, rat_mage, flux_hound, rime_wolf, slag_hound, void_hound, fangmaw, ...
- **mobs/mummy_mage** (6 GIFs: mummy_mage_walk, mummy_mage_walk_e, mummy_mage_walk_n, mummy_mage_walk_ne, mummy_mage_walk_nw, mummy_mage_walk_s)
  - Wave 3: 16 placed mob/boss walks regenerated (mummy S/E/N, mummy_mage S/E/N, skeleton_warrior E/N, rat_mage, flux_hound, rime_wolf, slag_hound, void_hound, fangmaw, ...
- **mobs/mummy_rogue** (1 GIF: mummy_rogue_death)
  - Death installer: bipeds scale by a central-band body height (a raised hand/weapon in frame 0 no longer shrinks the body); the sixteen biped deaths re-installed, frame-0 ...
  - Death clips for the remaining 13 placed mobs (cultist, mummy_rogue/warrior, rat_rogue/warrior, zombie_overweight, greyrun_lurker, grove_horror, fungus_immature, spider, ...
- **mobs/mummy_warrior** (1 GIF: mummy_warrior_death)
  - Death installer: bipeds scale by a central-band body height (a raised hand/weapon in frame 0 no longer shrinks the body); the sixteen biped deaths re-installed, frame-0 ...
  - Death installer: 2-D component slicing (touching figures split at the thinnest column, specks dropped); the five strips the equal-width slice had cut re-installed whole
  - Death clips for the remaining 13 placed mobs (cultist, mummy_rogue/warrior, rat_rogue/warrior, zombie_overweight, greyrun_lurker, grove_horror, fungus_immature, spider, ...
- **mobs/oathbound_knight** (2 GIFs: oathbound_knight_anim, oathbound_knight_walk)
  - Corpus seam sweep + fix-up batch installs
- **mobs/orc** (3 GIFs: orc_attack, orc_walk_n, orc_walk_s)
  - Corpus seam sweep + fix-up batch installs
  - Green keying-ring sweep (63 sprites) + orphan frame edits + the QA findings board
- **mobs/orc_rogue** (1 GIF: orc_rogue_walk)
  - Idle-to-walk seam fixes: 14 walks tone-matched to their idles, the four hounds reseated to idle body size, seven walks centred on their idle (rat_mage was 19% of the ...
  - Install orc_rogue + skeleton_rogue gaits; tighten the row brief against size drift
- **mobs/overgrown_gatewarden** (2 GIFs: overgrown_gatewarden_anim, overgrown_gatewarden_walk)
  - Corpus seam sweep + fix-up batch installs
- **mobs/pale_nursery** (1 GIF: pale_nursery_anim)
  - Corpus seam sweep + fix-up batch installs
- **mobs/pollen_drifter** (1 GIF: pollen_drifter_anim)
  - Corpus seam sweep + fix-up batch installs
- **mobs/ragged_soldier** (1 GIF: ragged_soldier_death)
  - Death installer: bipeds scale by a central-band body height (a raised hand/weapon in frame 0 no longer shrinks the body); the sixteen biped deaths re-installed, frame-0 ...
  - Death clips batch 2: blooming_convert, choir_pilgrim, elf_wild, ragged_soldier, ridge_deserter, vale_mourner (27 death clips total from the lane); board 10
- **mobs/rat_mage** (2 GIFs: rat_mage_anim, rat_mage_walk)
  - Idle-to-walk seam fixes: 14 walks tone-matched to their idles, the four hounds reseated to idle body size, seven walks centred on their idle (rat_mage was 19% of the ...
  - Wave 3: 16 placed mob/boss walks regenerated (mummy S/E/N, mummy_mage S/E/N, skeleton_warrior E/N, rat_mage, flux_hound, rime_wolf, slag_hound, void_hound, fangmaw, ...
  - Green keying-ring sweep (63 sprites) + orphan frame edits + the QA findings board
- **mobs/rat_rogue** (1 GIF: rat_rogue_death)
  - Death installer: bipeds scale by a central-band body height (a raised hand/weapon in frame 0 no longer shrinks the body); the sixteen biped deaths re-installed, frame-0 ...
  - Death installer: 2-D component slicing (touching figures split at the thinnest column, specks dropped); the five strips the equal-width slice had cut re-installed whole
  - Death clips for the remaining 13 placed mobs (cultist, mummy_rogue/warrior, rat_rogue/warrior, zombie_overweight, greyrun_lurker, grove_horror, fungus_immature, spider, ...
- **mobs/rat_warrior** (1 GIF: rat_warrior_death)
  - Death installer: bipeds scale by a central-band body height (a raised hand/weapon in frame 0 no longer shrinks the body); the sixteen biped deaths re-installed, frame-0 ...
  - Death installer: 2-D component slicing (touching figures split at the thinnest column, specks dropped); the five strips the equal-width slice had cut re-installed whole
  - Death clips for the remaining 13 placed mobs (cultist, mummy_rogue/warrior, rat_rogue/warrior, zombie_overweight, greyrun_lurker, grove_horror, fungus_immature, spider, ...
- **mobs/ridge_deserter** (1 GIF: ridge_deserter_death)
  - Death installer: bipeds scale by a central-band body height (a raised hand/weapon in frame 0 no longer shrinks the body); the sixteen biped deaths re-installed, frame-0 ...
  - Death clips batch 2: blooming_convert, choir_pilgrim, elf_wild, ragged_soldier, ridge_deserter, vale_mourner (27 death clips total from the lane); board 10
- **mobs/riftling** (2 GIFs: riftling_anim, riftling_walk)
  - Corpus seam sweep + fix-up batch installs
- **mobs/rime_wolf** (2 GIFs: rime_wolf_anim, rime_wolf_walk)
  - Idle-to-walk seam fixes: 14 walks tone-matched to their idles, the four hounds reseated to idle body size, seven walks centred on their idle (rat_mage was 19% of the ...
  - Corpus seam sweep + fix-up batch installs
  - Wave 3: 16 placed mob/boss walks regenerated (mummy S/E/N, mummy_mage S/E/N, skeleton_warrior E/N, rat_mage, flux_hound, rime_wolf, slag_hound, void_hound, fangmaw, ...
- **mobs/root_spiderling** (2 GIFs: root_spiderling_anim, root_spiderling_walk)
  - Corpus seam sweep + fix-up batch installs
  - Wave 3: 16 placed mob/boss walks regenerated (mummy S/E/N, mummy_mage S/E/N, skeleton_warrior E/N, rat_mage, flux_hound, rime_wolf, slag_hound, void_hound, fangmaw, ...
- **mobs/rootspawn** (2 GIFs: rootspawn_anim, rootspawn_walk)
  - Corpus seam sweep + fix-up batch installs
- **mobs/rootweaver** (2 GIFs: rootweaver_anim, rootweaver_walk)
  - Corpus seam sweep + fix-up batch installs
- **mobs/royal_knight** (3 GIFs: royal_knight_walk, royal_knight_walk_n, royal_knight_walk_s)
  - Idle-to-walk seam fixes: 14 walks tone-matched to their idles, the four hounds reseated to idle body size, seven walks centred on their idle (rat_mage was 19% of the ...
  - Corpus seam sweep + fix-up batch installs
  - Wave 5: the seven scissoring bipeds re-rolled with crossing-hardened briefs (elf_ranger, royal_knight, skeleton, zombie, elf_druid, skeleton_rogue, bandit_scout) -- ...
  - Audit A fixes: vow_sentinel's warhammer vanished in f2/f5 (filled from the neighbour frames); bandit_scout walk tone-matched to its idle (was 30% brighter); royal_knight ...
  - Green keying-ring sweep (63 sprites) + orphan frame edits + the QA findings board
- **mobs/sand_revenant** (2 GIFs: sand_revenant_anim, sand_revenant_walk)
  - Corpus seam sweep + fix-up batch installs
- **mobs/shardcaller** (2 GIFs: shardcaller_anim, shardcaller_walk)
  - Corpus seam sweep + fix-up batch installs
- **mobs/shattered_vow** (2 GIFs: shattered_vow_anim, shattered_vow_walk)
  - Corpus seam sweep + fix-up batch installs
- **mobs/skeleton** (2 GIFs: skeleton_attack, skeleton_walk)
  - Idle-to-walk seam fixes: 14 walks tone-matched to their idles, the four hounds reseated to idle body size, seven walks centred on their idle (rat_mage was 19% of the ...
  - Wave 5: the seven scissoring bipeds re-rolled with crossing-hardened briefs (elf_ranger, royal_knight, skeleton, zombie, elf_druid, skeleton_rogue, bandit_scout) -- ...
  - korrag E (with his lightning), skeleton (without the invented shield), veyx E (with his bulk)
  - Green keying-ring sweep (63 sprites) + orphan frame edits + the QA findings board
- **mobs/skeleton_mage** (1 GIF: skeleton_mage_walk)
  - Idle-to-walk seam fixes: 14 walks tone-matched to their idles, the four hounds reseated to idle body size, seven walks centred on their idle (rat_mage was 19% of the ...
- **mobs/skeleton_rogue** (2 GIFs: skeleton_rogue_walk, skeleton_rogue_walk_n)
  - Corpus seam sweep + fix-up batch installs
  - Wave 5: the seven scissoring bipeds re-rolled with crossing-hardened briefs (elf_ranger, royal_knight, skeleton, zombie, elf_druid, skeleton_rogue, bandit_scout) -- ...
  - Install orc_rogue + skeleton_rogue gaits; tighten the row brief against size drift
- **mobs/skeleton_warrior** (5 GIFs: skeleton_warrior_walk, skeleton_warrior_walk_e, skeleton_warrior_walk_n, skeleton_warrior_walk_nw, skeleton_warrior_walk_s)
  - nullwarden idle: the recentre pass had emptied its last frame (1px of alpha) -- restored to the centred pre-recentre version; bog_lurker/cinderhide/skeleton_warrior S ...
  - Idle-to-walk seam fixes: 14 walks tone-matched to their idles, the four hounds reseated to idle body size, seven walks centred on their idle (rat_mage was 19% of the ...
  - cinderhide walk: 6-frame three-headed trot from a two-row grid (was 4 stiff poses); skeleton_warrior S walk (+flat) from the re-run fix-up job
  - Wave 3: 16 placed mob/boss walks regenerated (mummy S/E/N, mummy_mage S/E/N, skeleton_warrior E/N, rat_mage, flux_hound, rime_wolf, slag_hound, void_hound, fangmaw, ...
- **mobs/slag_hound** (2 GIFs: slag_hound_anim, slag_hound_walk)
  - Idle-to-walk seam fixes: 14 walks tone-matched to their idles, the four hounds reseated to idle body size, seven walks centred on their idle (rat_mage was 19% of the ...
  - Corpus seam sweep + fix-up batch installs
  - Wave 3: 16 placed mob/boss walks regenerated (mummy S/E/N, mummy_mage S/E/N, skeleton_warrior E/N, rat_mage, flux_hound, rime_wolf, slag_hound, void_hound, fangmaw, ...
- **mobs/sleepwalker** (2 GIFs: sleepwalker_anim, sleepwalker_walk)
  - Corpus seam sweep + fix-up batch installs
- **mobs/sluice_lurker** (2 GIFs: sluice_lurker_anim, sluice_lurker_walk)
  - Corpus seam sweep + fix-up batch installs
- **mobs/spider** (11 GIFs: spider_attack, spider_death, spider_walk, spider_walk_e, spider_walk_n, spider_walk_ne, spider_walk_nw, spider_walk_s, spider_walk_se, spider_walk_sw, spider_walk_w)
  - Death installer: 2-D component slicing (touching figures split at the thinnest column, specks dropped); the five strips the equal-width slice had cut re-installed whole
  - Death clips for the remaining 13 placed mobs (cultist, mummy_rogue/warrior, rat_rogue/warrior, zombie_overweight, greyrun_lurker, grove_horror, fungus_immature, spider, ...
  - Corpus seam sweep + fix-up batch installs
  - Green keying-ring sweep (63 sprites) + orphan frame edits + the QA findings board
- **mobs/static_caller** (1 GIF: static_caller_walk)
  - Idle-to-walk seam fixes: 14 walks tone-matched to their idles, the four hounds reseated to idle body size, seven walks centred on their idle (rat_mage was 19% of the ...
- **mobs/stone_base** (4 GIFs: stone_base_walk_e, stone_base_walk_n, stone_base_walk_nw, stone_base_walk_s)
  - Audit B fixes (quad/creature mobs + boss facings, each re-checked by hand) + mage attack_walk_b S/E
  - Art wave 2: 11 more mob walks, 12 boss walk facings, the 26-piece capital repaint, and fire-on-move for the base classes
- **mobs/stone_broken** (2 GIFs: stone_broken_walk, stone_broken_walk_s)
  - Idle-to-walk seam fixes: 14 walks tone-matched to their idles, the four hounds reseated to idle body size, seven walks centred on their idle (rat_mage was 19% of the ...
  - Corpus seam sweep + fix-up batch installs
  - Art wave 2: 11 more mob walks, 12 boss walk facings, the 26-piece capital repaint, and fire-on-move for the base classes
- **mobs/storm_adept** (2 GIFs: storm_adept_anim, storm_adept_walk)
  - Corpus seam sweep + fix-up batch installs
- **mobs/storm_harrier** (2 GIFs: storm_harrier_attack, storm_harrier_walk)
  - Art wave 2: 11 more mob walks, 12 boss walk facings, the 26-piece capital repaint, and fire-on-move for the base classes
  - Green keying-ring sweep (63 sprites) + orphan frame edits + the QA findings board
- **mobs/stormcult** (4 GIFs: stormcult, stormcult_anim, stormcult_attack, stormcult_death)
  - Death installer: bipeds scale by a central-band body height (a raised hand/weapon in frame 0 no longer shrinks the body); the sixteen biped deaths re-installed, frame-0 ...
  - Death clips for the remaining 13 placed mobs (cultist, mummy_rogue/warrior, rat_rogue/warrior, zombie_overweight, greyrun_lurker, grove_horror, fungus_immature, spider, ...
  - Corpus seam sweep + fix-up batch installs
  - Green keying-ring sweep (63 sprites) + orphan frame edits + the QA findings board
- **mobs/thorn_howler** (2 GIFs: thorn_howler_anim, thorn_howler_walk)
  - Corpus seam sweep + fix-up batch installs
- **mobs/unfinished_sentence** (2 GIFs: unfinished_sentence_anim, unfinished_sentence_walk)
  - Corpus seam sweep + fix-up batch installs
- **mobs/vale_mourner** (3 GIFs: vale_mourner, vale_mourner_anim, vale_mourner_death)
  - Death installer: bipeds scale by a central-band body height (a raised hand/weapon in frame 0 no longer shrinks the body); the sixteen biped deaths re-installed, frame-0 ...
  - Death clips batch 2: blooming_convert, choir_pilgrim, elf_wild, ragged_soldier, ridge_deserter, vale_mourner (27 death clips total from the lane); board 10
  - Corpus seam sweep + fix-up batch installs
  - Green keying-ring sweep (63 sprites) + orphan frame edits + the QA findings board
- **mobs/vent_skitter** (2 GIFs: vent_skitter_death, vent_skitter_walk)
  - Death clips (first eight): wolf, winterfang, blightwolf, duneprowler, deep_stalker, casket_creeper, vent_skitter, bog_lurker -- 6-frame collapses from the death lane ...
  - Audit B fixes (quad/creature mobs + boss facings, each re-checked by hand) + mage attack_walk_b S/E
  - Art wave 2: 11 more mob walks, 12 boss walk facings, the 26-piece capital repaint, and fire-on-move for the base classes
  - Green keying-ring sweep (63 sprites) + orphan frame edits + the QA findings board
- **mobs/verdant_anvil** (1 GIF: verdant_anvil_anim)
  - Corpus seam sweep + fix-up batch installs
- **mobs/verdict_drone** (2 GIFs: verdict_drone_anim, verdict_drone_walk)
  - Corpus seam sweep + fix-up batch installs
- **mobs/void_hound** (2 GIFs: void_hound_anim, void_hound_walk)
  - Idle-to-walk seam fixes: 14 walks tone-matched to their idles, the four hounds reseated to idle body size, seven walks centred on their idle (rat_mage was 19% of the ...
  - Corpus seam sweep + fix-up batch installs
  - Wave 3: 16 placed mob/boss walks regenerated (mummy S/E/N, mummy_mage S/E/N, skeleton_warrior E/N, rat_mage, flux_hound, rime_wolf, slag_hound, void_hound, fangmaw, ...
- **mobs/vow_sentinel** (1 GIF: vow_sentinel_walk)
  - Idle-to-walk seam fixes: 14 walks tone-matched to their idles, the four hounds reseated to idle body size, seven walks centred on their idle (rat_mage was 19% of the ...
  - Audit A fixes: vow_sentinel's warhammer vanished in f2/f5 (filled from the neighbour frames); bandit_scout walk tone-matched to its idle (was 30% brighter); royal_knight ...
  - Art wave 2: 11 more mob walks, 12 boss walk facings, the 26-piece capital repaint, and fire-on-move for the base classes
- **mobs/waking_shard** (2 GIFs: waking_shard_anim, waking_shard_walk)
  - Corpus seam sweep + fix-up batch installs
- **mobs/winterfang** (2 GIFs: winterfang_death, winterfang_walk)
  - Death clips (first eight): wolf, winterfang, blightwolf, duneprowler, deep_stalker, casket_creeper, vent_skitter, bog_lurker -- 6-frame collapses from the death lane ...
  - Art wave 2: 11 more mob walks, 12 boss walk facings, the 26-piece capital repaint, and fire-on-move for the base classes
- **mobs/wolf** (2 GIFs: wolf_death, wolf_walk)
  - Death clips (first eight): wolf, winterfang, blightwolf, duneprowler, deep_stalker, casket_creeper, vent_skitter, bog_lurker -- 6-frame collapses from the death lane ...
  - Art wave 2: 11 more mob walks, 12 boss walk facings, the 26-piece capital repaint, and fire-on-move for the base classes
  - Green keying-ring sweep (63 sprites) + orphan frame edits + the QA findings board
- **mobs/word_wisp** (1 GIF: word_wisp_anim)
  - Corpus seam sweep + fix-up batch installs
- **mobs/zombie** (2 GIFs: zombie_attack, zombie_walk)
  - Wave 5: the seven scissoring bipeds re-rolled with crossing-hardened briefs (elf_ranger, royal_knight, skeleton, zombie, elf_druid, skeleton_rogue, bandit_scout) -- ...
  - Art wave 2: 11 more mob walks, 12 boss walk facings, the 26-piece capital repaint, and fire-on-move for the base classes
  - Green keying-ring sweep (63 sprites) + orphan frame edits + the QA findings board
- **mobs/zombie_overweight** (1 GIF: zombie_overweight_death)
  - Death installer: bipeds scale by a central-band body height (a raised hand/weapon in frame 0 no longer shrinks the body); the sixteen biped deaths re-installed, frame-0 ...
  - Death installer: 2-D component slicing (touching figures split at the thinnest column, specks dropped); the five strips the equal-width slice had cut re-installed whole
  - Death clips for the remaining 13 placed mobs (cultist, mummy_rogue/warrior, rat_rogue/warrior, zombie_overweight, greyrun_lurker, grove_horror, fungus_immature, spider, ...
- **npcs/choir_pilgrim** (1 GIF: choir_pilgrim_death)
  - Death installer: bipeds scale by a central-band body height (a raised hand/weapon in frame 0 no longer shrinks the body); the sixteen biped deaths re-installed, frame-0 ...
  - Death clips batch 2: blooming_convert, choir_pilgrim, elf_wild, ragged_soldier, ridge_deserter, vale_mourner (27 death clips total from the lane); board 10
- **npcs/npc_bandit_tracker** (1 GIF: npc_bandit_tracker)
  - Green keying-ring sweep (63 sprites) + orphan frame edits + the QA findings board
- **npcs/npc_scholar_a** (1 GIF: npc_scholar_a)
  - Green keying-ring sweep (63 sprites) + orphan frame edits + the QA findings board
- **npcs/npc_scholar_b** (1 GIF: npc_scholar_b)
  - Green keying-ring sweep (63 sprites) + orphan frame edits + the QA findings board
- **npcs/npc_villager_f** (1 GIF: npc_villager_f)
  - Green keying-ring sweep (63 sprites) + orphan frame edits + the QA findings board
- **npcs/npc_villager_m** (1 GIF: npc_villager_m)
  - Green keying-ring sweep (63 sprites) + orphan frame edits + the QA findings board
- **npcs/villager** (1 GIF: villager)
  - Green keying-ring sweep (63 sprites) + orphan frame edits + the QA findings board
- **capital/capital** (42 GIFs: capital_accord_longhouse, capital_accord_longhouse_anim, capital_alembic_station, capital_ashen_tankard, capital_ashen_tankard_anim, capital_ashfire_forge, capital_ashfire_forge_anim, capital_chartered_hall, capital_city_arcade, capital_city_bench, capital_city_directory, capital_crown_fountain, capital_crown_fountain_anim, capital_crown_spire_gate, capital_crown_spire_gate_anim, capital_emberward_gate, capital_emberward_gate_anim, capital_grand_archive, capital_great_hearth, capital_great_hearth_anim, capital_market_stall, capital_portal_crucible, capital_portal_crucible_anim, capital_portal_depths, capital_portal_depths_anim, capital_portal_story, capital_portal_story_anim, capital_proving_gate, capital_proving_gate_anim, capital_rot_chapel, capital_sable_hall, capital_sable_hall_anim, capital_stables, capital_undercroft, capital_vault_chest, capital_watchtower, capital_watchtower_anim, capital_wellspring, capital_wellspring_anim, capital_wildfang_fangmoot, capital_wildfang_fangmoot_anim, ground_field_holystone)
  - Art wave 2: 11 more mob walks, 12 boss walk facings, the 26-piece capital repaint, and fire-on-move for the base classes
  - The capital's real value problem was the FLOOR, not the buildings
  - Capital: light sockets on every flame, portal strobe fix, room-tour rig fix (CAP-6/3/10a)
- **props/bridge** (1 GIF: bridge)
  - Green keying-ring sweep (63 sprites) + orphan frame edits + the QA findings board
- **props/cactus2** (1 GIF: cactus2)
  - Palette-grade the world's style outliers back into the house palette
- **props/grass2** (1 GIF: grass2)
  - Palette-grade the world's style outliers back into the house palette
- **props/grass3** (1 GIF: grass3)
  - Palette-grade the world's style outliers back into the house palette
- **props/mushroom2** (1 GIF: mushroom2)
  - Palette-grade the world's style outliers back into the house palette
- **props/mushroom3** (1 GIF: mushroom3)
  - Palette-grade the world's style outliers back into the house palette
- **props/toadstool** (1 GIF: toadstool)
  - Palette-grade the world's style outliers back into the house palette
- **props/tree_green2** (2 GIFs: tree_green2, tree_green2_anim)
  - Palette-grade the world's style outliers back into the house palette
- **props/tree_green4** (2 GIFs: tree_green4, tree_green4_anim)
  - Palette-grade the world's style outliers back into the house palette

## Appendix B. Recentre drift table

Max per-frame feet-anchor offset removed by `recenter_strip.py --apply` (px, in the strip's
own cell). Every file listed was off its frame grid; the figure slid by this much across the
loop.

**Idles (68)**

| idle strip | drift px |
|---|---:|
| nullwarden_anim_codex.png | 124 |
| storm_adept_anim.png | 64 |
| archon_vassik_anim.png | 56 |
| bannerman_anim.png | 56 |
| burned_kings_echo_anim.png | 56 |
| greyrun_lurker_anim.png | 55 |
| verdict_drone_anim.png | 55 |
| chorister_of_frost_anim.png | 51 |
| hollow_knight_anim.png | 49 |
| elara_vessel_anim.png | 48 |
| foundry_thrall_anim.png | 48 |
| pollen_drifter_anim.png | 48 |
| unfinished_sentence_anim.png | 47 |
| drowned_warden_anim.png | 46 |
| sand_revenant_anim.png | 43 |
| high_artificer_maeven_anim.png | 42 |
| conductor_acolyte_anim.png | 41 |
| heart_of_the_root_anim.png | 41 |
| rootweaver_anim.png | 41 |
| smelter_lord_thrain_anim.png | 41 |
| sleepwalker_anim.png | 40 |
| waking_shard_anim.png | 40 |
| converted_anim.png | 39 |
| glacius_anim.png | 39 |
| oathbound_knight_anim.png | 39 |
| rootspawn_anim.png | 39 |
| choir_radical_anim.png | 38 |
| field_chirurgeon_anim.png | 38 |
| slag_hound_anim.png | 38 |
| thornfather_grael_anim.png | 38 |
| flux_hound_anim.png | 37 |
| morwyn_hollow_flame_anim.png | 37 |
| crusade_zealot_anim.png | 36 |
| overgrown_gatewarden_anim.png | 36 |
| choir_ascendant_anim.png | 35 |
| aldric_burned_out_anim.png | 34 |
| riftling_anim.png | 34 |
| shattered_vow_anim.png | 34 |
| bellows_imp_anim.png | 33 |
| bloat_leech_anim.png | 33 |
| commander_drayce_anim.png | 33 |
| rime_wolf_anim.png | 33 |
| void_hound_anim.png | 32 |
| cure_seeker_heretic_anim.png | 31 |
| korrag_reborn_anim.png | 31 |
| choir_of_frost_anim.png | 30 |
| forge_zealot_anim.png | 30 |
| sluice_lurker_anim.png | 30 |
| cistern_mimic_anim.png | 29 |
| grove_tender_anim.png | 28 |
| root_spiderling_anim.png | 28 |
| pale_nursery_anim.png | 26 |
| cindersmith_anim.png | 25 |
| thorn_howler_anim.png | 25 |
| verdant_anvil_anim.png | 24 |
| anchor_vine_anim.png | 23 |
| glasshide_stalker_anim.png | 22 |
| shardcaller_anim.png | 22 |
| mouth_of_the_storm_anim.png | 19 |
| word_wisp_anim.png | 15 |
| cultist_anim.png | 14 |
| broodmother_yskara_anim.png | 13 |
| fangmaw_anim_codex.png | 12 |
| grove_horror_anim.png | 11 |
| halla_anim_codex.png | 10 |
| vale_mourner_anim.png | 10 |
| vargoth_anim_codex.png | 10 |
| stormcult_anim.png | 9 |

**Legacy walks (97 applied; the table lists the 111 measured, the 14 gait-lane walks were restored)**

| legacy walk strip | drift px |
|---|---:|
| veyx_walk_codex_s.png | 139 |
| nullwarden_walk_codex_s.png | 81 |
| storm_adept_walk.png | 64 |
| bannerman_walk.png | 63 |
| spider_walk.png | 63 |
| sand_revenant_walk.png | 62 |
| stormmouth_walk_codex_s.png | 59 |
| waking_shard_walk.png | 59 |
| unfinished_sentence_walk.png | 55 |
| nullwarden_walk_codex_e.png | 54 |
| nullwarden_walk_codex_ne.png | 54 |
| nullwarden_walk_codex_se.png | 54 |
| vargoth_walk_codex_e.png | 54 |
| vargoth_walk_codex_ne.png | 54 |
| vargoth_walk_codex_nw.png | 54 |
| vargoth_walk_codex_se.png | 54 |
| vargoth_walk_codex_sw.png | 54 |
| vargoth_walk_codex_w.png | 54 |
| nullwarden_walk_codex_nw.png | 53 |
| nullwarden_walk_codex_sw.png | 53 |
| nullwarden_walk_codex_w.png | 53 |
| verdict_drone_walk.png | 53 |
| orc_walk_n.png | 49 |
| casket_creeper_walk.png | 47 |
| chorister_of_frost_walk.png | 47 |
| converted_walk.png | 47 |
| archon_vassik_walk.png | 46 |
| foundry_thrall_walk.png | 46 |
| grove_horror_walk.png | 46 |
| stormmouth_walk_codex_nw.png | 46 |
| stormmouth_walk_codex_sw.png | 46 |
| stormmouth_walk_codex_w.png | 46 |
| crusade_zealot_walk.png | 45 |
| elara_vessel_walk.png | 45 |
| oathbound_knight_walk.png | 45 |
| stormmouth_walk_codex_e.png | 45 |
| stormmouth_walk_codex_ne.png | 45 |
| stormmouth_walk_codex_se.png | 45 |
| choir_radical_walk.png | 44 |
| hollow_knight_walk.png | 44 |
| choir_ascendant_walk.png | 43 |
| high_artificer_maeven_walk.png | 43 |
| bog_lurker_walk.png | 42 |
| fangmaw_walk.png | 42 |
| riftling_walk.png | 41 |
| sleepwalker_walk.png | 41 |
| conductor_acolyte_walk.png | 40 |
| heart_of_the_root_walk.png | 40 |
| sluice_lurker_walk.png | 40 |
| smelter_lord_thrain_walk.png | 40 |
| commander_drayce_walk.png | 39 |
| morwyn_hollow_flame_walk.png | 39 |
| spider_walk_se.png | 39 |
| spider_walk_sw.png | 39 |
| choir_of_frost_walk.png | 38 |
| drowned_warden_walk.png | 38 |
| orc_walk_s.png | 37 |
| vent_skitter_walk.png | 37 |
| overgrown_gatewarden_walk.png | 36 |
| rootspawn_walk.png | 36 |
| shattered_vow_walk.png | 36 |
| auroch_minotaur_walk_codex_e.png | 35 |
| auroch_minotaur_walk_codex_ne.png | 35 |
| auroch_minotaur_walk_codex_se.png | 35 |
| grove_tender_walk.png | 35 |
| vess_walk_codex_n.png | 35 |
| skeleton_warrior_walk_s.png | 34 |
| bloat_leech_walk.png | 32 |
| korrag_reborn_walk.png | 32 |
| rootweaver_walk.png | 32 |
| aldric_burned_out_walk.png | 31 |
| auroch_minotaur_walk_codex_nw.png | 31 |
| auroch_minotaur_walk_codex_sw.png | 31 |
| auroch_minotaur_walk_codex_w.png | 31 |
| field_chirurgeon_walk.png | 31 |
| forgemistress_walk_codex_n.png | 31 |
| korrag_walk_codex_s.png | 31 |
| thornfather_grael_walk.png | 31 |
| cistern_mimic_walk.png | 30 |
| glacius_walk.png | 30 |
| royal_knight_walk_s.png | 30 |
| elf_druid_walk_n.png | 29 |
| nullwarden_walk_codex_n.png | 29 |
| skeleton_rogue_walk_n.png | 29 |
| duneprowler_walk.png | 27 |
| echo_walk_codex_e.png | 27 |
| echo_walk_codex_ne.png | 27 |
| echo_walk_codex_nw.png | 27 |
| echo_walk_codex_se.png | 27 |
| echo_walk_codex_sw.png | 27 |
| echo_walk_codex_w.png | 27 |
| glasshide_stalker_walk.png | 27 |
| rotmaw_walk_codex_s.png | 27 |
| stone_broken_walk_s.png | 27 |
| thorn_howler_walk.png | 27 |
| veyx_walk_codex_e.png | 27 |
| veyx_walk_codex_ne.png | 27 |
| veyx_walk_codex_nw.png | 27 |
| veyx_walk_codex_se.png | 27 |
| veyx_walk_codex_sw.png | 27 |
| veyx_walk_codex_w.png | 27 |
| burned_kings_echo_walk.png | 26 |
| forge_zealot_walk.png | 26 |
| skeleton_walk.png | 26 |
| sexton_walk_codex_e.png | 25 |
| sexton_walk_codex_ne.png | 25 |
| sexton_walk_codex_nw.png | 25 |
| sexton_walk_codex_se.png | 25 |
| sexton_walk_codex_sw.png | 25 |
| sexton_walk_codex_w.png | 25 |
| shardcaller_walk.png | 25 |

## Appendix C. Audit findings, final status

The 57 findings of the 2026-09-05 nine-subject workflow audit (classes, boss facings, the
frame edits), each re-checked by hand, with what happened to it. FIXED = changed on the
branch; SUPERSEDED = the strip was regenerated or rebuilt afterwards so the finding no longer
applies as stated; LEFT = verified and deliberately not changed (reason given).

1. `serane_walk_codex_s.png` f0 (P2, serane-s): Identity drift vs the same-facing idle: the two floating ice shards beside the shoulders are missing from ALL six walk_s frames (f0-f5). The idle (S) has them on every frame, and walk_e / walk_n carry them too, so they pop out ...
   FIXED: the two shards composited from the idle onto every frame
2. `serane_walk_codex_s.png` f2 (P2, serane-s): Frame 2 is drawn ~10% larger than the other five frames (a scale pop, not a pose): whole silhouette grows for one frame of the 6-frame loop, so the gliding boss swells and shrinks once per 0.43 s cycle.
   FIXED: frame 2 dropped (5-frame glide)
3. `serane_walk_codex_s.png` f1 (P3, serane-s): Detached slivers beside both sleeve icicle tips on f1 only: a 21x39 px diagonal streak floating right of the right sleeve and an 11x27 px streak at the left sleeve; they exist for one frame then vanish (not in the idle, not in ...
   FIXED: slivers dropped
4. `serane_walk_codex_s.png` f0 (P3, serane-s): Two tiny detached vertical slivers (3 px wide, 23 + 22 px) floating just right of the left sleeve icicle on f0; gone on f1-f5 and absent from the idle.
   FIXED: slivers dropped
5. `stormmouth_walk_codex_n.png` f4 (P2, stormmouth-n): Gait order is wrong: the viewer-left boot is the lifted/sole-showing foot in three consecutive loop frames (f4, f5, f0) while f0-f3 swap the lifted foot every single frame with no passing pose; the loop reads L R L R L L, so at ...
   FIXED: v3 roll, a real stride (rear boot lifts 25 to 70 px)
6. `stormmouth_walk_codex_n.png` f0 (P2, stormmouth-n): Bulk drift: the back view is about 15% narrower across the pauldrons/arms than the S walk and about 25% narrower than the idle (pauldrons less flared, arms tucked to the torso), so the boss visibly slims when it turns from S to N ...
   LEFT: your call; three rolls, the generator will not give back-view pauldron mass
7. `stormmouth_walk_codex_n.png` f0 (P3, stormmouth-n): Helm identity: the E profile (and therefore NE/NW, which are E copies/mirrors) shows a large rear-swept crest/horn on the crown; the new N back view has a plain segmented dome with no crest, so the crest vanishes when the boss ...
   LEFT: your call (no rear crest from behind)
8. `stormmouth_walk_codex_n.png` f0 (P3, stormmouth-n): Tone: the gunmetal plate on the back view reads slightly darker and cooler than the front facings (borderline on the 8% bar), and the strip has almost none of the blue specular pop of the idle/S plate.
   FIXED: v3 carries the family's blue-steel plate
9. `serane_walk_codex_s.png` f2 (P1, serane-s): The glide loop is five near-still frames plus one pop: frame 2 alone lifts the whole figure 10px, flares the gown hem out and back, and narrows the shoulders, so at 14 fps the boss twitches once every 0.43 s instead of flowing ...
   FIXED: frame 2 dropped
10. `serane_walk_codex_s.png` f2 (P2, serane-s): Frame 2 is a re-drawn figure, not just a pose: the crown band sits above the hairline with the forehead exposed (f1/f3/idle seat the gem on the brow), the face is longer with different brows and a centre-parted hair fall, each ...
   FIXED: frame 2 dropped
11. `serane_walk_codex_s.png` f0 (P2, serane-s): Missing equipment vs the same-facing idle: the two floating ice shards beside the shoulders (idle x163-173 and x448-458, y183-215, ~200px each) are absent from all six S frames, so they blink out when she starts moving south and ...
   FIXED: shards composited
12. `serane_walk_codex_s.png` f1 (P3, serane-s): Orphan slivers that blink: two small detached flecks beside the left sleeve in f0 (22px each), a 121px diagonal streak left of the left sleeve and a 161px diagonal streak right of the right sleeve in f1, then nothing in f2-f5; ...
   FIXED: slivers dropped
13. `mage_attack_walk_s.png` f0 (P2, mage-attack-walk): The whole S fire-on-move figure sits ~16 px (7% of the 228 cell) to the RIGHT of where walk_s and anim_s draw her, so firing while walking south hops the sprite sideways and back. Pre-existing (from e519aa2, not this session's E ...
   FIXED: attack_walk_s shifted onto walk_s
14. `mage_attack_walk_s.png` f6 (P3, mage-attack-walk): A detached grey/white sleeve-edge stroke floats above the raised sleeve at the shoulder line (53 fully opaque px, x146-162 y59-67), plus small dark keying specks under the raised sleeve in f1-f5 (1-4 px each) and a ragged dark ...
   FIXED (stroke dropped); the 1 to 4 px keying specks LEFT, sub-pixel
15. `mage_anim_e.png` f0 (P3, mage-attack-walk): Sibling observation (outside the subject files): the E idle has NO hip pouch, while mage_walk_e, the new mage_attack_walk_e and the front idle anim_s all carry the brown belt pouch, so the pouch blinks off when the mage stops ...
   FIXED: pouch pasted onto all five idle frames
16. `warlock_walk_e.png` f1 (P1, warlock-walk-and-attack-walk): Floating flaming skull is ABSENT in this frame (present only in f0 and f3), so the signature prop blinks 2-on/4-off across the 6-frame loop.
   FIXED: skull composited from frame 0
17. `warlock_walk_e.png` f2 (P1, warlock-walk-and-attack-walk): Floating flaming skull ABSENT (signature prop missing; part of the 2-on/4-off blink).
   FIXED: skull composited from frame 0
18. `warlock_walk_e.png` f4 (P1, warlock-walk-and-attack-walk): Floating flaming skull ABSENT (signature prop missing; part of the 2-on/4-off blink).
   FIXED: skull composited from frame 0
19. `warlock_walk_e.png` f5 (P1, warlock-walk-and-attack-walk): Floating flaming skull ABSENT (signature prop missing; part of the 2-on/4-off blink).
   FIXED: skull composited from frame 0
20. `warlock_walk_w.png` f1 (P1, warlock-walk-and-attack-walk): Per-cell mirror of walk_e (verified byte-exact mirror), so it inherits the skull blink: skull present only in f0/f3, absent in f1/f2/f4/f5.
   FIXED: the W family re-mirrored from the fixed E
21. `warlock_attack_walk_e.png` f0 (P2, warlock-walk-and-attack-walk): Palette/identity drift vs warlock_anim_e AND vs the walk_e it alternates with mid-stride: robe trim is a thin bright YELLOW line instead of the thick orange-gold embroidery, the belt gem is RED (idle/walk: purple), red piping on ...
   SUPERSEDED: attack_walk_e family regenerated from the new profile walk; the trim still reads about 5 degrees yellower (Your calls)
22. `warlock_attack_walk_w.png` f0 (P2, warlock-walk-and-attack-walk): Inherits the attack_walk_e palette drift by construction: warlock_attack_walk_w/_nw/_sw are byte-exact per-cell mirrors of attack_walk_e and _se/_ne are byte copies (verified), so the yellow trim / red gem / darker robe shows on ...
   SUPERSEDED: same regen
23. `warlock_attack_walk_e.png` f4 (P3, warlock-walk-and-attack-walk): Grimoire hand-swap: in f1-f3 the book leaves the thrusting near hand and is tucked at the belt behind the sleeve (a red-brown spine peeks at the belt; reads as pass-behind, not a blink), but in f4 the book is held at the chest by ...
   SUPERSEDED: same regen
24. `warlock_attack_walk_n.png` f2 (P2, warlock-walk-and-attack-walk): Seam file (from e519aa2): a SECOND flaming skull floats at the extended arm's elbow beside the real skull -- a duplicated signature prop / baked flare away from the hand.
   FIXED: attack_walk_n regenerated from walk_n
25. `warlock_attack_walk_n.png` f3 (P2, warlock-walk-and-attack-walk): Seam file: the second floating skull persists at the elbow of the extended arm (same duplicated prop as f2; f1 also shows a small skull-like purple blob in the raised hand at the shoulder).
   FIXED: same regen
26. `warlock_attack_walk_s.png` f4 (P3, warlock-walk-and-attack-walk): Seam file (identical bytes to the flat warlock_attack_walk.png): tiny near-black specks detached to the left of the robe hem at hip height (also visible as dashes in f5 and f6 on the 1x sheet). ~1px at play scale.
   LEFT: sub-pixel specks
27. `mage_cast_e.png` f0 (P1, mage-e-column): Frame 0 (and f1) is drawn at a smaller scale than the rest of the clip while standing upright (not a crouch): body 172px vs 201-221px in f2-f5. Because the hero renderer locks the clip's scale to frame 0's used rect (178px vs the ...
   FIXED: frames 0/1/6 normalised to frame 2's body, re-installed
28. `mage_cast_e.png` f5 (P2, mage-e-column): The staff head is cut off at the top cell edge: f5 loses the blue crystal entirely (only wood runs to y=0) and f4's crystal tip is flat-cut at the edge. The crystal blinks out for the two peak frames of the cast, then reappears ...
   FIXED: cast installed into a 320 px cell
29. `mage_cast_e.png` f1 (P2, mage-e-column): The hip pouch pops into existence between f0 and f1 (f0 has no pouch, f1-f6 carry a brown pouch on the near hip), an item blink inside one clip.
   FIXED: pouch pasted onto cast frame 0
30. `mage_anim_e.png` f0 (P2, mage-e-column): The idle carries no hip pouch while walk_e, attack_e (all frames) and cast_e (f1+) show a brown pouch on the near hip, so the pouch blinks on/off every time she stops or starts moving facing E/W. The idle is the outlier in the ...
   FIXED: pouch pasted onto the idle
31. `mage_attack_e.png` f0 (P2, mage-e-column): The staff is held in the FAR (left) hand behind the body for the whole attack clip, while the idle, walk and cast all hold it in the near (right, camera-side) hand in front of her, matching the S canon (staff in her right hand). ...
   FIXED: v2 attack roll, staff in the near hand
32. `mage_attack_e.png` f6 (P2, mage-e-column): The recovery frame is drawn compressed: head-top drops from y=23 (f0-f3) to y=48 while the belt stays at y=130, so the torso is 82px vs 103px (-20%) and the body is 173px vs 198px (-13%) with the figure nearly upright, not ...
   FIXED: v2 roll, head-top 23 px in all seven frames
33. `mage_anim_e.png` f0 (P2, mage-e-column): The E idle is duller than everything it co-displays with: body-mean luminance 114.4 vs 124.6 for the S idle (-8.2%), robe-only mean 162 vs 174 (S), 182 (N), 187 (blighted_healer profile), and 167-169 for its own walk_e / 171-174 ...
   LEFT: 5 percent vs the S idle after the pouch paste, inside the 8 percent bar
34. `nullwarden_walk_codex_n.png` f1 (P1, nullwarden-n): Leg cycle does not alternate: the viewer-right foot is the lifted/sole-showing foot in 4 of 6 frames (f1, f2, f3, f5) while the viewer-left foot lifts in only 2 (f0 toe-off, f4). On loop the right leg swings twice per cycle and ...
   FIXED: cycle rebuilt as frames 0 to 2 plus their mirrors
35. `nullwarden_walk_codex_n.png` f0 (P2, nullwarden-n): Body-type drift vs the front-facing siblings: the back view is a leaner, more upright figure. Widest shoulder/pauldron line = 0.53 of cell in every N frame vs 0.62 in S f0 (0.61 S f1) and 0.57 on the idle body, at the same body ...
   LEFT: noted; your eye on the S to N turn
36. `nullwarden_walk_codex_n.png` f0 (P3, nullwarden-n): Frame-count parity: the N strip is 6 frames while its E and S siblings of the same walk clip are 4. enemy.gd advances frames at a fixed per-frame dwell (sprite.frame = int(anim_t * anim_fps) % anim_frames; dir_set default 6 fps x ...
   LEFT: by design, the engine reads the frame count from the strip
37. `nullwarden_walk_codex_n.png` f0 (P3, nullwarden-n): Orphan fleck in frame 0: a detached 31-px dark fragment of the tabard's pointed hem sits just below the tip, between the legs (cell x538-544, y732-736); it is absent in every other frame, so it blinks on for one frame of the ...
   FIXED: 31 px fleck dropped from frames 0 and 3 (frame_fix --drop-orphans, the last edit on the branch)
38. `cinderhide_attack.png` f3 (P3, frame-edits: cinderhide_attack): Erase residue: the claw-sliver removal used an alpha cutoff (~40), leaving 106 px of the sliver's anti-alias fringe (alpha 1-38, near-black RGB ~(1,1,1)) as 24 tiny components that trace the claw's outline (x[89,122] y[611,669]) ...
   LEFT: alpha 1 to 38 residue, sub-pixel in play
39. `elf_ranger_attack.png` f2 (P3, frame-edits: cinderhide_attack): Bowstring blinks out in the release frame: f0 and f3 draw the string tip-to-tip, f1 draws it pulled to the face with the nocked arrow, f2 has no string at all (bow limb only). PRE-EXISTING: identical in the 7fd27a4 base and the ...
   LEFT: pre-existing on main
40. `cinderhide_attack.png` f0 (P3, frame-edits: cinderhide_attack): Tone vs the live idle it co-displays with (cinderhide_anim_codex, art.gd:3319): the attack strip's body reads darker in every frame -- mean luminance 38.6 vs idle 42.2 (8.5% lower, just past the 8% bar); the dark hide (L<60, ...
   LEFT: 8.5 percent, at the bar
41. `stormmouth_walk_codex_n.png` f0 (P2, stormmouth-n): The 6-frame N walk has no stride or passing pose: both legs stay side by side at the same length in every frame and the only motion cue is which boot tilts to show its sole, and that flips every frame (sole on L f0, R f1, L f2, R ...
   FIXED: v3 stride
42. `stormmouth_walk_codex_n.png` f0 (P2, stormmouth-n): Body type is slimmer than the front idle and the S walk: at identical body height (577px) the N figure is ~15% narrower than S and ~21-24% narrower than the idle in every band (pauldrons, chest, hips, thighs), so under CLIPSCALE ...
   LEFT: your call
43. `stormmouth_walk_codex_n.png` f3 (P3, stormmouth-n): Orphan fleck: a 9px detached fragment of the tabard-hem tassel floats in the gap between the boots, below the left tassel tip (cell x478-480, y587-592); ~2x5px on screen at the boss's ~0.77x render.
   SUPERSEDED: v3 strip
44. `stormmouth_walk_codex_n.png` f4 (P3, stormmouth-n): Orphan fleck: a second 9px detached tassel fragment between the boots below the left hem tip (cell x440-442, y583-588); same class as the f3 island.
   SUPERSEDED: v3 strip
45. `paladin_walk_n.png` f6 (P2, paladin-walk-n (game/assets/sp): Frame 6 is a near-duplicate of frame 2 (same right-boot-raised pose), so the 8-frame loop has a 4-frame period: f4-f7 replays f0-f3's right-leg phase instead of mirroring it to the left leg. Applies identically to ...
   LEFT: your call (regen vs the re-sliced old cycle)
46. `paladin_walk_n.png` f5 (P2, paladin-walk-n (game/assets/sp): Leg cycle does not alternate: the right boot is the raised/forward foot in 6 of 8 frames with up to ~22 px lift, the left boot is raised only in f1 and f5 with about half that lift and never gets a full swing, so in the loop the ...
   LEFT: your call
47. `paladin_walk_n.png` f0 (P3, paladin-walk-n (game/assets/sp): Idle-to-walk size pop on the N facing: with the hero frame-0 scale lock the walk figure renders at the idle's height but with a ~6% narrower torso, a ~12% shorter shield and a smaller mace head than paladin_anim_n; the S control ...
   LEFT: your call
48. `paladin_walk_n.png` f6 (P3, paladin-walk-n (game/assets/sp): Orphan fleck: a 2x2 near-black semi-alpha cluster detached from the silhouette just below-left of the skirt hem; the only frame in the strip with a second alpha component. Sub-pixel at render (~0.4 screen px). Applies identically ...
   LEFT: sub-pixel
49. `nullwarden_anim_codex.png` f1 (P1, boss-facing-seams): The live idle (BOSS_IDLE_STRIP_BASE) has its four frames sitting in four different places inside the cell, a 2x2-grid slice error: the body hops ~23% of cell sideways and ~20% vertically every frame at the 6 fps idle, and every ...
   FIXED: idle centred (the later corpus recentre emptied its last frame; the centred version was restored)
50. `stormmouth_walk_codex_n.png` f0 (P2, boss-facing-seams): The new back view slims and dims when the boss turns away: pauldron/shoulder band is ~16% narrower than the S walk and idle, and the plate reads ~10% darker (charcoal vs blue-steel), so the E/S -> N turn changes his bulk and tone.
   PARTLY: the plate tone fixed by v3; the bulk LEFT (your call)
51. `korrag_walk_codex_n.png` f0 (P2, boss-facing-seams): The north walk is the darkest facing in the family: ~26% darker than the idle it co-displays with and ~14% darker than its own E/S walk siblings, so the boss visibly dims when he walks away. Pre-existing (file unchanged on this ...
   FIXED: tone-matched to the idle
52. `korrag_walk_codex_e.png` f0 (P2, boss-facing-seams): The regenerated E walk is ~13% darker than the idle it transitions from (raw -17%); it matches the unchanged S walk exactly, so the idle is the family's bright outlier and the idle->walk seam dims by the same step on every facing.
   FIXED: tone-matched, E family copies and mirrors rebuilt
53. `nullwarden_walk_codex_s.png` f0 (P3, boss-facing-seams): Shoulder bulk changes on the S<->N turn: the S walk's pauldron band is ~10% wider than the idle's and ~14% wider than the new N walk's, so the boss broadens facing the camera and narrows facing away.
   LEFT: noted
54. `echo_walk_codex_n.png` f0 (P3, boss-facing-seams): The new back view carries a teal-grey cast on the wings and skirt where the idle, S and E read violet-grey; a subtle palette drift visible side by side on the turn.
   LEFT: P3
55. `serane_walk_codex_n.png` f0 (P3, boss-facing-seams): The unchanged north walk is ~12% brighter than the idle it co-displays with while the new S and E strips sit within 4% of it, so the ice queen lightens on the turn away. Pre-existing.
   LEFT: P3, pre-existing
56. `korrag_walk_codex_e.png` f0 (P3, boss-facing-seams): The idle's second held prop, the dark spiked ball in the off hand, is absent in all six E frames; only the whip is carried. The off hand is on the far side of the profile so this may be occlusion, but nothing of the ball peeks ...
   LEFT: P3, far-side occlusion is plausible
57. `korrag_walk_codex_n.png` f0 (P3, boss-facing-seams): On the unchanged north walk the spiked ball rides at the tip of the whip on the ground instead of being held in the off hand as in the idle, a prop reinterpretation on the back view. Pre-existing.
   LEFT: P3, pre-existing
