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

`verify_art` catches only #5 partially (GHOST) and edge alpha (BLEED). The rest are eyes-only.

## Observed failure modes and the brief fix

| # | Failure | Where it bit | Fix in the brief |
|---|---|---|---|
| Facing flip | windup frames face the OPPOSITE direction, figure turns to act, turns back | mage attack/cast (E row: f1-2 faced W) | "the figure faces the row's ONE direction in ALL frames; do NOT turn/rotate/pivot; f1 and fN already face that direction" |
| Weapon dropped | staff missing / replaced by a bare-hand orb in some frames | mage attack (front row cupped an orb), mage cast (f6-7 dropped staff) | "the staff is GRIPPED in EVERY frame of EVERY row; the bolt comes from the STAFF tip; never a free-floating orb" |
| Face distortion | face melts/changes in scattered frames | mage cast recovery | "identical clean face in every frame; do not distort/melt/smear/age" |
| Mis-slice | released projectiles drawn FAR out into the gutters; slicer cuts through the figure (bow left in the neighbor cell, bowless archer + stray arrows) | archer Multishot (attack2) — got GHOST warns that were wrongly dismissed | "do NOT draw released/flying projectiles; the game spawns them; NOTHING in the gutters; every column is one clean figure" |
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

See `IMAGEGEN_SPRITE_PIPELINE.md` for the full generation→build→install pipeline; this file
is the skin-specific QA addendum learned from the era-3 elite-skin batch.
