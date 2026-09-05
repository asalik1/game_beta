#!/usr/bin/env python
"""Leg-cycle metrics for a biped walk strip (or a green row): per frame, which boot is
lifted (bottom-most alpha row per side of the torso centre), how far it lifts, and whether
the two boot blobs MERGE (a passing frame -- the swing boot crossing the planted one).

A real cycle alternates the lifted side and shows at least one merge per half; a scissor
shuffle shows tiny lifts, no merges, and one side lifted every time.

    python tools/art/gait_metrics.py <strip.png|row.png> [--band 0.14]
"""
import argparse
import numpy as np
from PIL import Image
from scipy import ndimage


def frames_of(path):
    im = Image.open(path).convert("RGBA")
    a = np.array(im)
    g = (a[:, :, 1] > 180) & (a[:, :, 0] < 110) & (a[:, :, 2] < 110)
    if g.mean() > 0.3:  # a green row: slice at gutters
        fg = ~g & (a[:, :, 3] > 0)
        cols = fg.any(axis=0)
        runs, on, s = [], False, 0
        for x, c in enumerate(cols):
            if c and not on:
                on, s = True, x
            elif not c and on:
                on = False
                runs.append((s, x))
        if on:
            runs.append((s, len(cols)))
        out = []
        for x0, x1 in runs:
            if x1 - x0 < 20:
                continue
            sub = a[:, x0:x1].copy()
            sub[g[:, x0:x1]] = 0
            out.append(sub)
        return out
    c = im.height
    return [a[:, f * c:(f + 1) * c] for f in range(im.width // c)]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("path")
    ap.add_argument("--band", type=float, default=0.14, help="boot band = bottom fraction of the body")
    args = ap.parse_args()
    rows = []
    for i, fr in enumerate(frames_of(args.path)):
        al = fr[:, :, 3] > 100
        ys, xs = np.nonzero(al)
        if not len(ys):
            rows.append((i, "empty")); continue
        top, bot = ys.min(), ys.max()
        cols = al[int(top + (bot - top) * 0.3):int(top + (bot - top) * 0.6)].sum(axis=0)
        cx = int((np.arange(al.shape[1]) * cols).sum() / max(1, cols.sum()))
        band = al[int(bot - (bot - top) * args.band):bot + 1]
        L, R = band[:, :cx], band[:, cx:]
        lb = np.nonzero(L.any(axis=1))[0].max() if L.any() else -1
        rb = np.nonzero(R.any(axis=1))[0].max() if R.any() else -1
        lab, k = ndimage.label(band)
        sizes = sorted(ndimage.sum(np.ones(lab.shape), lab, range(1, k + 1)), reverse=True)
        blobs = sum(1 for s in sizes if s > band.size * 0.01)
        lift = lb - rb
        side = "L" if lift < -2 else "R" if lift > 2 else "="
        rows.append((i, f"{side}({lift:+d})", "MERGE" if blobs == 1 else f"{blobs} blobs"))
    for r in rows:
        print(" ".join(str(x) for x in r))
    sides = [r[1][0] for r in rows if len(r) > 1]
    merges = sum(1 for r in rows if len(r) > 2 and r[2] == "MERGE")
    print(f"summary: lifted {''.join(sides)}  merges {merges}/{len(rows)}")


if __name__ == "__main__":
    main()
