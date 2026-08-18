"""Description-led re-rolls for props whose SUBJECT ref is itself unreadable at
16px (the repaint faithfully reproduces a shape nobody wants: clay_pot2 came
back as a terracotta shard, candelabra as a blue cross). Painterly style ref,
NO subject ref, the object described in words. Appends to <stage_root>/stages.txt.

  python rerolls.py <stage_root> [name ...]
"""
import argparse, os, shutil, sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from _common import SPR  # noqa: E402

PLAN = {
    "clay_pot2": ("clay_pot", "a small round-bellied earthenware jar TIPPED ON ITS SIDE on the ground, its open rim turned toward the viewer's lower-left, terracotta with a darker fired band round the shoulder and a hairline crack in the belly; a plain household pot, no glaze, no pattern"),
    "candelabra": ("keep_brazier", "a wrought-iron floor CANDELABRA: a slim dark iron stem rising from a three-footed round base, branching into three curved arms that each hold a pale tallow candle with a small warm flame (a fourth candle on the central spike); a little wax drip, dull black iron with a faint rust bloom, no gold"),
}

BRIEF = """Generate ONE game prop for a top-down dark-fantasy action RPG, in the rendering style of a reference.

Reference image 1_style_{ref}.png (STYLE): a finished prop from this game — painterly, softly shaded, fine natural detail, NO black outlines, muted somber palette, light from the top-left, top-down three-quarter view. Match this rendering style exactly.

THE PROP: {desc}. Same view angle as the reference (top-down three-quarter, seen from slightly above).

Generate ONE image of that prop, filling most of the canvas, centred, on a flat solid pure-green (#00FF00) background. No cast shadow on the ground, no ground plane, no other objects, no text, no frame. Square 1024x1024. Muted saturation (a somber world): no cartoon outlines, no neon, no glow beyond the candle flames themselves.

Save the PNG to exactly this path: {out}/{name}.png
Then reply with one line describing what you drew.
"""


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("stage_root")
    ap.add_argument("names", nargs="*")
    a = ap.parse_args()
    stages = []
    for name, (ref, desc) in PLAN.items():
        if a.names and name not in a.names:
            continue
        stage = os.path.join(a.stage_root, name)
        refs = os.path.join(stage, "refs")
        os.makedirs(refs, exist_ok=True)
        shutil.copy(os.path.join(SPR, ref + ".png"), os.path.join(refs, "1_style_%s.png" % ref))
        with open(os.path.join(stage, "codex_brief.txt"), "w", encoding="utf-8") as f:
            f.write(BRIEF.format(ref=ref, name=name, desc=desc, out=stage.replace("\\", "/")))
        stages.append(stage)
    lst = os.path.join(a.stage_root, "stages.txt")
    cur = open(lst).read().strip() if os.path.exists(lst) else ""
    with open(lst, "w") as f:
        f.write((cur + "," if cur else "") + ",".join(stages))
    print("appended:", [os.path.basename(s) for s in stages])


if __name__ == "__main__":
    main()
