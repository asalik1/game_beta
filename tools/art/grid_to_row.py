#!/usr/bin/env python
"""Flatten a multi-row Codex figure grid (e.g. two rows of three, requested so
each figure comes back near full cell size for a 900-1000px boss cell) into the
single green row install_gait_row expects. Row bands are found from fully-green
horizontal gaps, figures within a band from green column gaps; reading order is
top row left to right, then the next row.

    python tools/art/grid_to_row.py <grid.png> <row.png> [--gap N]
"""
import argparse
import numpy as np
from PIL import Image

GREEN = (0, 255, 0, 255)


def runs_of(mask, gap):
    out, on, s = [], False, 0
    for i, v in enumerate(mask):
        if v and not on:
            on, s = True, i
        elif not v and on:
            on = False
            out.append([s, i])
    if on:
        out.append([s, len(mask)])
    merged = []
    for r in out:
        if merged and r[0] - merged[-1][1] < gap:
            merged[-1][1] = r[1]
        else:
            merged.append(r)
    return merged


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("grid")
    ap.add_argument("out")
    ap.add_argument("--gap", type=int, default=8, help="content runs closer than this merge (a held item off the body)")
    ap.add_argument("--pad", type=int, default=40)
    a = ap.parse_args()
    im = Image.open(a.grid).convert("RGBA")
    arr = np.array(im)
    g = (arr[:, :, 1] > 180) & (arr[:, :, 0] < 110) & (arr[:, :, 2] < 110)
    fg = ~g & (arr[:, :, 3] > 0)
    bands = [b for b in runs_of(fg.any(axis=1), a.gap) if b[1] - b[0] > 40]
    figs = []
    for y0, y1 in bands:
        band = fg[y0:y1]
        for x0, x1 in runs_of(band.any(axis=0), a.gap):
            if x1 - x0 < 24:
                continue
            ys = np.nonzero(band[:, x0:x1].any(axis=1))[0]
            figs.append(im.crop((x0, y0 + int(ys.min()), x1, y0 + int(ys.max()) + 1)))
    if not figs:
        raise SystemExit("no figures found")
    h = max(f.height for f in figs)
    cell = max(f.width for f in figs) + a.pad
    out = Image.new("RGBA", (cell * len(figs) + a.pad, h + 2 * a.pad), GREEN)
    for i, f in enumerate(figs):
        out.alpha_composite(f, (a.pad + i * cell + (cell - a.pad - f.width) // 2, a.pad + (h - f.height)))
    out.save(a.out)
    print(f"{len(bands)} rows, {len(figs)} figures, heights {[f.height for f in figs]}; wrote {a.out} {out.size}")


if __name__ == "__main__":
    main()
