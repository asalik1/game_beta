# Melee swing alternation — alternate basic swings (2026-08-16)

Owner ruling (2026-08-16): a melee hero's basic attack must not replay one
identical motion — "an assassin might have his basic attack be like a vertical
slash and then a horizontal slash; same with warrior … that slight alternation
matters for melee characters when it comes to immersion." Owner authorised the
whole build, PixelLab included for the assassin.

## What shipped

| class | primary `attack` (unchanged) | new alternate `attackb` | generator | frames | cells |
|---|---|---|---|---|---|
| Warrior Cleave | overhead raise → downward diagonal chop | LEVEL horizontal sweep at waist/chest height | Codex built-in ImageGen, 8 authored directions | 7 | 320–496 px (auto-fit to the level blade) |
| Paladin Judgment | overhead hammer slam | LEVEL sideways hammer swing, spark at the head | Codex built-in ImageGen, 5 authored (S SE E NE N) + W side mirrored (paladin convention) | 7 | 288–352 px |
| Assassin Stab | single-dagger forward lunge | double-dagger horizontal CROSS-SLASH (X at the chest) | PixelLab `animate_character` v3 on Assassin v2 (`8b3b2ab1`) + PixelLab Resize upscale, S/E/N authored, E→NE/SE, W side mirrored (base-stab layout) | 8 | 277 px (N: 336) |

Runtime files: `game/assets/sprites/<class>_attackb_<dir>.png` (8 dirs) +
`<class>_attackb.png` (South alias). Same 180 px frame-1 standing body as each
class's `attack`; the engine grounds every strip on its own cell.

## Engine seam (code)

- `art.gd` `HERO_CLIP_FILES/FPS` — new `"attackb"` clip (22 fps like `attack`).
- `player_core.gd` — `_a1_swing` parity + `_alt_basic_clip()`; reset with the
  class sprite. Art-driven: no `attackb` strip (every skin today) = the single
  swing, exactly as before.
- `player.gd` `use_ability` — a1 `"attack"` → `_alt_basic_clip()` (Berserk's
  red-blade `ult` swing untouched).
- `player_combat.gd` `swing_delay` + `Balance.ALT_SWING_DELAY` — the alt swing's
  own contact time. Measured: warrior f4 = 0.136 s (≈ WARRIOR_SWING_DELAY, no
  entry); paladin f4 (S f5) = 0.14–0.18 s (≈ PALADIN_SMITE_DELAY, no entry);
  assassin X lands on f5 = **0.18 s** (entry; the lunge's 0.10 s is earlier).
- `autotest.gd` `_test_swing_alternation` — strips installed + 8-dir, parity
  flips on the live `use_ability` path, fresh body opens on the primary swing,
  skin fallback, assassin contact time.
- `tools/art/verify_art.py` — `attackb` gated exactly like `attack`.

## Folder map

- `<class>/attackb_<dir>/codex_brief.txt` — the exact ImageGen prompt (refs
  were: warrior = the accepted same-direction `class_attack_regen_imagegen_2026-08-02`
  source; paladin = `paladin_oathbound_arbiter/regen_base_rotations.png` +
  the runtime `paladin_attack_<dir>.png` composited on #00ff00).
- `…_vNN_source.png` — every raw ImageGen attempt (all kept); `codex_result.md`
  = Codex's own per-frame report and pick.
- `…_vNN_keyed.png` / `…_candidate.png` / `…_contact.png` / `…_22fps.gif` —
  build outputs (`tools/art/alt_swing_pipeline.py build`).
- `<class>_attackb_all_directions_contact.png` / `…_22fps.gif` — the review sheet.
- `assassin/pixellab_raw/{south,east,north}` — the 9 raw 212 px frames of
  group `f7f93de7` (v01, ACCEPTED); `…_sel/` = the 8 runtime picks (see
  `SELECTION.txt`); `pixellab_raw_v02/` = group `bda5fcf0` (REJECTED: the
  daggers cross behind the back in N, E holds the crossed pose 4 frames, S
  failed); `attackb_n_277_rejected/` = the 277-cell N attempt whose arms-wide
  follow-through (307–309 px) could not fit — rebuilt at `--runtime-cell 336`.
- `<class>/runtime_pre_install/` — would hold anything the install replaced;
  empty this pass (all 27 files were NEW).

## Picks

Warrior: s v01, se v01, e v01, ne v01 (Codex: cleanest gutters), n **v01**
(v02/v03 raised the blade vertically at the peak — an overhead read, exactly
the motion the alt must not be), nw v03, sw v03, **w = mirror of e** (see the
owner-note section: both authored W rows drifted to blacker plate).
Paladin: s v02, se v01, e v01, ne v01, n v03.

## Owner note 2026-08-16 (same day): "warrior's blade changes size … sprite size
not consistent" — measured and fixed

Measured on the first install: the alt's upright mid frames were drawn 173–176
px tall against 180 (reads as the character shrinking, since the pose is
upright), and the greatsword's grip→tip length drifted per frame (E row: level
windup blade ~100 px, mid-sweep ~140, contact ~190 at the same body scale).
Body height on the base cleave varies MORE (151–212) but there the pose
crouches/raises, so it reads as motion.

- Codex repair pass (`warrior_repair/attackb_<dir>/`, briefs + r01–r03 sources
  + reports kept): asked for a fixed-length prop and constant figure height.
  Codex's own reports: blade drift remained in 6/8 rows — the generator does
  not hold a prop length across figures. Not adopted.
- Deterministic fix in the builder instead (`alt_swing_pipeline.py build`):
  - `--even-body`: per-frame scale so every frame's DENSE-BODY height (sword
    excluded) equals frame 1's (180). Applied to warrior AND paladin (paladin
    E/NE mid frames were 173–178). Frames off by >12% would be left as a real
    crouch; none were.
  - `--stretch <dir>=<frames>`: axial stretch of the blade (pixels beyond the
    gauntlet block on the weapon side) about the grip, along its own axis, to
    the row's longest level blade (the contact frame). Blade width, direction
    and the body pixels are untouched. EXPLICIT frame lists from inspecting the
    sources — only level blades whose root (hands at/beyond the body edge) is
    visible: `se=3,5 e=2,3 ne=2,3,5 nw=2,3,5`; S/N/SW untouched (front/back
    sweeps cross the body, the visible length is occlusion, not length).
  - `--mirror w=e`: the authored W rows (v02 AND v03) came back in blacker,
    less-ember plate than the primary and every other alt row — a palette
    drift — so W ships as the exact mirror of the E row (the paladin already
    mirrors its whole W side; the warrior's plate is symmetric at 52 px).
    NW/SW stay authored (their palette matches).
  - (An automatic "any level frame" stretch rule was tried and rejected: it
    stretched E's diagonal guard blades x1.8 because their root sits inside
    the body columns.)
  - Cells re-fit (E/W now 544 …); feet still frame-1 lowest pixel.
- Re-verified: `verify_art.py warrior paladin assassin` VERIFY OK, quick suite
  green, mobile re-synced.

## Slicing lesson

A level, fully extended sword reaches past the neighbouring figure's column,
so gutter-based slicing (`_infer_columns`) found 4–6 figures in a 7-figure
row. `alt_swing_pipeline.build` slices by connected components: the 7 largest
components are the bodies (weapon attached), every smaller island (ember wisp,
spark) joins the body whose bbox is nearest, and the cell auto-grows so no arc
is clipped (`_fit_cell`). Rejects when two figures are fused.

## QA

`verify_art.py warrior paladin assassin` = VERIFY OK (27 new strips, all
gates). Compile gate + quick suite green desktop and mobile
(`sync_mobile.py --apply --paths …` scoped to this pass's files); full suite
see the hand-off note.
