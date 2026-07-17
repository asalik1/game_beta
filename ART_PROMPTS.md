# ART_PROMPTS — generation prompts for regenerated assets (opened 2026-07-16)

Sibling to `ART_TASKS.md`, not a replacement. **ART_TASKS is a claim-based
work board** (one owner per task, pack-art customization, the boss STRIP
MANIFEST). This file is a **prompt library**: the exact text to paste into an
image generator for each asset a resolution/quality audit has flagged, so the
art lane starts from a tightened prompt instead of re-deriving one.

## STATUS (2026-07-17)

The owner runs these through ChatGPT by hand and drops the renders in; an agent
cuts and installs them. **HuggingFace inference is dead** for this (410 on every
text-to-image model — it also broke `tools/art/flux_draft.py` and polligen's
`hf` backend), and Pollinations averages a 512px render into a 2-colour smear at
32x32. ChatGPT-by-hand is the lane.

| Asset | State |
|---|---|
| **Cover** | **DONE** — both variants installed and CYCLING (`cover.png` pixel + `cover_2.png` painterly, crossfade every 10s; cover.gd probes `cover_2..cover_8`, so a 3rd just drops in). |
| **Wordmark** | **MOOT — do not generate.** Engine-drawn now, in Cinzel Decorative. See below. |
| `ward_elixir`, `renewal_draught` | **DONE** — installed. |
| **All 24 ability icons** | **DONE** — installed 2026-07-17. Every class is on real art; the glyph table is now fallback-only. |
| `ability_warrior_a2` (Shield Bash) | **KEPT** — owner reviewed 2026-07-17, reads fine in-game. |
| `ability_assassin_a2` (Shadow Dash) | **DONE** — re-roll installed 2026-07-17 (dagger afterimage strobe; reads distinct from a1 at 24px). |
| `ability_paladin_ult` (Conviction) | **DONE** — re-roll installed 2026-07-17 (split holy/chained warhammer). |
| `ability_mage_a3` (Blink) | **DONE** — v3 installed 2026-07-17 (bolt cut + displaced mid-strike; the break survives 24px). v1's afterimage died at bar size; v2's "two bars" prompt got faithful meaningless geometry — the fix was giving the displacement a recognizable OBJECT. |
| `ability_archer_a3` (Tumble) | **DONE** — re-roll installed 2026-07-17. Warm leather-brown swoosh + speed ticks + dust; no longer a moon and now sits in the archer row's palette. |
| `ability_warlock_a1` (Shadowbolt) | **DONE** — re-roll installed 2026-07-17. Rim-carries-the-silhouette worked: ~2x the bright pixels of the first render (p90 lum 135 -> 152), reads as a ringed void at 24px. Still the darkest icon in the set ON PURPOSE — it is a void bolt; the fix was the silhouette, not the mood. |

**Two lessons the re-rolls encode.** (1) The generator ignores negatives ~1 in
12 — the assassin figure is that: check every render against `[NEGATIVES]`
BEFORE cutting, no downscale rescues a figure or a flat-value subject. (2) Don't
describe a game icon in UI-symbol terms — the paladin ult asked for "a refresh
symbol" and faithfully got UI chrome; that one was the prompt's fault, not the
model's.

**Cutting a render → a 32x32 icon** is done by script, not by hand, and the
background cut is the whole difficulty. ChatGPT returns **two different
backgrounds** and one mask cannot do both. Detect which by the border ring's
MINIMUM luminance:

* **GREY batch** (ring min ~34-85) — a soft grey gradient with a dark vignette.
  Flood inward from the border through **low-gradient, desaturated** territory;
  the subject's hard edge is a wall. Do NOT key on a fixed luminance band — the
  vignette's dark corners fall outside it and get welded onto the icon. That is
  what made the first batch read as mud.
* **WHITE batch** (ring min ~240+) — near-white, uniform, slightly noisy. The
  gradient test FAILS here: the noise shatters the passable region into ~4000
  fragments and the flood cannot spread (5% cut). And colour alone can't work
  either, because the subject is sometimes white too (the paladin's light rays).
  Use the art's own **dark outline as the wall**: flood from the border, barrier
  = luminance < 150. Not < 100 — some outlines run lighter, the flood finds the
  gap and swallows the interior (one label covering 94% of the canvas, leaving a
  "subject" of eroded outline crumbs). That exact failure ate the paladin shield.

Then, both batches: keep every blob above ~2% of the largest — **not** just the
largest, because Arrow Storm is a volley of disjoint arrows and largest-only
leaves exactly one. Box-downscale in **premultiplied** alpha (otherwise the cut
background bleeds a halo into the edge), hard-alpha at 128, and quantise to ~12
colours to match the family, which has ZERO semi-transparent pixels.

**Judge at 24px, not at 8x.** The action bar is 24px; an icon that reads
beautifully zoomed can be mud at true size. Build a contact sheet at the real
size before installing.

Same discipline as `tools/art/PIXELLAB_PROMPT_LESSONS.md` (PixelLab lane):
loose prompts cost re-rolls. Every prompt below names the exact subject +
composition, the exact target resolution, a palette anchored to hexes
**sampled from the real asset**, a style anchor, and explicit negatives.

---

## Why these are flagged (the evidence)

`cover.png` is 1280x720 on disk but it is **exactly a 4x nearest-neighbour
upscale of a 320x180 image** — measured, not guessed: 0.00% of its 57,600
4x4 pixel blocks are non-uniform (at 8x8, 80% are). **The file carries 320x180
of real information.** It has no more detail than a 320x180 PNG.

The engine then magnifies that:

| Display | canvas_items scale | one authored pixel becomes |
|---|---|---|
| 1280x720 | 1.0x | 4x4 screen px |
| 1920x1080 | 1.5x | 6x6 screen px |
| 2560x1440 | 2.0x | 8x8 screen px |
| 3840x2160 | 3.0x | 12x12 screen px |

That is the "home screen looks pixelated" complaint, quantified. It is not a
filter bug and not a stretch bug — **the art is 320x180.** No code change and
no import setting can add detail that was never authored.

---

## COVER — `game/assets/sprites/cover.png` — REGENERATE

**Target: 2560x1440** (16:9). At 1440p that is 1:1; on 1080p it is a clean
0.75x downscale and on 4K a 1.5x upscale — both handled by the filter fix now
in `scripts/ui/cover.gd`. 3840x2160 is also accepted by the code if you have a
good upscale path; do not go below 2560x1440.

**The code accepts any resolution with no further changes.** `cover.gd` loads
the PNG via `load()` and hands it to a `TextureRect` with `EXPAND_IGNORE_SIZE`
— the texture's own size is ignored and it is stretched to the rect. Nothing
resizes or resamples the source. Just drop the new file in at the same path.

### Generator ceiling — read this before you start

ChatGPT's image model maxes out at **1536x1024** for landscape. You cannot ask
it for 2560x1440 directly. Workflow:

1. Generate at **1536x1024**, composing for a 16:9 safe area (the prompt below
   tells it to).
2. Crop to **1536x864**.
3. Upscale to **2560x1440** (1.67x — modest, and the source is real detail,
   not 4x-duplicated blocks).

Even stopping at step 2 is a **4.8x-per-axis information gain** over today's
320x180. The pixelation complaint dies at step 2; step 3 is polish.

### The wordmark — SETTLED 2026-07-17: never generate it

This was flagged as the most likely failure (generators mangle letterforms).
It's now moot, and the resolution went further than "budget re-rolls":

> **Generate the scene with NO text. The engine draws the wordmark.**
> `cover.gd` `_wordmark()` draws "CROWNLESS" / "The Hollow King" on BOTH the
> procedural set and the hand-made cover, via `UITheme.logo()` in **Cinzel
> Decorative** (OFL). Vector text is perfectly crisp at every resolution
> forever, it costs nothing to retitle — which was worth real money the week
> the game stopped being called Emberfall — and text is the single element
> that reads worst when the art is magnified. The old cover baked it in and
> carried 320x180 of real information, so the logo was the first thing to fall
> apart.

Every cover prompt here is written text-free. **The `[WORDMARK]` block below is
retained only as a record of the road not taken — do not use it.**

### Palette anchor (sampled from the real cover.png)

| Role | Hex |
|---|---|
| Night sky, upper corners | `#130D25` |
| Sky wash behind the crown | `#52363F` |
| Crown gold (dominant) | `#EEBF73` |
| Crown outline / near-black | `#110B09` |
| Horizon glow, warm | `#D47444` |
| Hill silhouette rim | `#9D5259` |
| Ground band | `#291818` |
| Mid violets | `#281939` `#1F142B` `#38213B` |
| Wordmark highlight (cream) | `#FFF6D2` |
| Wordmark deep (orange) | `#D77626` |

### PROMPT — Variant A (RECOMMENDED: stays pixel art, finer grid)

Faithful to the current cover and to the game's identity — the whole game is
pixel art. Same composition, roughly 2x the detail per axis.

```
Pixel art title-screen illustration for a dark fantasy game, 16:9 landscape,
somber dark fantasy mood. Detailed pixel art on a fine, consistent pixel grid
— crisp hard-edged pixels, no anti-aliasing, no soft airbrush gradients; use
ordered dithering for all gradients.

COMPOSITION, top to bottom, centred and symmetrical:
- Upper half: a deep indigo-violet night sky (#130D25), scattered small white
  stars, denser toward the top corners, a few brighter than the rest.
- Centre, upper-middle: a large golden crown floating in mid-air, seen
  front-on, filling roughly the middle third of the frame's width. It has five
  tall tapering spires; each spire tip carries a small orange flame. Four
  round gems are set across the crown's band, left to right: red, green, blue,
  purple. The crown is warm gold (#EEBF73) with a hard near-black outline
  (#110B09) and a soft warm bloom halo behind it.
- Four small coloured ember motes orbit the crown at its corners — one blue,
  one green, one purple, one orange — each a tiny bright core in a soft glow.
- Behind and below the crown: a warm orange horizon glow (#D47444) rising from
  behind a low dark hill, as if a fire burns just over the ridge.
- On the hill's crest: the small silhouette of a broken ruined tower.
- Mid-ground: layered dark violet hill silhouettes (#38213B, #281939).
- Far left edge and far right edge: one tall dead bare tree silhouette each,
  framing the frame, near-black.
- Lower third: a dark ground band (#291818), noticeably darker than the sky,
  with small orange ember motes floating upward through it, some blurred, some
  bright.

PALETTE: strictly deep indigo-violet (#130D25, #1F142B, #281939, #38213B),
warm gold (#EEBF73), ember orange (#D47444, #D77626), near-black (#110B09).
Cool dark sky against a single warm light source at the horizon.

SAFE AREA: keep the crown and the horizon inside the middle 84% of the frame
and keep the LOWER THIRD visually calm and uncluttered — a title wordmark will
be composited over it later. Compose so the image still reads when cropped
from 3:2 to 16:9 (trim top and bottom).

NEGATIVES: no text, no letters, no words, no title, no logo, no wordmark, no
signature, no watermark, no characters, no people, no human figures, no
creatures, no UI, no buttons, no frame, no border, no vignette, not painterly,
not photorealistic, not 3D-rendered, no soft blur, no anti-aliased edges, no
chromatic aberration, no lens flare.
```

### PROMPT — Variant B (alternative: painterly)

Use **only** if you decide the title screen should match the class splashes
(`class_splash_*.png` are painterly illustrations, not pixel art) rather than
the in-game art. This is a **look change**, not an upscale — the audit does not
recommend it, but it is the one style that makes the pixelation question moot
permanently.

```
Painterly digital illustration, title-screen key art for a dark fantasy game,
16:9 landscape. Moody, atmospheric, somber dark fantasy; loose confident oil-
paint brushwork, dramatic single-source lighting, high contrast, muted palette.

[same COMPOSITION block as Variant A]

PALETTE: deep indigo-violet night (#130D25, #281939, #38213B) against warm
gold (#EEBF73) and ember orange (#D47444). One warm light source at the
horizon; everything else falls to near-black (#110B09).

SAFE AREA: keep the crown and horizon inside the middle 84%; keep the lower
third calm for a composited wordmark. Must survive a 3:2 -> 16:9 crop.

NEGATIVES: no text, no letters, no words, no title, no logo, no watermark, no
signature, no characters, no people, no creatures, no UI, no border, no
vignette, not pixel art, not cel-shaded, not anime, no photorealism, no lens
flare, no chromatic aberration.
```

### `[WORDMARK]` — SUPERSEDED, kept as a record. Do not use.

The engine draws the wordmark (see "The wordmark — SETTLED" above). Baking text
into the PNG is now the wrong path twice over: the spelling needs re-rolls, and
a baked logo would have had to be REGENERATED when the game was renamed from
Emberfall to Crownless — which is exactly what happened, one day after this
block was written. It is left here so the next person can see the decision
rather than re-open it.

```
Across the lower-centre of the frame, the single word "EMBERFALL" in large
blocky pixel-art capital letters, spelled exactly E-M-B-E-R-F-A-L-L, spanning
about 80% of the frame width. Each letter is filled with a vertical gradient
from pale cream at the top (#FFF6D2) to deep ember orange at the bottom
(#D77626), with a hard near-black outline and a subtle drop shadow. Directly
beneath it, much smaller, the words "THE HOLLOW KING" in warm pale grey pixel
capitals with wide letter spacing. No other text anywhere in the image.
```

---

## Do NOT regenerate — verified fine

Listed so nobody burns generations on them.

- **`class_splash_*.png` (all six).** Painterly illustrations, on screen for
  ~1.15s during a fade-in, and drawn fit-to-height (720px canvas = 1080/1440/
  2160px on screen). The 768px four (archer, paladin, warlock, warrior) were
  magnified 1.4x–2.8x under the project's global NEAREST filter, which is what
  made them read blocky — that is **fixed in code** (`menus.gd`, per-node
  LINEAR_WITH_MIPMAPS). Painterly art tolerates soft magnification; nearest
  stair-steps were the actual defect. The 768-vs-1024 inconsistency is
  cosmetic — both are fit to the same 720px height, so the size difference has
  no on-screen consequence. Regenerating risks losing art that is genuinely
  good, for a beat that lasts one second.
- **`phantom_splash.png` (1280x720).** A transient ult flash — 0.85s, tweened
  out, drawn at ~0.1–0.3 opacity over gameplay. Resolution is irrelevant at
  that opacity and duration.
- **All 2,300+ world sprites and animation strips** (hero/mob/boss/skin, frames
  ~207–242px). Deliberately low-res pixel art, rendered *below* native via
  `Balance.CHAR_RENDER_SCALE`. Downscaled, not upscaled — correct by design.
  See the `hero-sprite-downscale-mipmaps` note; do not "fix" these.
- **All 48 UI icons** (`assets/icons/`, 24x24 and 32x32). Used at native size
  per `Art.ui_icon`; integer-nearest magnification is the intended pixel look.

---

# CONSUMABLE ICONS — 2 MISSING FILES — CREATE (added 2026-07-16, icon-audit lane)

> **Not in tension with "All 48 UI icons — verified fine" above.** That entry
> covers the icons that *exist*. These two **do not exist at all** — they are
> the owner-reported "missing icon" bug. Nothing is being regenerated here;
> two new files are being authored into an established family.

## Why these are flagged (the evidence)

`Elixir of Warding` and `Draught of Renewal` are **fully live content** —
stocked by merchants (`menus.gd:2673`), priced (`balance.gd:1041-1042`), and
working (`player_core.gd:1413`, `:1419`) — but they had **no icon at either
end of the seam**:

1. **No id→file mapping.** `Art.CONSUMABLE_ICONS` (`art.gd:1993`) listed only
   5 of the 7 consumable ids. **Fixed in code 2026-07-16** — the two entries
   are now mapped to the file names below.
2. **No PNG.** `game/assets/icons/` has no `ward_elixir.png` /
   `renewal_draught.png`. **This is the remaining half — that's this section.**

Until the PNGs land, `Art.consumable_icon()` returns null and every call site
falls back to the `⟲` glyph (verified at `menus.gd:1465`, `pickup.gd:111`,
`ui/mailbox.gd:118`, `hud.gd:1303`, `ui/touch_hud.gd:219`) — so the mapping is
safe to ship ahead of the art. Dropping the PNGs in **requires no code
change**: `Art._icon_override` picks them up by name.

**File names (exact — the code already points at these):**

| Item | id | **file to create** |
|---|---|---|
| Elixir of Warding | `elixir_ward` | `game/assets/icons/ward_elixir.png` |
| Draught of Renewal | `renewal_draught` | `game/assets/icons/renewal_draught.png` |

Names follow the existing `<descriptor>_<vessel>` convention (`mana_draught`,
`might_elixir`).

## The family they must join (measured, not guessed)

Sampled from the real files with PIL. The consumable icons are a **tight,
consistent family** and these two must read as siblings:

| Property | Measured value |
|---|---|
| Canvas | **32x32** RGBA, transparent background |
| Colour count | **6–13 distinct colours per icon** (mana_draught: 13, might_elixir: 12, potion: 12, recall_scroll: 6) |
| Outline | **`#2E1C2C`** — a hard 1px near-black desaturated plum, fully closed around the silhouette. Identical across `mana_draught`, `might_elixir`, `potion`. (`recall_scroll` uses `#2E222F`.) |
| Anti-aliasing | **None.** Flat colour blocks in large runs; no gradients, no dithering, no soft edges. |
| Specular | A pure **`#FFFFFF`** glint — on the flasks it is a *vertical dotted run of 1px pips* down the upper-left of the bulb. |
| Fill | Occupies most of the canvas — flasks span `x[4..27]`, full height. |

**The two flask siblings** (`mana_draught.png`, `potion.png`) share one exact
silhouette language, and that is the shape to match:

> A **bulbous rounded flask** — wide, near-circular body sitting on a flat
> base, shoulders curving in to a **short straight neck**, closed by a
> **horizontally banded cap**. Liquid rendered as a **3-step ramp**
> (bright body / mid shade / dark shade) plus 1–2 light tints, one white
> specular run, and a warm accent on the cap.

Ramp, sampled:

| Icon | dark | mid | bright | light tints | accent |
|---|---|---|---|---|---|
| `mana_draught` | `#224D7F` | `#1E6FCB` | `#3895FF` | `#82BCFF` `#90C4FF` | `#FF9148` cap |
| `potion` (health) | `#7F2222` | `#CB1E31` | `#FF3838` | `#FFA990` | `#E86838` cap |

> `might_elixir` is deliberately **not** the model here — it is a tipped
> wide-mouth vial with a foam splash, an outlier in the family. Match
> `mana_draught` / `potion`.

## Semantic + palette anchors (from the game's own colour language)

Not invented — taken from what the game already says these effects look like:

| | Elixir of Warding | Draught of Renewal |
|---|---|---|
| Effect | `dr_time`/`dr_amt` — **damage reduction**, a barrier | `gain_hp(max_hp * frac)` — **instant big heal** |
| Floating text | `"WARDED!"` **`#80CCFF`** (`player_core.gd:1418`) | `"RENEWED"` **`#80FF99`** (`player_core.gd:1426`) |
| Matching buff icon | `buff_ward.png` = a **blue shield** — `#00ADED` `#7BDCFF` `#547BC5` | `buff_heal.png` = a **green heart** — `#4B9479` `#9DBA97` `#BEC8A2` |

**The 32px distinctness problem, and the fix.** Ward is semantically blue, and
`mana_draught` is *already* a blue flask (`#3895FF`). Hue alone will not
separate them at 32px. So each new icon is separated on **three** axes at once:

- **Ward** → *cyan* (not royal blue) + an **angular shield-shaped bottle**
  (not the round teardrop) + a **shield emblem** + a **steel** band (not
  mana's orange cap).
- **Renewal** → **green**, a hue no other consumable uses → already distinct;
  plus a **heart emblem** and a **cork** stopper.

---

## PROMPT — `ward_elixir.png` (Elixir of Warding)

```
A single 32x32 pixel-art potion icon for a dark fantasy RPG inventory, centred
on a fully transparent background.

SUBJECT: a squat, angular, faceted glass flask shaped like a heater shield —
broad flat shoulders tapering to a rounded point at the bottom, standing
upright. It is filled with a glowing pale ice-cyan liquid. The neck is short
and straight and is closed by a horizontally banded STEEL cap — flat grey
metal, three stacked bands. Embossed on the front of the glass, centred, is a
small solid SHIELD emblem in bright white-cyan, clearly readable as a shield.
A faint cyan barrier shimmer sits inside the glass behind the emblem.

STYLE: hard-edged pixel art on a strict 32x32 grid — every pixel square and
aligned. Flat blocks of colour only. NO anti-aliasing, NO gradients, NO
dithering, NO soft edges, NO blur. A hard 1px outline of dark desaturated plum
(#2E1C2C) fully closed around the entire silhouette, including the cap. Use no
more than 12 distinct colours in total.

PALETTE (use these exact hexes):
- outline: #2E1C2C
- liquid, dark shade: #547BC5
- liquid, mid: #00ADED
- liquid, bright body: #7BDCFF
- liquid, light tint: #BFEFFF
- shield emblem + specular: #FFFFFF
- steel cap, light: #CBE4DA
- steel cap, mid: #A7BCC2
- steel cap, dark: #9A879F

SHADING: light comes from the upper LEFT. Render the liquid as three flat
bands — bright #7BDCFF on the upper left, #00ADED through the middle, #547BC5
pooled along the lower right. Add a vertical run of 3 single-pixel #FFFFFF
specular pips down the upper-left curve of the glass.

COMPOSITION: the flask fills the canvas — about 24 of the 32 pixels wide and
nearly the full 32 tall, centred, standing on a flat base.

NEGATIVES: no text, no letters, no numbers, no border, no frame, no card, no
background, no drop shadow on the ground, no sparkles, no starbursts, no hand,
no table, no anti-aliasing, no gradient, no dithering, no noise, no royal blue
or navy (it must NOT read as the existing blue mana potion), no purple, no
gold, no brass, no orange, not 3D, not rendered, not painterly, no outline
colour other than #2E1C2C.
```

## PROMPT — `renewal_draught.png` (Draught of Renewal)

```
A single 32x32 pixel-art potion icon for a dark fantasy RPG inventory, centred
on a fully transparent background.

SUBJECT: a bulbous rounded glass flask — a wide, near-circular body sitting on
a flat base, shoulders curving inward to a short straight neck, standing
upright. It is brimming with a vivid, luminous green liquid filled almost to
the neck. The neck is closed by a rounded BROWN CORK stopper. Embossed on the
front of the glass, centred, is a small solid HEART emblem in pale white-green,
clearly readable as a heart.

STYLE: hard-edged pixel art on a strict 32x32 grid — every pixel square and
aligned. Flat blocks of colour only. NO anti-aliasing, NO gradients, NO
dithering, NO soft edges, NO blur. A hard 1px outline of dark desaturated plum
(#2E1C2C) fully closed around the entire silhouette, including the cork. Use
no more than 12 distinct colours in total.

PALETTE (use these exact hexes):
- outline: #2E1C2C
- liquid, dark shade: #38645F
- liquid, mid: #4B9479
- liquid, bright body: #80FF99
- liquid, light tint: #BEC8A2
- heart emblem + specular: #FFFFFF
- cork, light: #D7BE92
- cork, mid: #B88F48
- cork, dark: #705C4A

SHADING: light comes from the upper LEFT. Render the liquid as three flat
bands — bright #80FF99 on the upper left, #4B9479 through the middle, #38645F
pooled along the lower right. Add a vertical run of 3 single-pixel #FFFFFF
specular pips down the upper-left curve of the glass, matching the existing
blue mana flask.

COMPOSITION: the flask fills the canvas — about 24 of the 32 pixels wide and
nearly the full 32 tall, centred, standing on a flat base.

NEGATIVES: no text, no letters, no numbers, no border, no frame, no card, no
background, no drop shadow on the ground, no sparkles, no starbursts, no hand,
no table, no anti-aliasing, no gradient, no dithering, no noise, no red, no
blue, no teal, no gold, no brass, not 3D, not rendered, not painterly, no
outline colour other than #2E1C2C.
```

## Post-process (required — the generator will not give you a clean 32x32)

ChatGPT will return a large canvas (~1024px), soft-edged, with far more than
12 colours. Do not install that. For each:

1. **Generate at 1024x1024**, then crop tight to the flask's bounding box.
2. **Nearest-neighbour downscale to 32x32.** If the generated pixel grid is not
   32-aligned, scale to a multiple first (e.g. 512 → 32 is 16px/cell) and check
   the cells land square.
3. **Snap to the palette** — quantize every pixel to the exact hex list above.
   Anything not on the list is a generator artifact.
4. **Rebuild the outline** as a hard closed 1px `#2E1C2C` ring; force fully
   transparent (alpha 0) outside it. No semi-transparent alpha anywhere —
   the family has none.
5. **Verify against the family** before installing: put the new icon beside
   `mana_draught.png` and `potion.png` upscaled ~10x and confirm it reads as a
   sibling and is unmistakable from the blue mana flask at true 32px.

Install: drop into `game/assets/icons/`, let Godot import, done — the code
already maps both ids. (Re-sync `mobile/game/assets/icons/` per CLAUDE.md.)

---

# ABILITY ICONS — 24 MISSING FILES — CREATE (added 2026-07-16, ability-icon lane)

> **Not in tension with "All 48 UI icons — verified fine" above.** That entry
> covers the icons that *exist as PNGs*. The 24 ability icons **are not files
> at all** — they are hand-typed ASCII art inside `art.gd`. Nothing is being
> regenerated here; 24 new files are being authored into an established family.

## Why these are flagged (the evidence)

The ability bar's icons are the last procedural art in the UI. They are not
sprites — `Art.ABILITY_GLYPH` (`art.gd:1669`) maps class+slot to a glyph name
into a `GLYPHS` dict of **12x12 ASCII pixel-string rows**, where `k` = outline,
`w` = tint, `y` = gold:

```
"ic_hp": [ "..kk...kk...", ".kwwk.kwwk..", ".kwwwkwwwk..", ... ]
```

`Art.glyph_tex()` paints those strings into a **12x12** image and `resize()`s
it **2x NEAREST to 24x24**. Measured consequences:

| Property | Ability glyph (today) | Rest of `assets/icons/` |
|---|---|---|
| Authored resolution | **12x12** | **32x32** |
| Colours | **3** (`k` outline, `w` tint, `y` gold) | **6–13** |
| Shading | none — a 2-colour stencil | 3-step ramp + white specular |
| Source | ASCII rows in a `.gd` file | Raven Fantasy Icons pack art |

**That is the "rudimentary" complaint, quantified.** A 12x12 3-colour stencil
sits directly beside 32x32 pack art — the potion slot at the end of the same
bar is a real `potion.png`. No code change fixes this; the art is 12x12.

## The seam is BUILT — art drops in with no code change (2026-07-16)

Already landed, so this section is art-only. File names (exact — the code
already looks for these):

| File | Ability |
|---|---|
| `game/assets/icons/ability_warrior_a1.png` | Cleave |
| `game/assets/icons/ability_warrior_a2.png` | Shield Bash |
| … | (`ability_<class>_<slot>.png`, slots `a1` `a2` `a3` `ult`) |

`Art.ability_icon(cls, slot, tint)` returns hand art when the file exists and
falls back to the tinted glyph when it does not — exactly the `ui_icon()` /
`consumable_icon()` pattern. All five call sites are converted (`hud.gd`,
`menus.gd` x3, `ui/touch_hud.gd`). **Drop the PNG in, it appears.** Partial
delivery is safe: any subset of the 24 can land and the rest keep their glyph.

### Hand art is used UNTINTED — and where the theme colour went

The glyph is a 2-colour stencil, so the ability-theme tint **is** its art. A
painted 32x32 icon carries its own palette, and modulating a theme colour
through it washes the whole thing to one hue — which is the look being
replaced. So `ability_icon()` returns hand art as-is, matching the documented
`consumable_icon()` rule.

The theme signal is **not lost, it moved to text**:

- **Skills menu** (`menus.gd`) — no change needed. It already passed the same
  `tcolor` as the button's `font_color`; the icon tint was redundant there.
- **Ability bar** (`hud.gd`) — the ability **name** under the slot now paints
  in the theme colour *when hand art is installed* (white otherwise, so today's
  all-glyph look is byte-identical).
- **Paladin ult** keeps its stance readout — the name still reads `◆ HOLY` in
  gold; only the glyph takes the stance modulate.
- **Touch HUD** (`ui/touch_hud.gd`) — **known gap, flagged for the owner.** The
  touch arc has no name label, so once hand art lands the theme colour has no
  carrier there. Its `modulate` is a cooldown/afford *dim*, which is fine on
  art. Needs an owner call (small theme pip? coloured ring? accept the loss?).

## Why these are ChatGPT prompts and not generated (tested 2026-07-16)

Per the `art-generation-tiers` rule the HuggingFace → Pollinate ladder was
tried first, on warrior/a1. **Both failed; do not retry them for icons.**

- **HuggingFace inference: dead lane, not a quality problem.** Every
  text-to-image model 410s with `"The requested model is deprecated and no
  longer supported by provider hf-inference"` (FLUX.1-schnell — the model
  `tools/art/flux_draft.py` and `polligen.py`'s `hf` backend both hard-code —
  plus SDXL and FLUX.1-dev), and the provider router advertises **zero**
  image-output models for our token. `flux_draft.py` and polligen's `hf`
  backend are **both broken at HEAD** and will need a new model/provider
  whenever the concept-draft lane is next used.
- **Pollinations: generates, output unusable at 32px.** It returns a 512px soft
  illustration; the 512→32 downscale averages the thin blade into an
  anti-aliased grey smear — **2 distinct colours, no outline, no hilt** — i.e.
  strictly *worse* than the 12x12 glyph it would replace. Confirmed this is the
  resolution mismatch and not `polligen.strip_bg` by re-running with
  `kind=tile` (no flood fill): still a smear. It also silently dropped the
  "slash arc" clause twice. This matches `polligen.py`'s own docstring — it is
  the walls/props lane.

**The owned pack was checked first, per the asset-library rule.** Raven Fantasy
Icons (`OneDrive/Assets/Visuals`, the *same purchased pack* the rest of
`assets/icons/` comes from — 2192 icons at 32x32) is a **gear/consumable/status**
pack. It covers maybe 6–8 of the 24 slots (`fb664` shield, `fb2154` arrow,
`fb656` X, `fb670` holy cross, `fb651` running figure, `fb705` chain) and has
**nothing** for the distinctive ones — Multishot, Arrow Storm, Whirlwind, Hex,
Shadowbolt, Dark Pact, Void Rift. Its magic art is unoutlined VFX glow strips,
a different style from the outlined-object icons we ship, and its two usable
shields (`fb664`/`fb665`) would **collide** as Shield Bash vs Aegis at HUD
size. A half-Raven set is worse than a coherent authored one — so the pack is
used here as the **palette + style anchor**, not the source.

## The family they must join (measured, not guessed)

Sampled from the real files with PIL:

| Property | Measured value |
|---|---|
| Canvas | **32x32** RGBA, transparent background |
| Colour count | **8–13 distinct colours** (`w_bow` 8, `w_hammer` 8, `w_claymore` 8, `buff_ward` 9, `w_staff` 11) |
| Outline | **`#2E1C2C`** on gear/weapons, **`#432D40`** on the buff/status set — hard 1px, fully closed |
| Anti-aliasing | **None.** Flat colour blocks; no gradients, no dithering, no soft edges |
| Specular | A pure **`#FFFFFF`** glint, usually 1px pips on the upper-left |
| Gamma | Pack art is lifted **gamma 0.78** before install (see `assets/icons/CREDITS.txt`) — raw pack art reads too dark/pale in-game |

### Shared palette (the pack's own ramps — use these, do not invent hues)

| Role | Hexes |
|---|---|
| Outline | `#2E1C2C` (primary) · `#432D40` (status set) |
| Steel / bone ramp | `#724E63` → `#86718C` → `#95ADB4` → `#BFDDD1` → `#FFFFFF` |
| Warm / fire / gold | `#E86838` `#EC7E4E` `#FF9148` `#FFA45F` `#FFC762` `#FFA900` `#FFCE00` |
| Cold / arcane | `#547BC5` `#00ADED` `#7BDCFF` `#BFEFFF` |
| Green / poison | `#38645F` `#4B9479` `#9DBA97` `#BEC8A2` |
| Blood / red | `#8D2C44` `#A0405A` `#C4594B` `#CB1E31` `#FF3838` |
| Wood / leather | `#705C4A` `#B88F48` `#D7BE92` |

## How to use this section

All 24 share one **STYLE** block and one **NEGATIVES** block — stated **once**,
below. For each icon, paste:

> `[STYLE]` + its own `SUBJECT` + its own `PALETTE` + `[NEGATIVES]`

### `[STYLE]` — prepend to every one of the 24

```
A single 32x32 pixel-art ability icon for a dark fantasy RPG action bar,
centred on a fully transparent background, viewed flat and orthographic.

STYLE: hard-edged pixel art on a strict 32x32 grid — every pixel square and
aligned. Flat blocks of colour only. NO anti-aliasing, NO gradients, NO
dithering, NO soft edges, NO blur, NO glow bloom. A hard 1px outline of dark
desaturated plum (#2E1C2C) fully closed around the entire silhouette. Use no
more than 12 distinct colours in total. Shade every form as a 3-step ramp
(bright / mid / dark) with light from the upper LEFT, plus a few single-pixel
#FFFFFF specular pips on the upper-left edge.

COMPOSITION: one single object, centred, filling about 26 of the 32 pixels —
it must read instantly at true 32x32 in a 24px action-bar slot. Bold silhouette
first: no thin 1px filaments, no fine tracery, no small floating details.
```

### `[NEGATIVES]` — append to every one of the 24

```
NEGATIVES: no text, no letters, no numbers, no runes, no border, no frame, no
card, no rounded-rectangle badge, no background, no ground shadow, no scene, no
landscape, no hand, no arm, no character, no full figure, no UI chrome, no
anti-aliasing, no gradient, no dithering, no noise, no glow bloom, no lens
flare, no chromatic aberration, not 3D, not rendered, not painterly, not
photorealistic, no outline colour other than #2E1C2C.
```

---

## WARRIOR

### `ability_warrior_a1.png` — Cleave
*Swing your blade at the nearest enemy; a measured, plated swing (Berserk unchains its speed).*
```
SUBJECT: a broad steel BROADSWORD, blade angled diagonally from lower-left to
upper-right, with a single thick crescent SLASH ARC sweeping across and behind
it — the arc is a bold tapering white-to-steel wedge, wide at its middle, not a
thin line. The sword is the solid anchor; the arc is one clean stroke.
PALETTE: outline #2E1C2C; blade ramp #86718C / #95ADB4 / #BFDDD1 with a #FFFFFF
edge; hilt and grip #705C4A with a #FFC762 pommel; slash arc #FFFFFF core
fading to #BFDDD1.
```

### `ability_warrior_a2.png` — Shield Bash
*Charge forward ramming everything in your path: damage, knockback, 1.3s STUN.*
```
SUBJECT: a heavy steel kite SHIELD seen face-on but TILTED and driving forward
— slightly foreshortened, its leading edge bigger and brighter, with three
short blunt IMPACT WEDGES (thick chevrons) trailing behind it to read as a
charge. A hard white impact flash sits on the leading rim. The shield is plain
and riveted: a broad boss in the centre, studs around the rim. It must read as
a RAM, not a raised guard — this is the deliberate opposite of Aegis.
PALETTE: outline #2E1C2C; shield ramp #724E63 / #86718C / #95ADB4 / #BFDDD1;
rivets and boss #FFC762; impact flash #FFFFFF; motion wedges #86718C.
```

### `ability_warrior_a3.png` — Whirlwind
*Damage everything around you.*
```
SUBJECT: a full circular SPIN — one steel sword blade at the top-right of a
closed circular sweep, with the sweep drawn as a thick tapering RING of slash
trailing all the way around and spiralling once. The ring is the subject and
the blade rides it; the centre is empty. It must read as a 360-degree sweep,
distinct from Cleave's single arc.
PALETTE: outline #2E1C2C; blade #95ADB4 / #BFDDD1 / #FFFFFF; hilt #705C4A;
sweep ring #FFFFFF at the blade, tapering back through #BFDDD1 to #86718C.
```

### `ability_warrior_ult.png` — Berserk
*8s: +40% damage, +25% speed, 15% lifesteal — rage.*
```
SUBJECT: a clenched armoured FIST punching straight toward the viewer, gauntlet
plates across the knuckles, wreathed in a thick ragged RAGE FLAME licking up
behind it. Bold and frontal. (The buff chip for this effect is buff_atk.png, a
flexed arm — this is its sibling, not a copy: a fist, not an arm.)
PALETTE: outline #2E1C2C; gauntlet steel #724E63 / #86718C / #95ADB4; knuckle
highlights #BFDDD1 / #FFFFFF; rage flame ramp #C4594B / #E86838 / #EC7E4E /
#FFA45F with #FFC762 tips.
```

## ARCHER

### `ability_archer_a1.png` — Quick Shot
*Fire an arrow at the nearest enemy. (Fast — 0.36s.)*
```
SUBJECT: a single ARROW flying diagonally from lower-left to upper-right,
broadhead leading, with a short crisp speed streak behind the fletching. Thick
shaft, clearly readable head and feathers — a bold single arrow, not a thin
needle.
PALETTE: outline #2E1C2C; shaft #B88F48 / #D7BE92; steel broadhead #95ADB4 /
#BFDDD1 / #FFFFFF; fletching #C4594B / #EC7E4E; speed streak #BFDDD1.
```

### `ability_archer_a2.png` — Multishot
*Fan of 5 arrows.*
```
SUBJECT: exactly FIVE arrows fanning outward from a single point at the
lower-left, spreading to the upper-right like a hand of cards — even angular
spacing, all broadheads leading, the centre arrow longest. The FAN SHAPE is the
whole idea and must read at a glance; keep the arrows thick and clearly
separated, never overlapping into a blob.
PALETTE: outline #2E1C2C; shafts #B88F48 / #D7BE92; steel broadheads #95ADB4 /
#BFDDD1 / #FFFFFF; fletchings #C4594B / #EC7E4E.
```

### `ability_archer_a3.png` — Tumble  (RE-ROLL 2026-07-17)
*Dodge-roll with a split-second perfect-dodge window, then +20% evasion 1.25s.*
The first render kept the roll-comma silhouette but dropped the dust puffs (the
generator's habit of shedding clauses) — and the prompt's own silver-steel
palette did the real damage: a bare silver crescent IS a moon. The silhouette
was never the problem, so this keeps it and changes hue + motion cues only:
wood-brown like the rest of the archer row, with the speed ticks and dust made
load-bearing instead of optional garnish.
```
SUBJECT: a bold curved MOTION SWOOSH shaped like a forward roll — a thick
tapering comma sweeping from lower-right up and over to lower-left, its empty
centre intact. THREE short straight SPEED TICKS trail off its outer edge at its
midpoint, and a cluster of 3-4 small square DUST PUFFS sits at its landing end,
kicked up where the roll finishes. The ticks and dust are REQUIRED elements,
the same visual weight as the swoosh's tail — an icon without them is wrong.
It must read as tumbling motion, NOT a crescent moon: no face, no stars, no
night-sky framing, warm earthy colour only.
PALETTE: outline #2E1C2C; swoosh ramp warm leather-brown #705C4A / #9C7A54 /
#C9A876 with a #F0E3C0 leading edge; speed ticks #9C7A54; dust puffs #86718C /
#C9A876.
```
### `ability_archer_ult.png` — Arrow Storm
*3s: arrows rain on every enemy near you.*
```
SUBJECT: FIVE arrows falling steeply DOWNWARD in parallel, broadheads pointing
down at the bottom of the icon, at staggered lengths and heights so they read
as a volley in flight, with three small impact marks on an implied ground line
at the very bottom. Rain-from-above is the idea — the opposite reading from
Multishot's outward fan.
PALETTE: outline #2E1C2C; shafts #B88F48 / #D7BE92; steel broadheads #95ADB4 /
#BFDDD1 / #FFFFFF; fletchings #C4594B / #EC7E4E; impact marks #86718C.
```

## MAGE

### `ability_mage_a1.png` — Firebolt
*Hurl a bolt at the nearest enemy.*
```
SUBJECT: a single compact FIREBALL hurtling diagonally from lower-left to
upper-right — a dense round burning core at the leading edge with a short
ragged flame tail streaming behind it. Chunky and solid, one clear mass.
PALETTE: outline #2E1C2C; core #FFFFFF into #FFCE00; body ramp #FFC762 /
#FFA45F / #EC7E4E; tail edges #E86838 / #C4594B.
```

### `ability_mage_a2.png` — Frost Nova
*Blast around you: knocks enemies away, SLOWS 50%, restores 20% missing HP/MP.*
```
SUBJECT: a burst of angular ICE SHARDS radiating OUTWARD from a small bright
centre — six thick faceted spikes of pale ice pointing outward in a ring, the
lower ones longer, with a hexagonal frost ring implied between their bases. It
must read as an outward SHOCKWAVE from the centre, not a snowflake ornament:
keep the spikes thick and wedge-shaped.
PALETTE: outline #2E1C2C; ice ramp #547BC5 / #00ADED / #7BDCFF / #BFEFFF;
centre flash #FFFFFF.
```

### `ability_mage_a3.png` — Blink  (RE-ROLL v3, 2026-07-17)
*Dash in your move direction, shocking everything in your path; brief i-frame + 50% DR.*
Third attempt; the second failed differently than the first, and the lesson is
the reusable part. v1: a good bolt whose afterimage bars died at 24px. v2 asked
for "two bold vertical BARS" — and a bar is semantically NOTHING, so the
generator faithfully rendered meaningless geometry (it read as a percent sign /
dumbbell). Same family as the paladin "refresh symbol" failure: the
displacement concept needs a RECOGNIZABLE OBJECT to be displaced. So v3 keeps
one object — a lightning bolt — and does the blink TO IT: the bolt is cut
mid-strike and its lower half reappears offset. One object, bold silhouette,
and the offset IS the teleport.
```
SUBJECT: one thick, chunky zigzag LIGHTNING BOLT striking from upper-right
toward lower-left, drawn massive — strokes as wide as a thumb, 3 hard angular
turns, filling the frame corner to corner. The bolt is CUT clean through at its
midpoint and the LOWER half is DISPLACED one full stroke-width to the left of
where it should be, so the two halves visibly do not line up across the gap —
the bolt teleported mid-strike. In the small diagonal gap between the halves,
2 or 3 tiny drifting square sparks. Both halves are solid and bright; the break
and misalignment must be obvious at a glance.
PALETTE: outline #2E1C2C; bolt core #FFFFFF; bolt body #BFEFFF / #7BDCFF with
a #00ADED shadowed underside; gap sparks #7BDCFF; a #547BC5 ghost edge one
pixel wide on the displaced half's left side.
```
### `ability_mage_ult.png` — Meteor
*Call a meteor onto the nearest enemy. Cataclysmic; a quarter is true damage.*
```
SUBJECT: a large burning METEOR falling steeply from the upper-right toward the
lower-left — a heavy cratered dark rock core mantled in fire, with a long
flaring flame trail behind it and a small hard impact flash at the lower-left
tip. Rock first, fire second: the mass must read.
PALETTE: outline #2E1C2C; rock #2E1C2C / #724E63 / #86718C; fire mantle #E86838
/ #EC7E4E / #FFA45F; trail #FFC762 / #FFCE00; impact flash #FFFFFF.
```

## ASSASSIN

### `ability_assassin_a1.png` — Stab
*Quick-draw the long blade — a lightning strike with real reach; a connecting cut surges lifesteal.*
```
SUBJECT: a single slender LONG DAGGER thrusting POINT-FIRST toward the upper
right, seen nearly end-on so it reads as a lunge — the blade foreshortened, a
hard white glint on the point, one short straight thrust streak behind the
pommel, and a single bright blood bead at the tip. Straight-line thrust, no
arc: this is a stab, not a slash.
PALETTE: outline #2E1C2C; blade #86718C / #95ADB4 / #BFDDD1 with a #FFFFFF
point glint; grip #705C4A; blood bead #CB1E31; thrust streak #86718C.
```

### `ability_assassin_a2.png` — Shadow Dash  (RE-ROLL 2026-07-17)
*Dash in your move direction, slashing everything in your path.*
First render came back a full hooded CHARACTER with motion trails — the one
thing the negatives forbid. This version removes any excuse for a figure: the
subject is ONLY blades. Three ghosted copies of the SAME dagger, echoing back
along the dash line — pure motion, nothing that could be read as a body.
```
SUBJECT: a single slim DAGGER pointing up-and-right at the bright leading edge,
with TWO or THREE ghosted afterimage copies of the exact same dagger trailing
behind it down-and-left, each fainter and more violet than the last — a
strobe/echo of one blade in motion, evenly spaced along a straight diagonal.
The front dagger is crisp steel; the echoes are flat violet-shadow silhouettes.
No smoke, no cloud, no figure — just one blade repeated as it streaks. The three
blades together are the whole subject and fill the frame corner-to-corner.
PALETTE: outline #2E1C2C; lead dagger blade #95ADB4 / #BFDDD1 with a #FFFFFF
point glint, grip #705C4A; echo silhouettes #2E1C2C / #724E63 / #86718C
(solid flat fills, front echo brightest).
```

### `ability_assassin_a3.png` — Fan of Knives
*Spammable dagger fan — thin chip alone; bites twice as hard while blood surge runs.*
```
SUBJECT: THREE throwing knives fanning outward from a point at the bottom
centre, spreading up and apart in a shallow fan, points leading, each with a
short motion streak. Small, sharp, plural — clearly LIGHT thrown blades, not
the one heavy dagger of Stab.
PALETTE: outline #2E1C2C; blades #95ADB4 / #BFDDD1 / #FFFFFF; grips #705C4A;
streaks #86718C.
```

### `ability_assassin_ult.png` — Death Mark
*Mark the prey with the X: shadows converge, TRUE damage, +50% taken 5s, executes low HP.*
```
SUBJECT: a bold X-shaped BRAND — two thick tapering strokes crossing at the
centre, drawn like a cut carved into the air, with a small skull silhouette
faintly showing THROUGH the middle of the X where the strokes cross. The X is
the icon; the skull is a subordinate detail inside it. Heavy, blunt, symmetric.
PALETTE: outline #2E1C2C; X strokes #CB1E31 / #FF3838 with a #FFFFFF core along
each stroke's upper-left edge; skull #86718C / #BFDDD1.
```

## PALADIN

### `ability_paladin_a1.png` — Judgment
*Bring the warhammer down on the nearest enemy — LEAPING to them if out of reach.*
```
SUBJECT: a heavy two-handed WARHAMMER at the end of a downward swing — a big
blocky steel head at the LOWER centre, haft running up to the upper right, a
curved overhead arc trailing from the haft to show the swing coming down, and a
hard white impact flash under the head. Weight and downward force.
PALETTE: outline #2E1C2C; hammer head #724E63 / #86718C / #95ADB4 / #BFDDD1;
haft #705C4A / #B88F48; gold trim band #FFC762; swing arc #BFDDD1; impact flash
#FFFFFF.
```

### `ability_paladin_a2.png` — Consecration
*Sanctify the ground around you: two waves of holy fire; every enemy struck MENDS you.*
```
SUBJECT: consecrated GROUND — a flat elliptical ring on the floor seen at a low
angle, drawn as TWO concentric ellipses, with thick golden holy flames rising
in tongues from the ring itself and a small solid cross standing at the centre.
Ground-plane and radiating: the ellipse must read as flat, not as a sphere.
PALETTE: outline #2E1C2C; ring #FFC762 / #FFCE00; holy flame ramp #FFA45F /
#FFC762 / #FFCE00 with #FFFFFF tips; cross #FFFFFF.
```

### `ability_paladin_a3.png` — Aegis
*Raise the shield 2.5s: massive resistances, and attackers are SMITTEN in return.*
```
SUBJECT: a broad heater SHIELD face-on, STATIONARY and squarely upright, with a
bold golden cross across its face and a bright protective barrier shimmer
outlining its rim as a hard 2px halo. Three short golden smite sparks flick
OUTWARD from the rim. It must read as a raised guard — square, centred and
still — the deliberate opposite of Shield Bash's tilted charge.
PALETTE: outline #2E1C2C; shield face ramp #547BC5 / #7BDCFF / #BFEFFF; cross
and sparks #FFC762 / #FFCE00; barrier halo #FFFFFF.
```

### `ability_paladin_ult.png` — Conviction  (RE-ROLL 2026-07-17)
*Swap stances. RETRIBUTION drags enemies in on chains; HOLY releases a mending blessing.*
My fault, not the generator's: the old prompt asked for "a refresh symbol" and
got exactly that — UI chrome, not an ability. This version encodes the same
Holy/Retribution duality as a real object: a warhammer head split down the
middle. Centred and symmetric, so it also reads distinct from a1 (Judgment),
which is a diagonal hammer mid-swing.
```
SUBJECT: a heavy WARHAMMER shown UPRIGHT and centred, head at the top filling
the width, short haft dropping straight down — seen flat and face-on. The
hammer HEAD is split vertically down its centre into two halves: the LEFT half
is radiant pale-gold holy metal stamped with a small white cross; the RIGHT
half is dark iron bound by two heavy CHAIN links with a red-ember glow in the
seams. One weapon, two natures, split down the middle. Bold blocky silhouette,
symmetric, the head much larger than the haft.
PALETTE: outline #2E1C2C; left/holy half #FFC762 / #FFCE00 / #FFFFFF with a
#FFFFFF cross; right/retribution half iron #724E63 / #86718C with #C4594B /
#E86838 ember seams and #86718C chain links; haft #705C4A.
```

## WARLOCK

### `ability_warlock_a1.png` — Shadowbolt  (RE-ROLL 2026-07-17)
*Hurl a bolt of hungry darkness at the nearest enemy.*
The first render was faithful — and invisible: a near-black core with a dim rim
sits on a near-black action bar. Same design, inverted emphasis: the RIM is now
the brightest thing in the icon and carries the whole silhouette; the core stays
void-dark inside it.
```
SUBJECT: a compact ORB of dark energy hurtling diagonally from lower-left to
upper-right. The core is a void — the darkest thing in the icon — but it is
WRAPPED in a thick, bright arcane rim that reads as the actual shape: pale
silver-violet, hottest at the leading edge with a white glint, trailing two
short bright wisps behind. The rim must stay readable against a near-black
background — it, not the core, is the silhouette.
PALETTE: outline #2E1C2C; void core #2E1C2C / #4C303F; rim #86718C into
#BFDDD1 with an #A0405A arcane seam; leading edge #BFDDD1 + #FFFFFF glint;
trailing wisps #86718C / #724E63.
```
### `ability_warlock_a2.png` — Hex
*Curse enemies around your target: withered and EXPOSED; cursed enemies EXPLODE on death; deepens while held.*
```
SUBJECT: a floating CURSE SIGIL — a bold circular brand with a stylised eye at
its centre, ringed by three thick angular hooks pointing inward, dripping two
heavy blobs of withering purple downward off its lower rim. The eye is open and
staring. Marked-and-watched is the idea; keep the ring heavy and the hooks
chunky.
PALETTE: outline #2E1C2C; ring and hooks #4C303F / #724E63 / #86718C; eye
sclera #BFDDD1 with a #2E1C2C pupil; curse drip #A0405A / #C4594B.
```

### `ability_warlock_a3.png` — Dark Pact
*Sacrifice 12% max HP for a soul-drain blast; for 5s your lifesteal surges.*
```
SUBJECT: a clenched HEART squeezed in a ring of dark thorns, three heavy blood
droplets falling from its base and a thin bright soul-wisp rising from its top.
The heart is the subject; the price is the blood. Bold, blunt, centred — the
trade of life for power in one read.
PALETTE: outline #2E1C2C; heart ramp #8D2C44 / #CB1E31 / #FF3838 with a #FFFFFF
specular pip; thorn ring #2E1C2C / #4C303F / #724E63; blood drops #CB1E31; soul
wisp #BFDDD1 into #FFFFFF.
```

### `ability_warlock_ult.png` — Void Rift
*Tear a rift under the nearest enemy: it drags everything inward, then BURSTS.*
```
SUBJECT: a vertical TEAR in space — a tall almond/eye-shaped rip, near-black
inside, its edges lit with a hard cold arcane rim, with four thick stubby
shards angled INWARD toward it from the four corners to show the pull. The void
interior is a true hole: the darkest, emptiest shape in the whole icon set.
PALETTE: outline #2E1C2C; rift interior #2E1C2C (flat, unshaded); rift rim
#4C303F / #547BC5 / #7BDCFF with a #FFFFFF hot edge; inward shards #724E63 /
#86718C.
```

---

## Post-process (required — the generator will not give you a clean 32x32)

Identical discipline to the consumable icons above. ChatGPT returns a large
soft canvas with hundreds of colours; **do not install that.** Per icon:

1. **Generate at 1024x1024**, then crop tight to the object's bounding box.
2. **Nearest-neighbour downscale to 32x32** (scale to a 32-multiple first, e.g.
   512, and check the cells land square).
3. **Snap to the palette** — quantize to the icon's listed hexes. Anything off
   the list is a generator artifact. Target **≤12 colours**.
4. **Rebuild the outline** as a hard closed 1px `#2E1C2C` ring; force alpha 0
   outside it. No semi-transparent alpha anywhere — the family has none.
5. **Verify as a SET, not one at a time.** These 24 sit four-at-a-time in one
   bar. Put all four of a class side by side at true 32x32 and confirm each is
   unmistakable from its three neighbours — the pairs most at risk are
   **Shield Bash vs Aegis** (both shields), **Cleave vs Whirlwind** (both
   slashes), **Multishot vs Arrow Storm** (both arrow volleys) and **Firebolt
   vs Shadowbolt** (same silhouette by design).
6. **Check against the bar it lives in** — the potion slot at the end of the
   same row is real pack art (`potion.png`); the new icons must read as its
   siblings, not as a different game's UI.

Install: drop into `game/assets/icons/`, let Godot import, done — no code
change, and any subset can land alone. Then update `assets/icons/CREDITS.txt`
(these are Crownless originals, not Raven pack art) and re-sync
`mobile/game/assets/icons/` per CLAUDE.md.
