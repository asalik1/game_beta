"""mobqa_filmstrip — assemble the shot_mobqa.gd rig's screenshots into one
filmstrip PNG per mob (rows idle / walk / attack, 4 frames each) so the
in-engine result of a strip install can be eyeballed the way the owner sees it:
same camera, same _apply_strip path, feet line drawn from the idle frame so a
body that jumps, shrinks or vanishes on walk/attack is obvious.

Run the rig first (windowed):
  tools\\Godot_v4.4.1-stable_win64_console.exe --path game res://shot_mobqa.tscn
Then:
  python tools/art/mobqa_filmstrip.py [--out <dir>] [--half W] [--zoom Z]

Reads user://shots/mobqa/{idle,walk,attack}_f{0..3}.png + mobqa_index.txt
(one "kind sprite_key screen_x screen_y" line per mob, written by the rig).
Writes <out>/mobqa_<sprite_key>.png (default out = the shots dir).
"""
import argparse
import os
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFont

SHOTS = os.path.join(os.environ.get("APPDATA", ""), "Godot", "app_userdata",
                     "Crownless", "shots", "mobqa")
STATES = ("idle", "walk", "attack")


def _font(sz):
    try:
        return ImageFont.truetype(r"C:\Windows\Fonts\arialbd.ttf", sz)
    except Exception:
        return ImageFont.load_default()


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    ap.add_argument("--shots", default=SHOTS)
    ap.add_argument("--out", default=None)
    ap.add_argument("--half", type=int, default=120,
                    help="half-width of the crop around each mob (px, screen)")
    ap.add_argument("--above", type=int, default=190, help="crop rows above the anchor")
    ap.add_argument("--below", type=int, default=60, help="crop rows below the anchor")
    ap.add_argument("--zoom", type=int, default=2, help="NEAREST upscale of each crop")
    a = ap.parse_args()
    out = a.out or a.shots
    os.makedirs(out, exist_ok=True)
    idx = os.path.join(a.shots, "mobqa_index.txt")
    if not os.path.exists(idx):
        print("no mobqa_index.txt in", a.shots, "-- run the rig first")
        return 1
    mobs = []
    for line in open(idx, encoding="utf-8"):
        parts = line.split()
        if len(parts) == 4:
            mobs.append((parts[0], parts[1], float(parts[2]), float(parts[3])))
    shots = {}
    for st in STATES:
        for f in range(4):
            p = os.path.join(a.shots, f"{st}_f{f}.png")
            if os.path.exists(p):
                shots[(st, f)] = Image.open(p).convert("RGBA")
    if not shots:
        print("no shots found in", a.shots)
        return 1
    font = _font(14)
    z = a.zoom
    cw, ch = 2 * a.half, a.above + a.below
    for kind, key, sx, sy in mobs:
        x0, y0 = int(sx - a.half), int(sy - a.above)
        strip = Image.new("RGBA", (34 * z + 4 * (cw * z + 6), 4 + 3 * (ch * z + 22)),
                          (30, 30, 34, 255))
        d = ImageDraw.Draw(strip)
        # idle feet reference: lowest non-background row change vs the frame-0
        # crop is not derivable from a screenshot alone; draw the rig-reported
        # anchor row (sprite origin) instead and the crops' shared baseline.
        base_y = a.above  # sprite origin row inside every crop
        for r, st in enumerate(STATES):
            yy = 4 + r * (ch * z + 22)
            d.text((4, yy + ch * z // 2 - 8), st, fill=(255, 255, 255, 255), font=font)
            for f in range(4):
                im = shots.get((st, f))
                xx = 34 * z + f * (cw * z + 6)
                if im is None:
                    continue
                crop = im.crop((x0, y0, x0 + cw, y0 + ch)).resize((cw * z, ch * z), Image.NEAREST)
                strip.alpha_composite(crop, (xx, yy))
                d.rectangle([xx, yy, xx + cw * z - 1, yy + ch * z - 1], outline=(255, 80, 80, 255))
                # sprite-origin row (mob position): identical for every state,
                # so a body that lifts/drops relative to it is a real anchor bug
                d.line([(xx, yy + base_y * z), (xx + cw * z, yy + base_y * z)],
                       fill=(255, 255, 0, 160))
                d.text((xx + 3, yy + ch * z + 3), f"f{f + 1}", fill=(255, 255, 255, 255), font=font)
        p = os.path.join(out, f"mobqa_{key}.png")
        strip.save(p)
        print("wrote", p, f"({kind})")
    return 0


if __name__ == "__main__":
    sys.exit(main())
