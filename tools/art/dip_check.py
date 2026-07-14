"""dip_check — flag a character whose weapon dips BELOW its feet per direction
(the "sword digs into the terrain" class of bug, e.g. Stormforged's greatsword).

For each rotation/frame PNG it finds the FEET row (lowest row at least 25% as wide
as the widest row — a thin blade tip is narrower and ignored) and the lowest
opaque pixel (the weapon tip), and reports the gap. A large gap = the weapon
hangs below the feet and will overlap the floor in a top-down view.

*** GUIDE ONLY — NOT GROUND TRUTH. ***
This is a heuristic (owner-confirmed 2026-07-14 that it "is good but not always
accurate"). The 25%-width feet test can misread capes, wide stances, energy FX,
or a blade held forward-horizontal. A few px of gap is usually fine and reads
correctly in-game. ALWAYS confirm the actual look with the OWNER in-game before
acting on these numbers — do not reject/regenerate art on this script alone.

Usage:
  python dip_check.py <dir_of_pngs>            # measures every *.png in the dir
  python dip_check.py <char_dir>/rotations     # a PixelLab char's 8 rotations
"""
import sys, glob, os
from PIL import Image
import numpy as np

ORDER = ["south", "south-east", "east", "north-east",
         "north", "north-west", "west", "south-west"]


def gap(path):
    a = np.asarray(Image.open(path).convert("RGBA"))[:, :, 3] > 40
    if not a.any():
        return None
    w = a.sum(axis=1)
    mx = w.max()
    ys = np.where(a.any(axis=1))[0]
    top, bot = int(ys.min()), int(ys.max())
    feet = top
    for y in range(bot, top - 1, -1):        # scan up for the lowest WIDE row
        if w[y] >= 0.25 * mx:
            feet = y
            break
    return bot - feet                         # px the weapon tip hangs below the feet


def main():
    d = sys.argv[1]
    files = {os.path.basename(f)[:-4]: f for f in glob.glob(os.path.join(d, "*.png"))}
    keys = [k for k in ORDER if k in files] or sorted(files)
    print("=== dip_check: weapon-below-feet (px) — GUIDE ONLY, confirm in-game ===")
    worst = 0
    for k in keys:
        g = gap(files[k])
        if g is None:
            continue
        flag = "  <-- check" if g > 8 else ""
        print("  %-12s %3dpx%s" % (k, g, flag))
        worst = max(worst, g)
    print("worst: %dpx  (a few px is normal; only the OWNER decides if it reads wrong)" % worst)


if __name__ == "__main__":
    main()
