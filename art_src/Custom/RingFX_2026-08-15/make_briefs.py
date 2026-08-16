"""Brief generator for the 2026-08-15 ring-replacement FX batch (owner: "fix the
other rings too — aegis, dark pact, arrow storm, whirlwind"). Run from the repo
root; writes <stem>/codex_brief.txt + refs/ for tools/art/run_codex_batch.ps1."""
import os

from PIL import Image, ImageDraw

BASE = "art_src/Custom/RingFX_2026-08-15"
STYLE = "game/assets/sprites/fx/mage_void_thread_eruption.png"


def swatch(cols, out, key):
    im = Image.new("RGB", (100 * len(cols), 120), key)
    d = ImageDraw.Draw(im)
    for i, c in enumerate(cols):
        d.rectangle((i * 100 + 5, 5, i * 100 + 95, 95), fill=c)
        d.text((i * 100 + 8, 100), c, fill=(0, 0, 0))
    im.save(out)


HEAD = """You are generating ONE game visual-effect animation master with your built-in image_gen tool. Read $CODEX_HOME/skills/.system/imagegen/SKILL.md first, then follow this brief exactly. Work only inside the current directory (the staging dir). Do NOT touch any file under C:\\Users\\asali\\Projects\\MMO.

Two images are attached to this prompt:
- Image 1 = refs/palette.png : the BINDING colour palette for this effect ({pal_desc}). Ignore the {keyname} around the swatches — it is only there to show what the chroma key looks like.
- Image 2 = refs/style_fx_strip.png : a shipped FX animation strip from this game (a violet thread eruption). Match its LEVEL OF FINISH — crisp high-resolution game FX, hard readable clusters, glowing rims over a darker body, no blur, no photo texture. Do NOT copy its subject, shape or colour.

TASK: generate exactly ONE new {grid} source sheet for {title} with this image_gen prompt (adapt only if the tool's parameters require it; keep every constraint):

---
Use case: game asset
Output size: {size}.
Asset type: high-resolution {n}-frame game visual-effect animation source, to be cropped into a horizontal sprite strip.
Scene/backdrop: a perfectly flat uniform {keyhex} {keyname} chroma-key background filling every pixel, including the seams between cells. No scenery, floor plane, ground texture, platform, cast shadow, gradient, vignette, border, grid, line, or panel divider.
Primary request: create exactly {NWORD} separate equal square effect cells laid out as a clean {gridwords} contact sheet in reading order ({order}). All cells have identical scale and framing; no cell may overlap another; no drawn separators; leave a broad band of flat {keyname} between neighbouring cells and around the sheet edge.
Subject: {subject}
Style/medium: crisp high-resolution dark-fantasy game FX art with hard readable clusters and a controlled palette; not painterly, not 3D-rendered, not photographic, not anime, not blurred.
Composition/framing and ANCHOR RULE: {anchor}
{storyboard}
Constraints: output only the cells on {keyname}; no text, watermark, UI, characters, weapons, scenery, ground texture, shadow, or separators. {colour_rule} Every frame must be clearly different from every other frame.
---

AFTER generation:
1. Copy the raw generated PNG (do not resize it) to ./{stem}_master_v1.png in the current directory.
2. Run the skill's remove_chroma_key.py helper on it and write the keyed RGBA result to ./{stem}_master_v1_keyed.png (auto-key sampling from the border, soft matte, despill on).
3. Do NOT slice, do NOT install, do NOT write anywhere under the MMO project. I will do the slicing.
4. In your final message report: the raw output size in pixels, whether all cells were produced with visibly different frames (frame by frame), whether the effect kept the same centre and size in every cell, and any deviation from the brief (a cell missing, cells overlapping or touching, key colour inside the effect, drift, an extra cell, a ground plane drawn). Be blunt about defects; do not soften them.

If image_gen is unavailable, say so and stop; do not fall back to another provider or the CLI.
"""

COMMON = dict(grid="4x2", size="1536x1024 landscape", n=8, NWORD="EIGHT",
              gridwords="4-column by 2-row",
              order="top row left to right = frames 1-4, bottom row left to right = frames 5-8")

MAG = dict(key=(255, 0, 255), keyhex="#ff00ff", keyname="magenta")
GRN = dict(key=(0, 255, 0), keyhex="#00ff00", keyname="green")

JOBS = {
    "aegis_dome": dict(
        pal=["#FFFFFF", "#FFF3C8", "#FFD27A", "#9CC8FF", "#5A7DB8"], **MAG,
        pal_desc="five swatches on magenta: #FFFFFF white core light, #FFF3C8 warm pale gold, #FFD27A gold rim, #9CC8FF pale sky blue, #5A7DB8 muted blue shadow — a PALE effect, mostly white/pale gold, so the game can tint it per theme",
        title="a LOOPING HOLY SHIELD DOME (a paladin's Aegis barrier)",
        subject="ONE translucent hemispherical BARRIER DOME of holy light seen from a high three-quarter game camera: a see-through dome (the inside must remain visible through it — paint it as thin glowing rims, hexagonal/rune facets and light seams over a faint pale wash, NOT a solid ball), about 1.15x wider than it is tall, sitting on a thin bright ring where it meets the ground (an ellipse, foreshortened). Pale white and pale gold with a gold rim light and faint blue in the shadowed facets; small glints travel across the facets. It is EMPTY inside — no character, no shield emblem, no cross. A magic energy barrier — NOT glass, NOT a soap bubble with a cartoon highlight, NOT a planet.",
        anchor="the dome is centred in each square cell and its ground ring's centre is the exact centre of the cell; the dome fills about 80% of the cell width with clear magenta margin on every side. It stays in the SAME spot at the SAME size in every cell — only the glints and facet brightness change.",
        storyboard="LOOP storyboard — eight VISIBLY DIFFERENT shimmer states of THIS SAME dome that read as one seamless loop (frame 8 flows back into frame 1): the bright facet glints and light seams travel around the dome CLOCKWISE one full turn across the eight frames (frame 1 glints at the front-left, frame 3 at the back-left/top, frame 5 at the back-right, frame 7 at the front-right, frame 8 nearly back at frame 1's position); the ground ring pulses subtly (brighter on frames 2, 4, 6, 8). The dome outline itself never moves.",
        colour_rule="Do NOT use #ff00ff, pink, purple or any magenta anywhere in the effect. Keep it PALE — mostly white and pale gold; blue only in shadowed facets. Do not use pure #00ff00 or saturated red.",
    ),
    "dark_pact_burst": dict(
        pal=["#FFB0BC", "#FF3B5C", "#B0122E", "#5A0716", "#180307"], **GRN,
        pal_desc="five swatches on green: #FFB0BC hot highlight, #FF3B5C blood red, #B0122E deep blood, #5A0716 dark blood, #180307 near-black",
        title="a ONE-SHOT BLOOD-MAGIC ERUPTION (a warlock's Dark Pact — HP paid for power)",
        subject="the ERUPTION of a blood pact from a caster's feet, seen from a high three-quarter game camera: a roughly CIRCULAR burst centred on the caster's spot — a runic seal of blood on the ground flashes, then thick blood-red tendrils and jagged crimson spikes ERUPT upward and outward in a ring, a flat shockwave of near-black smoke and blood droplets races outward along the ground, and the ring collapses back into a dark stain with fading runes. Blood, dark magic and smoke — NOT fire, NOT lava, NOT lightning, NOT a face, NOT a portal, and NO character (the centre is EMPTY, the caster is added by the game).",
        anchor="the seal/eruption centre is the exact centre of every square cell; the effect grows out from that centre and never leaves the cell — at its widest (frames 3-4) the shockwave fills about 85% of the cell width with clear green margin on every side. The centre never drifts, the camera never moves. The centre of every frame must stay OPEN (only a flat ground seal there), never a solid mass, so a character standing there is not hidden.",
        storyboard="ONE-SHOT storyboard — eight VISIBLY DIFFERENT stages of one eruption, small to wide to gone:\n frame 1: a small blood-red runic seal glowing on the ground at the centre, a few droplets lifting — about 30% of the cell wide\n frame 2: the seal flares; a ring of short crimson spikes/tendrils breaks upward around the (empty) centre; a dark shockwave ring starts — about 50% wide\n frame 3: PEAK: tall curling blood tendrils and jagged spikes in a full ring around the empty centre, blood droplets flung outward, the near-black shockwave ring at about 80% width with #FF3B5C rims\n frame 4: tendrils at full reach and starting to bend outward, the shockwave at 85% thinning to smoke, droplets arcing down\n frame 5: tendrils dissolving into dark smoke and falling droplets, the seal dimming\n frame 6: only dark smoke wisps, scattered blood droplets and a fading seal\n frame 7: a dark stain with faint runes and a couple of last droplets\n frame 8: a faint dark stain alone — nearly empty cell",
        colour_rule="Do NOT use #00ff00 or any green anywhere in the effect. Stay inside the five palette colours plus their in-between shades (reds, dark reds, near-black only).",
    ),
    "wind_vortex": dict(
        pal=["#FFFFFF", "#EEF6F2", "#CFDFD8", "#9DB5AE", "#5F7770"], **MAG,
        pal_desc="five swatches on magenta: #FFFFFF white, #EEF6F2 pale mist, #CFDFD8 light grey-mint, #9DB5AE mid grey-mint, #5F7770 shadow — a PALE near-white effect so the game can tint it per theme",
        title="a LOOPING WIND VORTEX on the ground (the eye of an archer's Arrow Storm)",
        subject="ONE flat swirling VORTEX of wind lying on the ground, seen from directly above / a high game camera: a roughly CIRCULAR spiral of pale wind streaks and gust ribbons curling COUNTER-CLOCKWISE into the centre, with FOUR-FOLD rotational symmetry (four matching spiral arms), a soft pale haze between the arms, and a few small dust motes; the centre is an open calm eye (empty — the archer stands there, added by the game). Pale white and grey-mint; the streaks have crisp bright edges. Air and wind only — NOT water, NOT a portal, NOT clouds from the side, NOT a tornado funnel seen sideways.",
        anchor="the vortex is centred in each square cell (its eye is the exact centre) and fills about 82% of the cell width with clear magenta margin on every side. It stays in the SAME spot at the SAME size in every cell.",
        storyboard="LOOP storyboard — eight VISIBLY DIFFERENT rotation states of THIS SAME vortex that read as one seamless loop: the whole four-armed spiral rotates COUNTER-CLOCKWISE by exactly 11.25 degrees per frame (frame 2 = frame 1 turned 11.25 degrees, frame 3 = 22.5, ... frame 8 = 78.75), so that one more step (90 degrees) lands exactly back on frame 1 because of the four-fold symmetry. Nothing else changes: same arm shapes, same haze, same size; only the rotation angle. Frames 1 through 8 must each be clearly different rotations.",
        colour_rule="Do NOT use #ff00ff, pink, purple or any magenta anywhere in the effect. Keep it PALE — white and grey-mint only. Do not use pure #00ff00.",
    ),
    "arrow_impact": dict(
        pal=["#FFF6E0", "#E8D2A0", "#B89A6A", "#7A6446", "#3E3226"], **MAG,
        pal_desc="five swatches on magenta: #FFF6E0 pale flash, #E8D2A0 pale dust, #B89A6A tan, #7A6446 dark tan, #3E3226 shadow — a PALE effect so the game can tint it",
        title="a small ONE-SHOT ARROW-STRIKE PUFF (where a falling arrow hits the ground)",
        subject="the small IMPACT of an arrow striking the ground, seen from a high three-quarter game camera: a tiny pale flash at the strike point, a compact roughly circular puff of pale dust that pops up and out with a few small dirt chips and two or three thin splinters/feathers flicked outward, then the dust thins and settles. Compact and quick — NOT an explosion, NOT fire, NOT a big cloud, and NO arrow shaft (the arrow is drawn by the game).",
        anchor="the strike point is the exact centre of every square cell; the puff grows out from it and never leaves the cell — at its widest (frames 3-4) it fills about 70% of the cell width with clear magenta margin on every side. The centre never drifts.",
        storyboard="ONE-SHOT storyboard — eight VISIBLY DIFFERENT stages of one strike, small to puff to gone:\n frame 1: a tiny bright flash and a few dirt chips lifting — about 20% wide\n frame 2: a compact dust puff popping up, chips and two splinters flicking outward — 45% wide\n frame 3: PEAK: the dust puff at its fullest, chips at the top of their arc — 70% wide\n frame 4: the puff spreading and thinning outward, chips falling — 70% wide\n frame 5: thin dust settling low, chips landed\n frame 6: only faint dust and a chip or two\n frame 7: a faint dust smudge\n frame 8: almost nothing — a couple of specks",
        colour_rule="Do NOT use #ff00ff, pink, purple or any magenta anywhere in the effect. Keep it PALE — pale dust and tan only. Do not use pure #00ff00.",
    ),
    "whirl_gust": dict(
        pal=["#FFFFFF", "#F0F4F8", "#CFD8E3", "#9AA8B8", "#5B6978"], **MAG,
        pal_desc="five swatches on magenta: #FFFFFF white, #F0F4F8 pale, #CFD8E3 light steel-grey, #9AA8B8 mid steel-grey, #5B6978 shadow — a PALE effect so the game can tint it",
        title="a LOOPING WHIRLWIND GUST RING (the air torn around a spinning warrior)",
        subject="ONE ring of torn air around a spinning fighter, seen from a high three-quarter game camera: THREE broad crescent-shaped wind slashes (each a curved gust ribbon with a crisp bright leading edge and a feathered trailing edge) chasing each other CLOCKWISE around a roughly CIRCULAR path, evenly spaced (three-fold symmetry, 120 degrees apart), with a thin flat ring of kicked-up pale dust under them near the ground; the centre is EMPTY (the fighter stands there, added by the game). Pale white and steel-grey. Wind and dust only — NOT blades, NOT fire, NOT a tornado funnel from the side, NOT water.",
        anchor="the ring is centred in each square cell (its empty centre is the exact centre) and fills about 82% of the cell width with clear magenta margin on every side. It stays in the SAME spot at the SAME size in every cell.",
        storyboard="LOOP storyboard — eight VISIBLY DIFFERENT rotation states of THIS SAME ring that read as one seamless loop: the three crescents rotate CLOCKWISE by exactly 15 degrees per frame (frame 2 = frame 1 turned 15 degrees, frame 3 = 30, ... frame 8 = 105), so that one more step (120 degrees) lands exactly back on frame 1 because of the three-fold symmetry. Nothing else changes: same crescent shapes, same dust ring, same size; only the rotation angle. Frames 1 through 8 must each be clearly different rotations.",
        colour_rule="Do NOT use #ff00ff, pink, purple or any magenta anywhere in the effect. Keep it PALE — white and steel-grey only. Do not use pure #00ff00.",
    ),
}


def main():
    for stem, j in JOBS.items():
        d = f"{BASE}/{stem}"
        os.makedirs(f"{d}/refs", exist_ok=True)
        swatch(j["pal"], f"{d}/refs/palette.png", j["key"])
        Image.open(STYLE).save(f"{d}/refs/style_fx_strip.png")
        fields = dict(COMMON)
        fields.update({k: v for k, v in j.items() if k not in ("pal", "key")})
        open(f"{d}/codex_brief.txt", "w", encoding="utf-8").write(HEAD.format(stem=stem, **fields))
        print("wrote", d)


if __name__ == "__main__":
    main()
