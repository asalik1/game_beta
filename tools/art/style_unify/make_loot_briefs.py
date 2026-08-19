"""P7.B (POLISH_TASKS.md, 2026-08-19; owner: "the coins don't look polished
enough and the chests…"): the ten CHEST sprites (the last 32px black-outline
objects in the world — they skipped every prop batch because they are not
scenery) and the COIN -> painterly house-style art with MOTION:

  chest_<key>      : ONE ROW of FIVE — f1 CLOSED (the static), f2 lid cracking
                     (a thin line of light), f3 lid half open, f4 lid fully
                     open with light spilling out, f5 open at rest (softer) ->
                     build_loot.py installs f1 as `chest_<key>.png` and all five
                     as `chest_<key>_open.png` (chest.gd plays it once on open).
  coin             : ONE ROW of SIX — the same gold coin turning about its
                     vertical axis 60° per frame (face / 3/4 / 1/4 / EDGE / 1/4
                     back / 3/4 back) -> `coin_anim.png` (Art.anim_prop seam;
                     pickup.gd spins it) + `coin.png` = f1.

Style refs = installed painterly siblings (hideout_barrel, coffin); subject
identity = the old 32px chest ×4 nearest (silhouette / material / tint family
ONLY — its chunky pixels are not the target).

  python make_loot_briefs.py <stage_root> [--only chest_a,coin]
"""
import argparse, os, shutil, sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from _common import SPR  # noqa: E402
from PIL import Image  # noqa: E402

STYLE_REFS = ["hideout_barrel", "coffin"]

CHESTS = {
    "chest_f": "the POOREST chest: a small plain pale-pine box of rough planks, a flat lid, a frayed rope handle, no metal at all, scuffed and dusty",
    "chest_e": "a plain dark-brown wooden chest, simple flat lid, one dull iron clasp, worn edges",
    "chest_d": "a sturdy oak chest with a gently domed lid, two dark iron bands and iron hinges, a small iron lock plate",
    "chest_c": "a red-lacquered wooden chest with iron corner caps, an iron lock plate and dark iron hinges, the lacquer worn at the edges",
    "chest_b": "a dark-wood chest banded in dull steel with a pale iron-sheathed lid and a silver clasp — sturdier and cleaner than the wooden ones",
    "chest_a": "a deep teal-blue painted chest with brass trim along every edge, ornate brass corner caps and a brass lock — a rich merchant's strongbox",
    "chest_s": "the ROYAL chest: black lacquer with a gold crown embossed on the lid, gold trim, gold hinges and a heavy gold lock — restrained, not gaudy",
    "chest_wood": "a bronze-banded wooden supply chest with a rounded lid, bronze rivets and a bronze lock plate",
    "chest_silver": "a polished silver-steel metal chest with a domed lid, dark seams between the plates and a silver lock",
    "chest_gold": "a gold metal chest with a softly engraved domed lid, gold rivets and a large gold lock — warm, not neon",
}

CHEST_BRIEF = """You are generating ONE game sprite master with your built-in image_gen tool. Read $CODEX_HOME/skills/.system/imagegen/SKILL.md first, then follow this brief exactly. Work only inside the current directory (the staging dir). Do NOT touch any file under C:\\Users\\asali\\Projects\\MMO.

Three images are attached:
- Image 1 = refs/1_style_hideout_barrel.png and Image 2 = refs/2_style_coffin.png : the STYLE benchmark — installed painterly world props of this game (low top-down three-quarter view, light from the top-left, soft painterly shading, NO black outlines, muted palette, crisp readable silhouette). Match their treatment exactly. They are NOT the subject.
- Image 3 = refs/3_subject_{key}.png : the CURRENT tiny (32px, upscaled) chest — its SHAPE, proportions, material and colour family are the identity to keep; its chunky pixels and black outlines are NOT the target.

TASK: generate exactly ONE new source sheet — ONE ROW of FIVE figures — of this chest OPENING, with this image_gen prompt (adapt only if the tool's parameters require it; keep every constraint). Use the tool's widest LANDSCAPE output size.

---
Use case: illustration-story
Asset type: high-resolution 5-frame game prop animation source, one horizontal row, to be cropped into a sprite strip. Landscape output canvas.
Input images: Images 1-2 are the binding style / perspective / shading benchmark; Image 3 is the subject's identity (shape, material, colours).
Scene/backdrop: a perfectly flat uniform #00ff00 chroma-key background filling every pixel, including the gaps between figures. No scenery, floor, ground plane, cast shadow, contact shadow, gradient, vignette, border, grid, line, panel divider, text or watermark. Do not use #00ff00 or any strong green in the figures.
Primary request: create exactly FIVE complete figures in ONE horizontal row, left to right, evenly spaced with a clear flat-green gutter between neighbours; no figure touches or is cropped by a neighbour or the canvas edge. All five are the SAME chest, at the SAME scale, SAME position within its slot and SAME ground line, seen from the SAME angle — only the LID moves and the light inside changes:
 f1 CLOSED at rest (this frame is also the static sprite).
 f2 the lid cracks open a few degrees; a thin line of warm light shows at the seam.
 f3 the lid half open (about 45°), warm light spilling out over the rim.
 f4 the lid fully open (about 100°, resting back), the brightest warm glow from inside, a few soft sparkle motes above the box.
 f5 open at rest: lid fully open, the inner glow softer, no motes.
Subject: {desc}. Same chest in every frame; the lid is hinged at the BACK edge and opens away from the viewer.
Style/medium: painterly, soft-shaded, no black outlines, muted dark-fantasy palette — exactly the treatment of Images 1-2; not pixel art, not cartoon, not 3D render, not anime; no thick outlines, no rim glow on the body.
Composition/framing: low top-down three-quarter view like Images 1-2 (we see the front and the top), light from the top-left, the chest about the same share of its slot in every frame; the open lid may rise above the closed silhouette but must stay inside its slot.
Constraints: output only the five figures on green; no text, watermark, UI, frame numbers, extra objects, scenery, shadow or separators. The body of the chest never moves, scales or changes colour between frames; only the lid and the inner light.
---

AFTER generation:
1. Copy the raw generated PNG (do not resize it) to ./{key}_open_master_v1.png in the current directory.
2. Run the skill's remove_chroma_key.py helper on it and write the keyed RGBA result to ./{key}_open_master_v1_keyed.png (auto-key sampling, despill on).
3. Do NOT slice, do NOT install, do NOT write anywhere under the MMO project. I will do the slicing.
4. In your final message, report: the raw output size, how many complete figures were produced, whether the body stays put across the five, whether the lid opens progressively f1→f4 and holds in f5, and any deviation from the brief (a body that moves or changes colour, figures touching, green in the figure, outlines, cartoon shading). Be blunt; do not soften defects.

If image_gen is unavailable, say so and stop; do not fall back to another provider or the CLI.
"""

COIN_BRIEF = """You are generating ONE game sprite master with your built-in image_gen tool. Read $CODEX_HOME/skills/.system/imagegen/SKILL.md first, then follow this brief exactly. Work only inside the current directory (the staging dir). Do NOT touch any file under C:\\Users\\asali\\Projects\\MMO.

Two images are attached:
- Image 1 = refs/1_style_hideout_barrel.png : the STYLE benchmark — an installed painterly world prop of this game (soft painterly shading, no black outlines, muted palette, light from the top-left). Match its treatment. It is NOT the subject.
- Image 2 = refs/2_subject_coin.png : the CURRENT coin — a round gold coin with an embossed CROWN on its face; keep that identity (round, gold, crown face, plain rim), but give it real depth: a bevelled rim, a specular highlight, a darker lower edge.

TASK: generate exactly ONE new source sheet — ONE ROW of SIX figures — of this coin TURNING about its vertical axis, with this image_gen prompt (adapt only if the tool's parameters require it; keep every constraint). Use the tool's widest LANDSCAPE output size.

---
Use case: illustration-story
Asset type: high-resolution 6-frame game pickup spin-cycle source, one horizontal row, to be cropped into a sprite strip. Landscape output canvas.
Input images: Image 1 is the binding style benchmark; Image 2 is the coin's identity.
Scene/backdrop: a perfectly flat uniform #00ff00 chroma-key background filling every pixel, including the gaps between figures. No scenery, floor, shadow, gradient, border, grid, line, text or watermark. Do not use #00ff00 or any strong green in the figures.
Primary request: create exactly SIX complete figures in ONE horizontal row, left to right, evenly spaced with a clear flat-green gutter between neighbours; none touches a neighbour or the canvas edge. All six are the SAME coin at the SAME scale, the SAME height (its full diameter, top to bottom, never changes) and CENTRED at the same height in each slot; the coin turns about its VERTICAL axis by 60° per frame, so only its apparent WIDTH and the highlight change:
 f1 full face (a perfect circle, crown face, highlight upper-left).
 f2 turned 60° (an upright ellipse about half as wide as it is tall; the crown foreshortened; the bevelled rim visible on one side).
 f3 turned 120° (a narrow upright ellipse about a quarter as wide as tall; mostly rim, a sliver of face).
 f4 EDGE-ON (a thin bright upright bar of rim, the full diameter tall, a few pixels wide).
 f5 turned 240° (narrow ellipse, the REVERSE face — the same crown design — showing).
 f6 turned 300° (half-wide ellipse, reverse face) — flowing back into f1.
Subject: a round gold coin, warm antique gold with a bevelled rim, an embossed crown on both faces, a specular highlight upper-left and a darker lower edge; clean, not cartoon-shiny.
Style/medium: painterly, soft-shaded, no black outlines, exactly the treatment of Image 1; not pixel art, not cartoon, not 3D render.
Constraints: output only the six coins on green; no text, watermark, sparkles, motion lines, shadow or separators. The diameter (height) is identical in every frame; the vertical centre is identical; only the width narrows toward f4 and widens again.
---

AFTER generation:
1. Copy the raw generated PNG (do not resize it) to ./coin_spin_master_v1.png in the current directory.
2. Run the skill's remove_chroma_key.py helper on it and write the keyed RGBA result to ./coin_spin_master_v1_keyed.png (auto-key sampling, despill on).
3. Do NOT slice, do NOT install, do NOT write anywhere under the MMO project. I will do the slicing.
4. In your final message, report: the raw output size, how many coins were produced, whether the height is constant across all six, whether f4 is edge-on and f1 full face, and any deviation (a coin that changes height, touches a neighbour, green in the coin). Be blunt; do not soften defects.

If image_gen is unavailable, say so and stop; do not fall back to another provider or the CLI.
"""


def _subject_ref(key: str, dst: str) -> None:
    im = Image.open(os.path.join(SPR, key + ".png")).convert("RGBA")
    if im.width < 100:
        im = im.resize((im.width * 4, im.height * 4), Image.NEAREST)
    im.save(dst)


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("root")
    ap.add_argument("--only", default="")
    args = ap.parse_args()
    only = [s for s in args.only.split(",") if s]
    stages = []
    for key, desc in CHESTS.items():
        if only and key not in only:
            continue
        stage = os.path.join(args.root, key)
        refs = os.path.join(stage, "refs")
        os.makedirs(refs, exist_ok=True)
        for i, r in enumerate(STYLE_REFS, 1):
            shutil.copy(os.path.join(SPR, r + ".png"), os.path.join(refs, "%d_style_%s.png" % (i, r)))
        _subject_ref(key, os.path.join(refs, "3_subject_%s.png" % key))
        with open(os.path.join(stage, "codex_brief.txt"), "w", encoding="utf-8") as f:
            f.write(CHEST_BRIEF.format(key=key, desc=desc))
        stages.append(stage)
    if not only or "coin" in only:
        stage = os.path.join(args.root, "coin")
        refs = os.path.join(stage, "refs")
        os.makedirs(refs, exist_ok=True)
        shutil.copy(os.path.join(SPR, "hideout_barrel.png"), os.path.join(refs, "1_style_hideout_barrel.png"))
        _subject_ref("coin", os.path.join(refs, "2_subject_coin.png"))
        with open(os.path.join(stage, "codex_brief.txt"), "w", encoding="utf-8") as f:
            f.write(COIN_BRIEF)
        stages.append(stage)
    lst = os.path.join(args.root, "stages.txt")
    open(lst, "w").write(",".join(stages))
    print("stages: %d -> %s" % (len(stages), lst))


if __name__ == "__main__":
    main()
