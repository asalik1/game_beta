#!/usr/bin/env python
"""Repair animation strips whose figures were assembled OFF the square-cell
grid (the 2026-07-26 mob refresh: every 4x192 sheet drifted its figure
10-55px leftward across the cells, many with a weapon bleeding across the
cell boundary — on screen the mob visibly slides side to side each loop;
the training dummy made it obvious on the borrowed skeleton body).

Method (X only — the ground line is clean in every audited sheet):
  1. Column-occupancy bands over the WHOLE sheet segment the figures, so a
     sword that bled across a cell boundary is reunited with its owner.
  2. Bands are reconciled to the expected frame count: detached FX blobs
     merge into the figure across the smallest gap; two figures whose spans
     touch are split at the sparsest interior column valley.
  3. Each figure is re-centred in a fresh cell anchored on its FEET-BAND
     centroid (bottom 25% of the figure's opaque rows) — the feet are the
     stable landmark, so attack lunges keep their reach and the body stays
     planted. Statics (one cell) recentre the same way.

Verify pass (no --apply) prints per-frame anchor drift and changes nothing.
"""
from __future__ import annotations

import argparse
from pathlib import Path

from PIL import Image

ALPHA_THR = 25
FEET_FRAC = 0.25   # bottom fraction of the figure's opaque rows = the anchor band
BAND_GAP = 2       # empty columns tolerated inside one figure (anti-aliased edges)


def save_png(image: Image.Image, output: Path) -> None:
    """Atomic replace so importers never observe a partial strip."""
    temporary = output.with_name(f".{output.stem}.recenter.tmp.png")
    image.save(temporary, optimize=True)
    temporary.replace(output)


def column_profile(im: Image.Image) -> list[int]:
    a = im.getchannel("A").point(lambda v: 1 if v > ALPHA_THR else 0)
    w, h = im.size
    data = list(a.getdata())
    return [sum(data[y * w + x] for y in range(h)) for x in range(w)]


def bands_from_profile(profile: list[int], gap: int) -> list[tuple[int, int]]:
    out: list[tuple[int, int]] = []
    start = None
    run = 0
    for x, v in enumerate(profile):
        if v:
            if start is None:
                start = x
            run = 0
        elif start is not None:
            run += 1
            if run > gap:
                out.append((start, x - run))
                start = None
    if start is not None:
        out.append((start, len(profile) - 1))
    return out


def reconcile(bands: list[tuple[int, int]], profile: list[int],
              frames: int) -> list[tuple[int, int]]:
    bands = list(bands)
    # Too many bands: detached FX blobs — merge across the smallest gap.
    while len(bands) > frames:
        gaps = [bands[i + 1][0] - bands[i][1] for i in range(len(bands) - 1)]
        i = gaps.index(min(gaps))
        bands[i:i + 2] = [(bands[i][0], bands[i + 1][1])]
    # Too few: two figures' spans touch — split the widest band at its
    # sparsest interior column (the valley between the two silhouettes).
    while len(bands) < frames:
        i = max(range(len(bands)), key=lambda k: bands[k][1] - bands[k][0])
        lo, hi = bands[i]
        margin = (hi - lo) // 4
        valley = min(range(lo + margin, hi - margin + 1), key=lambda x: profile[x])
        bands[i:i + 1] = [(lo, valley), (valley + 1, hi)]
        bands.sort()
    return bands


def feet_anchor_x(cell: Image.Image) -> float | None:
    """Centroid x of the bottom FEET_FRAC of the figure's opaque rows."""
    a = cell.getchannel("A").point(lambda v: 1 if v > ALPHA_THR else 0)
    bbox = a.getbbox()
    if bbox is None:
        return None
    top = bbox[3] - max(1, round((bbox[3] - bbox[1]) * FEET_FRAC))
    w = cell.width
    data = list(a.getdata())
    sx = n = 0
    for y in range(top, bbox[3]):
        row = y * w
        for x in range(bbox[0], bbox[2]):
            if data[row + x]:
                sx += x
                n += 1
    return sx / n if n else None


def repair(path: Path, apply: bool, max_ok_drift: float) -> str:
    im = Image.open(path).convert("RGBA")
    w, h = im.size
    if h == 0 or w % h:
        return f"SKIP {path.name}: {w}x{h} not square-cell"
    frames = w // h
    profile = column_profile(im)
    bands = reconcile(bands_from_profile(profile, BAND_GAP), profile, frames)
    if len(bands) != frames:
        return f"FAIL {path.name}: cannot resolve {frames} figures"

    cells: list[Image.Image] = []
    shifts: list[int] = []
    for f, (lo, hi) in enumerate(bands):
        segment = im.crop((lo, 0, hi + 1, h))
        anchor = feet_anchor_x(segment)
        if anchor is None:
            cells.append(Image.new("RGBA", (h, h)))
            shifts.append(0)
            continue
        paste_x = round(h / 2 - anchor)
        cell = Image.new("RGBA", (h, h))
        cell.alpha_composite(segment, (max(paste_x, 0), 0),
                             (max(-paste_x, 0), 0))
        cells.append(cell)
        # drift = how far this figure's anchor sat from ITS OWN cell's centre
        shifts.append(round((lo + anchor) - (f * h + h / 2)))

    drift = max(shifts) - min(shifts) if shifts else 0
    worst = max(abs(s) for s in shifts) if shifts else 0
    if worst <= max_ok_drift and drift <= max_ok_drift:
        return f"OK   {path.name}: anchors already centred (worst {worst}px)"
    if apply:
        out = Image.new("RGBA", (w, h))
        for f, cell in enumerate(cells):
            out.alpha_composite(cell, (f * h, 0))
        save_png(out, path)
    verb = "FIXED" if apply else "WOULD FIX"
    return f"{verb} {path.name}: per-frame anchor offsets {shifts} (drift {drift}px)"


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("paths", nargs="+", type=Path)
    ap.add_argument("--apply", action="store_true",
                    help="rewrite the strips (default: report only)")
    ap.add_argument("--tolerance", type=float, default=3.0,
                    help="max anchor offset (px) considered healthy")
    args = ap.parse_args()
    for p in args.paths:
        print(repair(p, args.apply, args.tolerance))


if __name__ == "__main__":
    main()
