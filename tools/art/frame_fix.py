#!/usr/bin/env python
"""Surgical, deterministic edits to an INSTALLED strip — the cheapest rung of
the drift-fix taxonomy (despill < FRAME EDIT < single-strip regen < full-clip
regen, tools/art/DRIFT_AUDIT.md), for defects a regen would be overkill for:

  --drop-orphans        erase every connected component that is not the body,
                        smaller than --orphan-max of it, in the listed cells
                        (sliced-off neighbour limbs, detached ghost chunks).
  --scale F             re-render every cell at F about its own FEET line and
                        cell-centre x (a clip that plays 7-15 % off the idle
                        body — the CLIPSCALE family), keeping the ground point.
  --shift-cell N=DX,DY  nudge one cell (a frame the generator placed off-centre).
  --feet-pin            pin every cell's lowest opaque row to --feet (default:
                        the strip's own frame-0 feet row), killing FEETSLIDE.

    python tools/art/frame_fix.py <strip.png> --drop-orphans 1,2 [--dry]
    python tools/art/frame_fix.py <strip.png> --scale 0.93 --feet-pin
    python tools/art/frame_fix.py <strip.png> --shift-cell 3=25,0

Always writes a backup beside the file the first time (`<name>.pre_fix.png`)
unless --no-backup, and writes atomically. Re-run verify_art afterwards.
"""
from __future__ import annotations

import argparse
import shutil
import sys
from pathlib import Path

import numpy as np
from PIL import Image

A = 40


def cells_of(im: Image.Image) -> tuple[int, int]:
    c = im.height
    return c, max(1, im.width // c)


def _bbox(alpha: np.ndarray):
    ys, xs = np.nonzero(alpha > A)
    if not len(ys):
        return None
    return int(xs.min()), int(ys.min()), int(xs.max()), int(ys.max())


def drop_orphans(a: np.ndarray, cell: int, n: int, which: set[int], frac: float) -> int:
    from scipy import ndimage
    removed = 0
    for f in range(n):
        if which and f not in which:
            continue
        sl = a[:, f * cell:(f + 1) * cell]
        m = sl[:, :, 3] > A
        lab, cnt = ndimage.label(m)
        if cnt <= 1:
            continue
        sizes = ndimage.sum(m, lab, range(1, cnt + 1))
        main = int(np.argmax(sizes)) + 1
        for i in range(1, cnt + 1):
            if i == main or sizes[i - 1] > frac * sizes[main - 1]:
                continue
            mm = lab == i
            sl[:, :, 3] = np.where(mm, 0, sl[:, :, 3])
            removed += int(sizes[i - 1])
    return removed


def rescale_cells(a: np.ndarray, cell: int, n: int, factor: float) -> np.ndarray:
    out = np.zeros_like(a)
    for f in range(n):
        sl = a[:, f * cell:(f + 1) * cell]
        bb = _bbox(sl[:, :, 3])
        if bb is None:
            continue
        img = Image.fromarray(sl, "RGBA")
        w, h = max(1, int(round(cell * factor))), max(1, int(round(cell * factor)))
        small = np.asarray(img.resize((w, h), Image.LANCZOS))
        sb = _bbox(small[:, :, 3])
        if sb is None:
            continue
        # keep the feet line and the horizontal centre of the ORIGINAL cell
        dx = int(round((bb[0] + bb[2]) / 2 - (sb[0] + sb[2]) / 2))
        dy = int(round(bb[3] - sb[3]))
        tgt = out[:, f * cell:(f + 1) * cell]
        for y in range(h):
            ty = y + dy
            if not (0 <= ty < cell):
                continue
            xs0, xs1 = max(0, dx), min(cell, dx + w)
            if xs1 <= xs0:
                continue
            src = small[y, max(0, -dx):max(0, -dx) + (xs1 - xs0)]
            keep = src[:, 3] > 0
            tgt[ty, xs0:xs1][keep] = src[keep]
    return out


def shift_cell(a: np.ndarray, cell: int, f: int, dx: int, dy: int) -> None:
    sl = a[:, f * cell:(f + 1) * cell].copy()
    a[:, f * cell:(f + 1) * cell] = 0
    tgt = a[:, f * cell:(f + 1) * cell]
    ys = slice(max(0, dy), min(cell, cell + dy))
    xs = slice(max(0, dx), min(cell, cell + dx))
    sy = slice(max(0, -dy), min(cell, cell - dy))
    sx = slice(max(0, -dx), min(cell, cell - dx))
    tgt[ys, xs] = sl[sy, sx]


def feet_pin(a: np.ndarray, cell: int, n: int, feet: int | None) -> int:
    base = feet
    if base is None:
        bb = _bbox(a[:, 0:cell, 3])
        if bb is None:
            return 0
        base = bb[3]
    moved = 0
    for f in range(n):
        sl = a[:, f * cell:(f + 1) * cell]
        bb = _bbox(sl[:, :, 3])
        if bb is None:
            continue
        dy = base - bb[3]
        if dy == 0:
            continue
        shift_cell(a, cell, f, 0, dy)
        moved += 1
    return moved


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("path")
    ap.add_argument("--drop-orphans", default=None, help="cell indices, or 'all'")
    ap.add_argument("--orphan-max", type=float, default=0.20,
                    help="a component this fraction of the body or smaller is an orphan")
    ap.add_argument("--scale", type=float, default=None)
    ap.add_argument("--shift-cell", action="append", default=[], help="N=DX,DY")
    ap.add_argument("--feet-pin", action="store_true")
    ap.add_argument("--feet", type=int, default=None)
    ap.add_argument("--no-backup", action="store_true")
    ap.add_argument("--dry", action="store_true")
    args = ap.parse_args()

    p = Path(args.path)
    im = Image.open(p).convert("RGBA")
    cell, n = cells_of(im)
    a = np.asarray(im).copy()
    print(f"{p.name}: {n} cell(s) of {cell}px")

    if args.drop_orphans is not None:
        which = set() if args.drop_orphans == "all" else {
            int(x) for x in args.drop_orphans.split(",") if x.strip() != ""}
        px = drop_orphans(a, cell, n, which, args.orphan_max)
        print(f"  dropped {px} orphan px")
    if args.scale is not None:
        a = rescale_cells(a, cell, n, args.scale)
        print(f"  rescaled every cell x{args.scale} about its feet line")
    for spec in args.shift_cell:
        idx, d = spec.split("=")
        dx, dy = (int(v) for v in d.split(","))
        shift_cell(a, cell, int(idx), dx, dy)
        print(f"  shifted cell {idx} by ({dx},{dy})")
    if args.feet_pin:
        moved = feet_pin(a, cell, n, args.feet)
        print(f"  feet-pinned {moved} cell(s)")

    if args.dry:
        print("  DRY (nothing written)")
        return 0
    bak = p.with_name(p.stem + ".pre_fix.png")
    if not args.no_backup and not bak.exists():
        shutil.copy2(p, bak)
    tmp = p.with_name(f".{p.stem}.fix.tmp.png")
    Image.fromarray(a, "RGBA").save(tmp, optimize=True)
    tmp.replace(p)
    print(f"  wrote {p}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
