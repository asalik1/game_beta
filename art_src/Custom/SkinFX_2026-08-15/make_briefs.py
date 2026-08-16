"""Brief generator for the 2026-08-15 SKIN FX pass (owner: fix the skin review's
ranked list — quality AND layering; Umbral Phantom + Arcane Warlock are
prototypes and skipped). Five masters:
  void_contact        8f one-shot 128px  — Voidwraith tentacle bite / void contact pop
  storm_conduct       8f one-shot 128px  — Stormforged blade discharge / charge break
  gilded_iai          8f one-shot 256px  — Golden Ronin's one-cut cross-slash payoff
  consecration_bloom  8f LOOP     256px  — paladin Consecration hallowed-ground bloom (pale, tintable)
  void_rift_burst     8f one-shot 256px  — warlock Void Rift collapse burst (base + Hellfire hue-shift)
Run from the repo root; writes <stem>/codex_brief.txt + refs/ for run_codex_batch.ps1."""
import os
import sys

from PIL import Image

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "RingFX_2026-08-15"))
from make_briefs import HEAD, MAG, GRN, COMMON, swatch  # noqa: E402

BASE = "art_src/Custom/SkinFX_2026-08-15"
STYLE = "game/assets/sprites/fx/mage_void_thread_eruption.png"

RADIAL_ANCHOR = ("the effect's centre is the exact centre of every square cell; it grows out from that "
                 "centre and never leaves the cell — at its widest it fills about {pct}% of the cell width "
                 "with clear {key} margin on every side. The centre never drifts, the camera never moves.")

JOBS = {
    "void_contact": dict(
        pal=["#F0C8FF", "#B46CFF", "#7A2FCF", "#3A1466", "#150726"], **GRN,
        pal_desc="five swatches on green: #F0C8FF pale violet flash, #B46CFF violet, #7A2FCF deep violet, #3A1466 dark, #150726 near-black",
        title="a small ONE-SHOT VOID CONTACT POP (where a void tentacle bites a target)", **COMMON,
        subject="a compact burst where something made of void strikes: a tight pale-violet flash at the strike point, a ragged little tear of near-black void opening around it with violet rim light, four to six short violet spark-shards flicked outward, then the tear seals and the shards fade. Compact and quick — NOT an explosion, NOT fire, NOT a portal seen from the side, NOT a face, NO tentacle (the tentacle is drawn by the game).",
        anchor=RADIAL_ANCHOR.format(pct=70, key="green"),
        storyboard="ONE-SHOT storyboard — eight VISIBLY DIFFERENT stages, small to pop to gone:\n frame 1: a tiny pale-violet flash — 20% wide\n frame 2: the flash rings out, a small ragged near-black tear opening at the centre with violet rims, first shards leaving — 45% wide\n frame 3: PEAK: the tear at its widest with bright violet rims, shards at full reach — 70% wide\n frame 4: the tear starting to seal, shards thinning outward — 65% wide\n frame 5: tear mostly sealed to a violet seam, shards fading\n frame 6: a faint violet seam and two motes\n frame 7: a couple of motes\n frame 8: almost nothing — one speck",
        colour_rule="Do NOT use #00ff00 or any green anywhere in the effect. Stay inside the five palette colours plus their in-between shades (violets, purples, near-black only). Do not use pink or magenta.",
    ),
    "storm_conduct": dict(
        pal=["#FFFFFF", "#CFF0FF", "#7FD4FF", "#2F8FE8", "#123C6E"], **MAG,
        pal_desc="five swatches on magenta: #FFFFFF white core, #CFF0FF pale electric, #7FD4FF sky lightning, #2F8FE8 storm blue, #123C6E dark storm",
        title="a small ONE-SHOT STORM DISCHARGE (lightning snapping off a charged blade)", **COMMON,
        subject="a compact electric discharge: a bright white-blue spark core with three to five jagged forked lightning tendrils snapping outward in every direction, a thin ring of pale electric haze, and small crackling sparks; then the forks break up into stray sparks and go out. Lightning and static — NOT fire, NOT a ball of plasma, NOT a lightning BOLT from the sky, NOT a face, NO weapon (the blade is drawn by the game).",
        anchor=RADIAL_ANCHOR.format(pct=75, key="magenta"),
        storyboard="ONE-SHOT storyboard — eight VISIBLY DIFFERENT stages, small to snap to gone:\n frame 1: a tiny white spark with two short forks — 20% wide\n frame 2: the core flares, forks jumping outward in three directions, a haze ring starting — 45% wide\n frame 3: PEAK: five jagged forks at full reach in every direction, bright core, haze ring at 75% wide\n frame 4: forks re-routed (different jagged paths than frame 3), core dimming — 70% wide\n frame 5: forks breaking into stray sparks, haze thinning\n frame 6: only sparks and a faint core\n frame 7: two or three fading sparks\n frame 8: almost nothing — one speck",
        colour_rule="Do NOT use #ff00ff, pink, purple or any magenta anywhere in the effect. Stay inside the five palette colours plus their in-between shades (whites and blues only). Do not use pure #00ff00.",
    ),
    "gilded_iai": dict(
        pal=["#FFFFFF", "#FFF3B0", "#FFD24A", "#E0A020", "#7A5210"], **MAG,
        pal_desc="five swatches on magenta: #FFFFFF white-hot core, #FFF3B0 pale gold, #FFD24A gold, #E0A020 deep gold, #7A5210 dark bronze",
        title="a ONE-SHOT GILDED CROSS-CUT (a golden swordsman's one decisive iai slash landing)", **COMMON,
        subject="two enormous curved sword-slash streaks of gold light crossing in an X through the centre of the cell — each streak a long tapered crescent with a white-hot core, a gold body and a bronze trailing edge — appearing one after the other, flaring at the crossing point with a spray of small gold light-petals, then thinning to bright hairlines and fading. Sword-light — NOT fire, NOT lightning, NOT a star or sun, NOT a sword or hand (the fighter is drawn by the game).",
        anchor=RADIAL_ANCHOR.format(pct=85, key="magenta"),
        storyboard="ONE-SHOT storyboard — eight VISIBLY DIFFERENT stages of one cross-cut:\n frame 1: the FIRST streak alone — a thin bright gold hairline from lower-left to upper-right through the centre, just drawn — 60% wide\n frame 2: the first streak swells to a full crescent with a white core; the SECOND streak appears as a hairline from upper-left to lower-right — 80% wide\n frame 3: PEAK: both streaks at full crescent width crossing in an X, a white-hot flare at the crossing point, gold petals spraying out — 85% wide\n frame 4: the flare blooming wider, both streaks still full, petals drifting outward\n frame 5: streaks thinning toward hairlines, flare fading, petals falling\n frame 6: two thin bright hairlines in an X and a few petals\n frame 7: faint hairlines and one or two petals\n frame 8: almost nothing — a faint glint at the centre",
        colour_rule="Do NOT use #ff00ff, pink, purple or any magenta anywhere in the effect. Stay inside the five palette colours plus their in-between shades (whites, golds, bronze only). Do not use pure #00ff00 or red.",
    ),
    "consecration_bloom": dict(
        pal=["#FFFFFF", "#FFF7D6", "#FFE9A0", "#F2C860", "#A8843A"], **MAG,
        pal_desc="five swatches on magenta: #FFFFFF core light, #FFF7D6 pale, #FFE9A0 pale gold, #F2C860 gold, #A8843A shadow gold — a PALE effect so the game can tint it per theme/skin",
        title="a LOOPING HALLOWED-GROUND BLOOM (a paladin's Consecration circle)", **COMMON,
        subject="ONE flat circle of holy light lying on the ground, seen from directly above / a high game camera: a roughly CIRCULAR field with a soft irregular edge, a brighter thin outer ring of light, a faint inner ring, gentle radiating light-rays between the two rings (like a soft sunburst seen from above), and small motes of light rising off the field; the very centre is calm and slightly darker (empty — the paladin stands there, added by the game). Pale white and pale gold — NOT a rune circle with letters, NOT fire, NOT a portal, NOT a mandala with hard geometry.",
        anchor="the circle is centred in each square cell (its calm centre is the exact centre) and fills about 82% of the cell width with clear magenta margin on every side. It stays in the SAME spot at the SAME size in every cell — only the rays, ring brightness and motes change.",
        storyboard="LOOP storyboard — eight VISIBLY DIFFERENT shimmer states of THIS SAME circle that read as one seamless loop (frame 8 flows back into frame 1): the light-rays between the rings slowly rotate CLOCKWISE by 6 degrees per frame (frame 8 = 42 degrees, so one more step lands near frame 1); the outer ring pulses brighter on frames 2, 4, 6, 8; the motes rise and refresh (frames 1-2 low, 3-4 mid, 5-6 high and dimming, 7-8 fresh low motes). The circle outline itself never moves or resizes.",
        colour_rule="Do NOT use #ff00ff, pink, purple or any magenta anywhere in the effect. Keep it PALE — white and pale gold only. Do not use pure #00ff00, red or orange.",
    ),
    "void_rift_burst": dict(
        pal=["#FFFFFF", "#D9B8FF", "#8B5CF6", "#4C1D95", "#14062B"], **GRN,
        pal_desc="five swatches on green: #FFFFFF white core, #D9B8FF pale violet, #8B5CF6 violet, #4C1D95 deep violet, #14062B near-black",
        title="a ONE-SHOT VOID RIFT COLLAPSE-BURST (a warlock's rift imploding, then blowing back out)", **COMMON,
        subject="the moment a tear in space collapses and detonates, seen from a high three-quarter game camera: a roughly CIRCULAR effect centred on the rift point — first a ring of near-black void with violet rims CONTRACTING toward a white-hot pinpoint, then the pinpoint bursts: a white core bloom, a flat violet shockwave ring racing outward along the ground, ragged near-black void shards and violet light-rays flung outward, then a dark violet scar/stain left at the centre. Void and dark light — NOT fire, NOT lava, NOT a face, NOT an eye, NOT lightning, and NO character.",
        anchor=RADIAL_ANCHOR.format(pct=85, key="green"),
        storyboard="ONE-SHOT storyboard — eight VISIBLY DIFFERENT stages, contract → burst → scar:\n frame 1: a ring of near-black void with violet rims at about 60% width, arrows of violet light streaming INWARD toward a tiny white pinpoint at the centre\n frame 2: the ring contracted to 30% width, brighter, the pinpoint growing to a small white core\n frame 3: DETONATION: a white-hot core bloom at the centre with the first violet shockwave ring at 45% width and void shards starting outward\n frame 4: PEAK: the shockwave ring at 85% width, ragged near-black shards and violet rays at full reach, the core still bright\n frame 5: the ring dissolving to violet haze at the edge, shards slowing, the core dimming into a violet flare\n frame 6: haze thinning, a dark violet scar/stain forming at the centre, a few drifting shards\n frame 7: the scar with faint violet cracks, one or two last shards\n frame 8: a faint dark scar alone — nearly empty cell",
        colour_rule="Do NOT use #00ff00 or any green anywhere in the effect. Stay inside the five palette colours plus their in-between shades (whites, violets, near-black only). Do not use pink or magenta.",
    ),
}


def main():
    for stem, j in JOBS.items():
        d = f"{BASE}/{stem}"
        os.makedirs(f"{d}/refs", exist_ok=True)
        swatch(j["pal"], f"{d}/refs/palette.png", j["key"])
        Image.open(STYLE).save(f"{d}/refs/style_fx_strip.png")
        fields = {k: v for k, v in j.items() if k not in ("pal", "key")}
        open(f"{d}/codex_brief.txt", "w", encoding="utf-8").write(HEAD.format(stem=stem, **fields))
        print("wrote", d)


if __name__ == "__main__":
    main()
