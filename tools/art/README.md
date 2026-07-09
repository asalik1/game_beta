# Sprite-sheet extraction pipeline (`extract_sheet.py`)

Turns a **pre-keyed animation sheet** (one big grid of labelled frames on a
transparent background) into the engine-ready horizontal clip strips Emberfall
loads. Built for the six class sheets; **reuse it verbatim for boss/mob sheets.**

This is the process that fixed the warrior's *green-holes*, *head cut-off*, and
*too-small* problems — each was a distinct step below, so if a new creature
shows the same symptom you know which knob to check.

---

## When to use it

You have an AI-generated (or hand-drawn) sheet where each ROW is an action and
each COLUMN is a frame, and each cell has a character. The tool takes either a
**transparent-background** sheet (alpha = silhouette) or a **solid-background**
one (it auto-keys the bg by colour when the image is mostly opaque). Baked-in
gold labels (row names + frame numbers) are removed automatically.

Source sheets live in the asset library (`OneDrive/Assets/Custom/`), NOT in the
repo. Only the extracted strips get committed, into `game/assets/sprites/`.

### Pick the source that CONTRASTS the character (measured)

A colour-key removes every pixel close to the background colour, so keying needs
subject↔background contrast. Measured across our six classes, the fraction of a
character a navy-background key would eat rises straight with darkness:

| character | avg brightness | eaten by a navy (dark) bg |
|---|---|---|
| assassin (darkest) | 36 | **52.8%** — half the ninja vanishes |
| warlock | 39 | 45.8% |
| warrior / archer | 51 / 57 | 26% / 32% |
| paladin / mage (lightest) | 83 / 80 | **17% / 19%** |

So: **light characters key cleanly off a dark (navy) bg** — the few eaten pixels
are sparse interior shadows that `solidify`'s hole-fill restores. **Dark
characters need a light or transparent bg** — on a dark bg the key eats the body
itself, unrecoverably. That's why we pulled the light classes (paladin, mage,
archer) from the navy ORIGINALS and the dark ones (assassin, warlock, warrior)
from the pre-keyed transparent `(2)` sheets. Rule of thumb: dark subject → light
bg, light subject → dark bg.

---

## Rebuild the whole roster (and where things live)

The exact per-class recipe (which source sheet + flags each class uses) is
codified in **`tools/art/build_sprites.py`** — run it to regenerate every class
sprite, then re-import:

```bash
python tools/art/build_sprites.py     # writes game/assets/sprites/
tools/Godot_v4.4.1-stable_win64_console.exe --headless --path game --import
```

**Where the assets live:**

| what | where | in repo? |
|---|---|---|
| Source sheets (raw art) | `OneDrive/Assets/Custom/` (`EMBERFALL_ART_SRC`) | no — asset library only |
| Extracted engine strips | `game/assets/sprites/<class>_*.png` | yes — the shipped sprites |
| Heroes-set backup + directional master | `art_src/heroes_clips/` | yes |

**Per-class source (why each — see the contrast rule above):**

| class | source sheet | note |
|---|---|---|
| paladin, mage, archer | `Custom/<Class>.png` (navy ORIGINAL) via `build_sprites.py` | light figures — key cleanly off a dark bg |
| **assassin, warlock, warrior** (all clips + directional) | `Custom/<class>_upscaled/*.png` via **`upscale_hero.py`** | ChatGPT UPSCALES — a separate tool, NOT built by `build_sprites.py` |

The three dark classes were originally extracted from the `Custom/<Class> (2).png`
transparent sheets; they now use ChatGPT upscales instead. The `(2)` and original
sheets are sometimes **different art** (e.g. the paladin `(2)` was a kneeling
variant), not just different keying — always eyeball a rebuild.

### Upscaled classes (separate pipeline: `upscale_hero.py`)

Some classes use higher-detail ChatGPT redraws instead of the `(2)` sheet. They
can't go through `extract_sheet` because they (a) sit on white, (b) are drawn at
a **different zoom in every clip** — so the engine's shared idle-derived scale
would make the character grow/shrink between animations — and (c) sometimes drop
a frame (the assassin's stab was missing its final SE frame). `upscale_hero.py`
handles all three: white-key + de-halo each figure, then rescale + feet-anchor
every clip to match its ORIGINAL counterpart's layout (body ref regenerated from
`<Class> (2).png`, directional ref from the Heroes backup), filling any missing
frame from its pair-mate.

```
python tools/art/upscale_hero.py             # every configured class
python tools/art/upscale_hero.py warlock     # just one
```

Add a class by giving it an entry in `CLASSES` (source sheet, clip order, the
body suffix→source map, any directional strips). Sources are archived under
`Custom/<class>_upscaled/` with clip-name filenames. Upscaled classes are left
out of `build_sprites.py`'s `JOBS` so a roster rebuild can't overwrite them.

---

## Run one sheet by hand

```bash
python tools/art/extract_sheet.py \
  --in "<source sheet>.png" \
  --out "<scratch dir>/<name>" \
  --class <name> \
  --names "idle,walk,run,attack,attack2,dash,ult,death"
```

- `--class <name>` — the sprite base name; output files are `<name>_<clip>.png`.
- `--names` — **one clip name per ROW, in order.** The row count printed must
  match your list length, or the mapping is off (see Troubleshooting).
- `--pad` (default 1.06) — square padding around the widest/tallest frame.

It writes, per row, `<name>_<clipname>.png`; the row named `idle` also produces
`<name>_anim.png` (the engine's idle-strip name) + `<name>.png` (static frame,
used by the codex/portraits). A `<name>_QA.png` contact sheet is written for
eyeballing. `_rowNN.png` debug strips are written too — don't install those.

### Clip-name vocabulary the engine understands

`idle walk run attack attack2 cast dash ult ultidle death` — see
`Art.HERO_CLIP_FILES` / `HERO_CLIP_FPS` in `game/scripts/art.gd`. A row mapped to
a name outside this list is still written to disk but the player won't play it.

---

## What each step fixes (the important part)

The tool does six things per frame. Each one killed a specific bug:

1. **Alpha mask** (`alpha > 40`). The transparent background keys itself — no
   colour-distance guessing, no per-sheet background constant. (Earlier labelled
   sheets had *different* navy backgrounds; auto-keying off alpha sidesteps that
   entirely.)
2. **Digit-glyph removal.** Baked frame-numbers are small gold blobs, but so are
   bits of gold armour and blonde hair — size/shape alone eats those and leaves
   holes (this was the paladin/archer green-see-through bug). The gate also
   requires the blob to be **floating** (its immediate surroundings mostly
   transparent); a number floats, embedded armour/hair does not, so trim & hair
   survive while the numbers go.
3. **Largest connected component = the character.** Every label, number, and
   detached FX puff is a separate, smaller blob, so keeping only the biggest
   component removes them **with zero geometric masking**. → *This is why heads
   are never clipped.* (The old approach blanked a top-left rectangle to erase
   labels and decapitated any pose whose head reached into it.)
4. **SOLIDIFY** — fill interior holes + force alpha fully opaque. → *This is the
   green-grass fix.* Semi-transparent edge/interior pixels were compositing over
   the grass and tinting the sprite green; making the silhouette 100% opaque
   (and inpainting any hole with its nearest colour) means nothing behind the
   sprite ever shows through. Verify with the "green background" check below.
5. **Mirror each frame to face LEFT.** Emberfall's `Art.faces_left` contract
   says art natively faces left (the engine flips it when moving right). Source
   art faces right, so every frame is mirrored — **per-frame, preserving column
   order** (mirroring the whole strip would reverse the animation).
6. **Uniform global square, feet-aligned.** All clips share one frame size so
   the engine never rescales between them, and feet sit on a constant baseline
   so the character doesn't bob vertically.

Plus: **frame 0 is dropped** (→ 7 frames). It's the only cell carrying the gold
ROW-NAME label, which a wide pose can merge into the figure; dropping it is
invisible for loops and harmless for one-shots.

---

## Install + verify

1. Copy the named clip PNGs (skip `_rowNN` and `_QA`) into
   `game/assets/sprites/`.
2. Re-import: `tools/Godot_v4.4.1-stable_win64_console.exe --headless --path game --import`
3. Compile gate: `... --script res://check_compile.gd` → `COMPILE OK`.
4. **Green-bleed check** (the warrior symptom) — composite an idle frame over a
   grass-green background and look for tinting; a clean sprite has **0
   semi-transparent pixels**:
   ```python
   from PIL import Image; import numpy as np
   a = np.asarray(Image.open("game/assets/sprites/<name>_anim.png"))[:,:,3]
   print("semi:", int(((a>0)&(a<255)).sum()))   # must be 0
   ```
5. In-engine: `... --path game res://shot_kit.tscn -- --class=<name>` (players),
   then `test_quick.bat`, then `test.bat` before staging.

---

## Directional aim ANIMATIONS (8-way)

A flat left/right swing clip can't track a freely-aimed attack (the assassin's
Stab fires in any of 360°, but a mirrored horizontal thrust only looks right
dead-left/right). The fix is a **directional sheet**: 8 directions in the order
**E, NE, N, NW, W, SW, S, SE**, each with K sub-frames (windup → action). The
engine packs them into one `8*K` strip and, on cast, plays the K frames of the
direction matching the aim, then returns to idle.

The engine slices frame `dir*K + sub`, so the strip MUST be laid out
direction-major. Extract with `--nomirror` (poses face their own way),
`--keepall`, `--ncol N` (directional sheets are narrow — 2 cols for a
windup+action), and `--flatten <name>` to pack all rows into one strip:

```bash
# clean 8-row sheet (one row per direction, 2 cols windup+stab):
python tools/art/extract_sheet.py --in "Assassin-Directions.png" \
  --out scratch/dir --class assassin --ncol 2 --nomirror --keepall --flatten stab_dir
```

**Partial (right-facing-only) sheets:** if the art only supplies the E/N/S side,
extract per-row (drop `--flatten`) and assemble the 8 directions yourself,
mirroring the east poses for W/NW/SW (see the throw assembly in git history: map
each compass dir → (row, flip), then concat 16 frames in E,NE,N,NW,W,SW,S,SE
order). Mirroring a windup+action pair is just a horizontal flip of both frames.

Install `<class>_<name>_dir.png`. Wiring: `Art.HERO_DIR_FILES` (name → suffix),
`DIR_POSE` in `player_core.gd` (which ability slot uses which), `play_dir_anim`
+ `_dir_index` (aim → direction, K auto = frames/8), `DIR_ANIM_DUR` (play speed).
The animation sets its own facing (flip suppressed) and hands back to idle. Add
another aim-critical attack by dropping a sheet + one `HERO_DIR_FILES` entry +
one `DIR_POSE` slot.

## Player vs. mobs/bosses — how much animates

- **Players** run the full clip state machine (`_advance_clip` in `player.gd`):
  idle/walk/run loop, one-shot attack/cast/dash/ult return to locomotion, death
  latches its last frame. Ability→clip mapping is `ABILITY_CLIP` in
  `player_core.gd` (tunable per class). On-screen size is body-height-based:
  `HERO_TARGET_BODY` / `HERO_FEET_ANCHOR` in `player_core.gd` — *this is the
  size fix; it scales by the measured body, not the padded frame box.*
- **Mobs & bosses** (`enemy.gd`) currently consume only the **idle strip**
  (`<name>_anim.png`) and **walk strip** (`<name>_walk.png`) + the static
  `<name>.png` — the classic sprite trio. So when you extract a creature sheet,
  the rows that matter are `idle` and `walk`; extra action rows are extracted and
  parked on disk but won't play until the enemy side gets its own clip machine.
  Enemies scale via `Art.scale_for` (frame-box based), so keep creature frames
  reasonably tight or bump their scale at the call site.

---

## Troubleshooting

- **Row count ≠ your `--names` length** → the row-band splitter merged/over-split
  rows. Rows are found by projecting the alpha mask on Y and splitting on gaps;
  tune `gap` in the `bands(...)` call (smaller = splits closer rows). The tool
  prints `<name>: N rows` — check it every run.
- **A label survives on one frame** → a pose merged a number/row-name into the
  character CC. Row-names only ever live in frame 0 (already dropped); a stray
  number means the digit-glyph gate missed it — widen the size/shape bounds in
  the number-removal block.
- **Green bleed / see-through** → two causes. (a) Semi-transparent pixels: the
  solidify step didn't run or the source had no alpha (solid bg not keyed). (b)
  Actual holes (`semi=0` but grass still shows) — the digit-removal ate embedded
  gold/hair; that's why it now requires a blob to be *floating*. If a gold-heavy
  creature still holes, loosen the `opq_frac < 0.30` isolation threshold.
- **Character too small / too big** → don't touch the extractor; it's a render
  knob. Players: `HERO_TARGET_BODY`. Enemies: the `scale_for` factor at the
  enemy sprite call site.
- **Animation plays backwards** (e.g. death runs pile→standing) → the source
  authored that row reversed. Reverse that strip's frame order at install time;
  the cleaned class sheets author forward, so no reversal was needed there.
- **Character flickers into a bolt / pool / arc** → a frame where the source drew
  ONLY the effect (no figure) and the extractor grabbed it. Three defenses, in
  order: (1) `pick_character` already prefers the tall/centred/feet-down figure
  over a fat FX blob when both are present; (2) frames that are just a short
  streak or empty are auto-swapped for the nearest real character frame (skipped
  for `death`, whose short frames are intentional); (3) a tall thin arc/beam that
  slips both — cut it explicitly with `--drop clip:frameindex` (e.g.
  `--drop attack2:3`), or best, get a source sheet that keeps the character in
  every frame (the cleanest fix — that's what the warlock re-do did).
- **Label-free sheet** (no baked row-names/numbers, e.g. a re-cleaned sheet) →
  add `--keepall` so frame 0 isn't dropped as a phantom label cell.
- **White/light outline around a sprite** (worst on dark ones like the assassin)
  → a light anti-alias halo the source left at low alpha; `solidify` made it
  opaque. Two defenses, both on by default: `--alpha 90` cuts the silhouette
  inside the fringe, and a de-halo pass recolours any outer-ring pixel that's
  lighter than its inner neighbour to the body colour (only fires on a light
  rim, so clean sprites are untouched). Raise `--alpha` further if a rim
  persists, but the de-halo usually handles it without eroding the figure.
- **Dark detail eaten near the background** (e.g. the archer's brown boot soles
  on the navy sheet — one foot read as half-cut in some idle frames) → the auto
  bg-key drops any pixel within colour-distance `--key` (default 45) of the
  sampled background, and a *dark* boot edge sits close to navy. Lower `--key`
  to spare it — the archer uses `--key 30`, which recovered ~half the boot
  pixels with a negligible (~30px) navy fringe. Go too low and a navy rim
  survives; 30 was the sweet spot here. Note `solidify`'s hole-fill only
  restores *enclosed* holes, so an eaten silhouette *edge* like a sole won't
  come back on its own — fix it at the key.
