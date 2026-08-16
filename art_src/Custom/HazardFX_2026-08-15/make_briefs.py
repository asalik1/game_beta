"""Brief generator for the 2026-08-15 hazard-pool + Berserk batch (owner: "do
the berserk squares and hazard pools too"). Five looping GROUND PATCH masters
(lava / ice / heal / slow / churned — poison reuses fx/poison_pool) as 2x2
4-frame sheets, plus one 4x2 8-frame RAGE BURST one-shot for Berserk. Run from
the repo root; writes <stem>/codex_brief.txt + refs/ for run_codex_batch.ps1."""
import os
import sys

from PIL import Image

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "RingFX_2026-08-15"))
from make_briefs import HEAD, MAG, GRN, swatch  # noqa: E402  (same brief skeleton)

BASE = "art_src/Custom/HazardFX_2026-08-15"
STYLE = "game/assets/sprites/fx/mage_void_thread_eruption.png"

POOL = dict(grid="2x2", size="1024x1024 square", n=4, NWORD="FOUR",
            gridwords="2x2", order="top-left, top-right, bottom-left, bottom-right")
BURST = dict(grid="4x2", size="1536x1024 landscape", n=8, NWORD="EIGHT",
             gridwords="4-column by 2-row",
             order="top row left to right = frames 1-4, bottom row left to right = frames 5-8")

POOL_ANCHOR = ("the patch is centred in each square cell and fills about 80% of the cell width, "
               "with clear {keyname} margin on every side. It stays in the SAME spot with the SAME "
               "outline in every cell — the patch shape, size and position do not change at all "
               "between frames; the camera never moves. Only the surface details named in the "
               "storyboard change.")


def pool(title, subject, storyboard, colour_rule, pal, pal_desc, key):
    return dict(title=title, subject=subject, storyboard=storyboard, colour_rule=colour_rule,
                pal=pal, pal_desc=pal_desc, anchor=POOL_ANCHOR.format(keyname=key["keyname"]),
                **POOL, **key)


JOBS = {
    "hazard_lava": pool(
        "a LOOPING LAVA POOL (a floor hazard patch)",
        "ONE pool of molten lava lying flat on the ground, seen from a high three-quarter game camera: a roughly circular pool, slightly wider than it is deep, with an irregular cooled-crust outline; a dark cracked crust (#3A1208 / #6A2A10) floating over bright molten orange-yellow lava (#FFB13A / #FF6A1E) that shows through the cracks and around the rim, with fat lava bubbles doming and bursting and a faint heat glow. Molten rock — NOT fire flames standing up, NOT water, NOT a portal, NOT a face.",
        "LOOP storyboard — four VISIBLY DIFFERENT surface states of THIS SAME pool that loop seamlessly (frame 4 flows back into frame 1):\n frame 1 (top-left): crust cracks glowing steadily, two small bubbles forming near the left, a crust plate calm on the right\n frame 2 (top-right): the left bubbles swollen large and bright, the right crust plate cracking wider (more molten showing)\n frame 3 (bottom-left): the left bubbles POP into little ring splashes with flung sparks, the right crack at its brightest\n frame 4 (bottom-right): pop rings fading, the right crack dimming back, a fresh tiny bubble near the left again so the loop closes into frame 1",
        "Do NOT use #00ff00 or any green anywhere in the effect. Stay inside the five palette colours plus their in-between shades (yellows, oranges, dark reds, near-black only).",
        ["#FFF1B0", "#FFB13A", "#FF6A1E", "#6A2A10", "#3A1208"],
        "five swatches on green: #FFF1B0 white-hot core, #FFB13A molten yellow-orange, #FF6A1E lava orange, #6A2A10 hot crust, #3A1208 dark crust", GRN),
    "hazard_ice": pool(
        "a LOOPING ICE PATCH (a slick floor hazard patch)",
        "ONE patch of slick glare ice lying flat on the ground, seen from a high three-quarter game camera: a roughly circular sheet, slightly wider than it is deep, with an irregular frosted outline; a pale glassy blue-white surface (#EAF6FF / #BFE3FF) with a few fine dark-blue cracks (#3E6FA8), a frost-crystal rim (#FFFFFF), and small sparkling glints on the surface. Ice — NOT water, NOT snow piles, NOT a portal, NOT a mirror reflection of anything.",
        "LOOP storyboard — four VISIBLY DIFFERENT surface states of THIS SAME patch that loop seamlessly (frame 4 flows back into frame 1):\n frame 1 (top-left): two glints near the left rim, cracks faint\n frame 2 (top-right): the glints brighter and a third glint at the top, a crack catching light on the right\n frame 3 (bottom-left): a bright twinkle at the centre, the left glints fading, a wisp of frost mist lifting off the top edge\n frame 4 (bottom-right): the centre twinkle fading, the frost wisp thinning, a fresh faint glint near the left again so the loop closes into frame 1",
        "Do NOT use #ff00ff, pink, purple or any magenta anywhere in the effect. Stay inside the five palette colours plus their in-between shades (whites and blues only). Do not use pure #00ff00.",
        ["#FFFFFF", "#EAF6FF", "#BFE3FF", "#7FB4E8", "#3E6FA8"],
        "five swatches on magenta: #FFFFFF frost white, #EAF6FF pale ice, #BFE3FF ice blue, #7FB4E8 mid blue, #3E6FA8 crack blue", MAG),
    "hazard_heal": pool(
        "a LOOPING HOLY SPRING (a mending floor patch)",
        "ONE pool of gently glowing holy light lying flat on the ground, seen from a high three-quarter game camera: a roughly circular pool, slightly wider than it is deep, with a soft irregular outline; a warm pale-gold liquid-light surface (#FFF7CF / #FFE28A) with brighter concentric ripple rings (#FFFFFF), and small motes of light rising off it. Blessed water/light — NOT fire, NOT lava, NOT a rune circle with symbols, NOT a portal.",
        "LOOP storyboard — four VISIBLY DIFFERENT surface states of THIS SAME pool that loop seamlessly (frame 4 flows back into frame 1):\n frame 1 (top-left): a small bright ripple ring near the centre, two motes low over the surface\n frame 2 (top-right): the ripple ring wider, motes rising higher, a second small ring starting near the centre\n frame 3 (bottom-left): the first ring reaching the rim and fading, the second ring mid-size, motes drifting up and dimming\n frame 4 (bottom-right): the second ring wide, a fresh tiny ring at the centre and new low motes so the loop closes into frame 1",
        "Do NOT use #ff00ff, pink, purple or any magenta anywhere in the effect. Stay inside the five palette colours plus their in-between shades (whites, pale golds, gold only). Do not use pure #00ff00 or red.",
        ["#FFFFFF", "#FFF7CF", "#FFE28A", "#E8B84A", "#8C6A22"],
        "five swatches on magenta: #FFFFFF core light, #FFF7CF pale gold, #FFE28A gold, #E8B84A deep gold, #8C6A22 shadow gold", MAG),
    "hazard_slow": pool(
        "a LOOPING VOID SLUDGE PATCH (a slowing floor hazard)",
        "ONE patch of thick dark violet sludge lying flat on the ground, seen from a high three-quarter game camera: a roughly circular puddle, slightly wider than it is deep, with an irregular oozing outline; a near-black tarry body (#12081C / #2A1240) with slow violet swirls (#5A2E8A / #8A55C8) on the surface, a thin dim violet rim, and slow fat bubbles that dome and sink back. Heavy clinging tar/void — NOT water, NOT lava, NOT a portal, NOT a face, NOT bright.",
        "LOOP storyboard — four VISIBLY DIFFERENT surface states of THIS SAME patch that loop seamlessly (frame 4 flows back into frame 1):\n frame 1 (top-left): one slow bubble doming near the left, the violet swirl coiled at the centre\n frame 2 (top-right): the left bubble at its largest, the swirl rotated a quarter turn clockwise\n frame 3 (bottom-left): the left bubble sinking back into a dimple, a new bubble doming near the right, the swirl rotated a half turn\n frame 4 (bottom-right): the right bubble large, the left dimple gone, the swirl three-quarters turned so the loop closes into frame 1",
        "Do NOT use #00ff00 or any green anywhere in the effect. Stay inside the five palette colours plus their in-between shades (violets, purples, near-black only). Do not use bright pink or magenta.",
        ["#B48CE8", "#8A55C8", "#5A2E8A", "#2A1240", "#12081C"],
        "five swatches on green: #B48CE8 pale violet highlight, #8A55C8 violet, #5A2E8A deep violet, #2A1240 dark, #12081C near-black", GRN),
    "hazard_churned": pool(
        "a LOOPING CHURNED GRAVE-EARTH PATCH (a boss's imposed floor hazard)",
        "ONE patch of freshly churned grave earth lying flat on the ground, seen from a high three-quarter game camera: a roughly circular patch, slightly wider than it is deep, with an irregular broken-turf outline; dark wet soil (#2E1F14 / #4A3322) heaved into clods and furrows, a few pale bone fragments and finger-bones (#E8DCC0 / #B8A888) half-buried in it, and thin wisps of grave-dust lifting. Disturbed earth — NOT lava, NOT mud water, NOT a portal, NOT a full skeleton, NOT a face.",
        "LOOP storyboard — four VISIBLY DIFFERENT states of THIS SAME patch that loop seamlessly (frame 4 flows back into frame 1):\n frame 1 (top-left): soil settled, a bone tip just showing near the left, one dust wisp on the right\n frame 2 (top-right): the left soil heaving up as a clod, the bone tip pushed higher, the wisp drifting up\n frame 3 (bottom-left): the left clod cracking open with soil crumbs tumbling, a second small heave starting near the right\n frame 4 (bottom-right): the left clod sinking flat again, the right heave at its peak, a fresh wisp so the loop closes into frame 1",
        "Do NOT use #00ff00 or any green anywhere in the effect. Stay inside the five palette colours plus their in-between shades (browns, dark browns, bone off-whites only).",
        ["#E8DCC0", "#B8A888", "#6A4E36", "#4A3322", "#2E1F14"],
        "five swatches on green: #E8DCC0 bone, #B8A888 old bone, #6A4E36 dry soil, #4A3322 wet soil, #2E1F14 dark soil", GRN),
    "rage_burst": dict(
        pal=["#FFF1B0", "#FF9A3A", "#F0381E", "#8A1010", "#2A0808"], **GRN,
        pal_desc="five swatches on green: #FFF1B0 white-hot core, #FF9A3A rage orange, #F0381E blood-fire red, #8A1010 deep red, #2A0808 near-black",
        title="a ONE-SHOT RAGE ERUPTION (a warrior's Berserk — fury bursting out of a fighter)", **BURST,
        subject="the ERUPTION of raw fury from a fighter's body, seen from a high three-quarter game camera: a roughly CIRCULAR burst centred on the fighter's spot — tongues of red-orange rage-flame lick upward and outward in a ring around the (EMPTY) centre, a flat shockwave of red heat races outward along the ground, and embers/sparks fly up; it dies down into a few rising embers. Fury as flame and heat — NOT a fireball, NOT lava, NOT smoke only, NOT lightning, NOT a face, and NO character (the centre stays open; the fighter is added by the game).",
        anchor="the burst centre is the exact centre of every square cell; the effect grows out from that centre and never leaves the cell — at its widest (frames 3-4) the shockwave fills about 85% of the cell width with clear green margin on every side. The centre never drifts, the camera never moves. The centre of every frame stays OPEN (a flat glow at most), never a solid mass, so a character standing there is not hidden.",
        storyboard="ONE-SHOT storyboard — eight VISIBLY DIFFERENT stages of one eruption, small to wide to embers:\n frame 1: a bright red-hot flash ring on the ground at the centre with a few sparks — about 30% of the cell wide\n frame 2: rage-flames lick up in a ring around the empty centre, a red shockwave pushing out — about 55% wide\n frame 3: PEAK: tall flame tongues in a full ring, the shockwave at about 80% width with a bright rim, sparks and embers flung outward and up\n frame 4: flames leaning outward and thinning, the shockwave at 85% dissolving into heat haze, embers arcing\n frame 5: flames breaking into separate tongues and dying down, embers rising\n frame 6: only low flickers and rising embers, a dim glow ring on the ground\n frame 7: a few last embers drifting up, the glow ring almost out\n frame 8: two or three embers alone — nearly empty cell",
        colour_rule="Do NOT use #00ff00 or any green anywhere in the effect. Stay inside the five palette colours plus their in-between shades (yellows, oranges, reds, dark reds only).",
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
