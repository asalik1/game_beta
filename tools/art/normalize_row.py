#!/usr/bin/env python
"""Equalise figure heights in a Codex row (the "two small figures crammed into
one cell" defect): gutter-slice the green row, scale every figure to the
median figure height, re-lay them evenly on fresh green. Feed the result to
install_gait_row.

    python tools/art/normalize_row.py <row.png> <out.png> [--gap N]
"""
import argparse
import numpy as np
from PIL import Image

GREEN = (0, 255, 0, 255)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("row")
    ap.add_argument("out")
    ap.add_argument("--gap", type=int, default=6, help="content runs closer than this merge")
    ap.add_argument("--pad", type=int, default=40)
    a = ap.parse_args()
    im = Image.open(a.row).convert("RGBA")
    arr = np.array(im)
    g = (arr[:, :, 1] > 180) & (arr[:, :, 0] < 110) & (arr[:, :, 2] < 110)
    fg = ~g & (arr[:, :, 3] > 0)
    cols = fg.any(axis=0)
    runs, on, s = [], False, 0
    for x, c in enumerate(cols):
        if c and not on:
            on, s = True, x
        elif not c and on:
            on = False
            runs.append([s, x])
    if on:
        runs.append([s, len(cols)])
    merged = []
    for r in runs:
        if merged and r[0] - merged[-1][1] < a.gap:
            merged[-1][1] = r[1]
        else:
            merged.append(r)
    merged = [r for r in merged if r[1] - r[0] > 12]
    figs = []
    for x0, x1 in merged:
        ys = np.nonzero(fg[:, x0:x1].any(axis=1))[0]
        figs.append(im.crop((x0, int(ys.min()), x1, int(ys.max()) + 1)))
    hs = sorted(f.height for f in figs)
    target = hs[len(hs) // 2]
    scaled = []
    for f in figs:
        k = target / f.height
        scaled.append(f.resize((max(1, round(f.width * k)), target), Image.LANCZOS) if abs(k - 1) > 0.02 else f)
    cell = max(f.width for f in scaled) + a.pad
    out = Image.new("RGBA", (cell * len(scaled) + a.pad, target + 2 * a.pad), GREEN)
    for i, f in enumerate(scaled):
        out.alpha_composite(f, (a.pad + i * cell + (cell - a.pad - f.width) // 2, a.pad))
    out.save(a.out)
    print(f"{len(figs)} figures, heights {[f.height for f in figs]} -> {target}; wrote {a.out} {out.size}")


if __name__ == "__main__":
    main()
