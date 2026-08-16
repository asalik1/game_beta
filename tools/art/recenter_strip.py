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

--anchor head (2026-08-15, Morwen Codex wave-1): the feet band is the wrong
landmark for a HOVERING caster whose "feet" are a wet mist hem — the hem
sweeps left/right on purpose in her glide, and an attack's spell can widen
the bottom rows — so anchor on the HEAD band (top HEAD_FRAC of the opaque
rows: halo + hood) instead. Her strips were quadrant-sliced from a 2x2
ImageGen master, so frames 1/3 (left column) and 2/4 (right column) sat at
two different offsets: an 18-20px alternating slide every loop.
--grow lets a cell widen (stays SQUARE; the engine's oversized-ability-cell
path renders the body at the idle scale and re-anchors by feet) when a
recentred figure would otherwise clip at the cell edge — a cast whose burst
reaches far past the body needs the room the master never gave it.
"""
from __future__ import annotations

import argparse
from pathlib import Path

from PIL import Image

ALPHA_THR = 25
FEET_FRAC = 0.25   # bottom fraction of the figure's opaque rows = the anchor band
HEAD_FRAC = 0.10   # top tenth of the figure's opaque rows = halo + hood CROWN only
                   # (a wider band reached chin level and a chest-high spell
                   # burst dragged the anchor toward itself — build_codex_2x2_strip)
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


def head_anchor_x(cell: Image.Image) -> float | None:
    """Centre x of the top HEAD_FRAC of the figure's opaque rows (halo + hood).
    Uses the band's bbox midpoint rather than its centroid: a lopsided halo
    streak or hood highlight must not pull the anchor sideways."""
    a = cell.getchannel("A").point(lambda v: 1 if v > ALPHA_THR else 0)
    bbox = a.getbbox()
    if bbox is None:
        return None
    bottom = bbox[1] + max(1, round((bbox[3] - bbox[1]) * HEAD_FRAC))
    band = a.crop((0, bbox[1], cell.width, bottom)).getbbox()
    if band is None:
        return None
    return (band[0] + band[2]) / 2.0


def repair(path: Path, apply: bool, max_ok_drift: float,
           anchor_mode: str = "feet", grow: bool = False) -> str:
    im = Image.open(path).convert("RGBA")
    w, h = im.size
    if h == 0 or w % h:
        return f"SKIP {path.name}: {w}x{h} not square-cell"
    frames = w // h
    profile = column_profile(im)
    bands = reconcile(bands_from_profile(profile, BAND_GAP), profile, frames)
    if len(bands) != frames:
        return f"FAIL {path.name}: cannot resolve {frames} figures"
    anchor_fn = head_anchor_x if anchor_mode == "head" else feet_anchor_x

    # Pass 1: measure every figure's anchor and how far it reaches either side
    # of that anchor, so a --grow cell is sized once for the whole strip.
    segs: list[tuple[Image.Image, float | None]] = []
    shifts: list[int] = []
    reach = 0.0
    for f, (lo, hi) in enumerate(bands):
        segment = im.crop((lo, 0, hi + 1, h))
        anchor = anchor_fn(segment)
        segs.append((segment, anchor))
        if anchor is None:
            shifts.append(0)
            continue
        # drift = how far this figure's anchor sat from ITS OWN cell's centre
        shifts.append(round((lo + anchor) - (f * h + h / 2)))
        seg_bbox = segment.getchannel("A").point(
            lambda v: 1 if v > ALPHA_THR else 0).getbbox()
        if seg_bbox is not None:
            reach = max(reach, anchor - seg_bbox[0], seg_bbox[2] - anchor)

    cell_px = h
    clipped: list[int] = []
    if reach * 2.0 + 2.0 > h:
        if grow:
            cell_px = int(reach * 2.0 + 2.0)
            cell_px += cell_px % 2  # even cell keeps a clean integer centre
        else:
            clipped = [f for f, (seg, anc) in enumerate(segs)
                       if anc is not None and (
                           anc > h / 2.0 or seg.width - anc > h / 2.0)]

    cells: list[Image.Image] = []
    for segment, anchor in segs:
        cell = Image.new("RGBA", (cell_px, cell_px))
        if anchor is not None:
            paste_x = round(cell_px / 2 - anchor)
            # Bottom-align: a grown cell keeps every hem row where it was
            # relative to the cell floor, so the engine's frame-0 feet line
            # (lowest opaque row) lands on the idle body unchanged.
            paste_y = cell_px - h
            cell.alpha_composite(segment, (max(paste_x, 0), paste_y),
                                 (max(-paste_x, 0), 0))
        cells.append(cell)

    drift = max(shifts) - min(shifts) if shifts else 0
    worst = max(abs(s) for s in shifts) if shifts else 0
    if worst <= max_ok_drift and drift <= max_ok_drift and cell_px == h:
        return (f"OK   {path.name}: {anchor_mode} anchors already centred "
                f"(worst {worst}px)")
    note = ""
    if cell_px != h:
        note = f"; cell grown {h}->{cell_px}px so the widest figure fits"
    elif clipped:
        note = (f"; WARNING frames {[c + 1 for c in clipped]} clip at the "
                f"cell edge once centred (rerun with --grow)")
    if apply:
        out = Image.new("RGBA", (cell_px * frames, cell_px))
        for f, cell in enumerate(cells):
            out.alpha_composite(cell, (f * cell_px, 0))
        save_png(out, path)
    verb = "FIXED" if apply else "WOULD FIX"
    return (f"{verb} {path.name}: per-frame {anchor_mode} anchor offsets "
            f"{shifts} (drift {drift}px){note}")


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("paths", nargs="+", type=Path)
    ap.add_argument("--apply", action="store_true",
                    help="rewrite the strips (default: report only)")
    ap.add_argument("--tolerance", type=float, default=3.0,
                    help="max anchor offset (px) considered healthy")
    ap.add_argument("--anchor", choices=("feet", "head"), default="feet",
                    help="landmark to centre on: feet band (default) or the "
                         "head band (hovering casters whose hem sweeps)")
    ap.add_argument("--grow", action="store_true",
                    help="widen the square cell instead of clipping a figure "
                         "that reaches past the edge once centred")
    args = ap.parse_args()
    for p in args.paths:
        print(repair(p, args.apply, args.tolerance, args.anchor, args.grow))


if __name__ == "__main__":
    main()
