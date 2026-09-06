# Crownless visual overhaul, 2026-09-03 to 09-05: review guide

Branch `claude/visual-overhaul-2026-09-03` (worktree `.claude/worktrees/epic-panini-3fd8fd`),
75+ commits on top of main 7fd27a4. NOT merged: that is your call after this review.
The full record with every commit, tool and gate is `VISUAL_OVERHAUL_2026-09-03.md` at the
branch root. This file is the short version for the GIFs.

## How to read a GIF

Each GIF plays the OLD strip's frames (branch base) on the left and the NEW strip's frames
(branch head) on the right, feet aligned, above game scale, palette-quantized. Judge motion,
identity and consistency here; judge colour and softness in-game, not in a GIF. A GIF with
only a NEW side is a strip that did not exist before (every death clip, the base classes'
fire-on-move clips).

Folder layout: `classes/<class>/`, `bosses/<boss>/`, `mobs/<mob>/`, `npcs/`, `capital/`,
`props/`, `travel/`.

## What was done, folder by folder

### classes/  (the six base heroes; the 18 real skins were not touched, per your ruling)
- mage: the whole E column (anim, walk, attack, cast) was FRONT art wearing the E name, and
  W mirrored it, so she had no side view at all. All four are now a true right profile;
  W is the mirror. Her fire-on-move clip was rebuilt from the new walk. Fixes on top: the
  cast's first frames were drawn small (the renderer locks a clip to frame 0, so the whole
  cast ballooned), the raised staff was cut at the cell top, the E idle was missing the hip
  pouch every other clip carries, the attack held the staff in the wrong hand.
- warlock: walk E was a three-quarter front view against a full-profile idle (the hood
  snapped to camera on the first step); now a true profile, fire-on-move rebuilt from it.
  The floating skull existed in only 2 of 6 walk frames; it is in all six now.
- mage, warlock, assassin: `attack_walk_b`, the alternate fire-on-move you asked for on
  08-23 (mage rising flick, warlock two-hand book shove, assassin sidearm flick). The primary
  fire-on-move clips for all four ranged base classes are also new: the feature had been dark
  for every default character (only skins shipped them).
- warrior: walk E/W had the flaming greatsword dimmed to a thin plain blade that changed
  size every frame; restored via an edit-in-place roll (your approved gait untouched).
- paladin: walk_n on main was an 8-figure row saved 6 cells wide (every cell showed one and
  a third paladins). A back-view regen is installed; the re-sliced old cycle sits beside it
  in `art_src/paladin_n_2026-09-03/old_cycle_resliced/` as a one-copy swap. YOUR CALL.

### bosses/
- Walk facings regenerated where a facing was missing, wrong or a byte copy: ashpriest S+N,
  auroch S+N, choirmother N, hrolgar E+N, kaethra E+N (she had no north at all), korrag E,
  rotmaw E, veyx E, echo N, stormmouth N (was a copy of E), nullwarden N (front art wearing
  the N name), serane S (was the idle). Big cells are now requested as two-row grids so
  nothing upscales at install.
- 20 death clips (ashpriest through first_howl): every boss used to collapse
  procedurally at the climax of its fight. Six frames: hit, stagger, buckle, fall, ground,
  still; the last frame is held, then fades.
- Fixes: nullwarden's idle sat 51px off centre (a sideways jump on every idle/walk
  transition); auroch's S/N came back ice-blue and were graded to the idle; korrag's walks
  were 13-26% darker than his idle; a green keying patch inside ashpriest S.
- Code side, not visible in a GIF: every boss's telegraph now has its own hue and ground
  figure (ring/cone/line/cross/square), and through the fuse the boss holds a per-kind body
  posture and snaps on release (brutes crouch and widen, casters draw up, skirmishers lean,
  serpents coil). The danger disc is unchanged; these are accents. See "In-game" below.

### mobs/
- Roughly 65 walks regenerated over six waves: the 4-frame pose-steps that read as
  "robotic" are now 6-8 frame strides and trots with knee bends and a passing frame
  (cultist, wolves, skeletons, zombies, elves, hounds, spiders, mummies, rats and the rest).
  Where a first roll drifted (blightwolf went teal, vent_skitter lost its lava tips on two
  frames, seven bipeds still scissored), it was re-rolled with a tightened brief.
- 27 death clips for placed mobs that only collapsed procedurally.
- A corpus-wide defect nobody had named: many older 4-frame idles and walks were sliced off
  the frame grid, so the figure slid 15-30% of the cell across the loop, a constant jitter.
  68 idles and 97 legacy walks recentred. Idle-to-walk seams were then measured for every
  enemy and fixed where they popped (walks brighter or darker than their idle, hounds that
  shrank 25% on the first step, walks off their idle's centre).
- 63 sprites had a green keying ring; despilled. Eight candy-bright props graded.

### npcs/  recentred off-grid idles only.
### capital/  the floor was the contrast problem (holystone at luminance 188 under
buildings at 44), graded to 151; all 26 pieces repainted painterly with silhouette and
footprint kept; light sockets on every flame; the depths portal's strobe fixed.
### props/  palette grades toward the house palette.
### travel/  old vs new walks over scrolling ground at the mob's real speed (the only way to
see foot skating; walks march in place by your 08-28 ruling, so judge the stride, not the slide).

## In-game (the GIFs cannot show these)
- `enemy.gd` motion stack: stride-locked bounce and lean per body archetype, real deaths
  (21 shipped death clips that nothing ever played now play), footfall dust, boss stomp,
  8-direction turn hysteresis, bite windup crouch, summon spawn-in. Four bugs under the same
  read: elites shrank to base size on their first step, Act-1 bosses glided for co-op guests,
  the hit squash lifted the feet, the walk clock was only half speed-coupled.
- Boss tells: `shot.bat tells` (every tell on one sheet), `shot.bat tells --bosses
  --phase=0.85` vs `--phase=0.02` (the windup posture per boss).
- Capital: `shot.bat capital` (nine rooms), then walk it.

## Your calls (also in the board's Open list)
- paladin walk_n: regen (installed) vs the re-sliced old cycle (beside it).
- stormmouth N still reads slimmer across the pauldrons than his S walk (three rolls; the
  generator will not give back-view pauldron mass).
- bannerman idle frame 4 was already clipped in the source; a regen would be needed.
- minor facing tone/hue nits: korrag N darker, serane N brighter, echo N teal cast,
  wolf/rotmaw/veyx/duneprowler hue.

## Gates on the final tree
Full suite AUTOTEST PASS (172 sections, three green runs, the last with the windup code and
all 47 death clips), preflight OK, confirming desktop import, quick suite PASS, mobile
`sync_mobile --apply --gate` GATE OK six times (the last after the boss deaths), corpus
`verify_art` sweep 312 bases with zero non-import FAILs.
