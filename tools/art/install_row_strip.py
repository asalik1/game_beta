#!/usr/bin/env python3
"""Install a Codex row master as an engine strip, seated to the old strip's
per-frame geometry.

The gearlock lane (2026-08-27, paladin walk / archer idle coherence fixes)
generates ONE image per clip: a horizontal row of N figures on flat #00ff00
green (single-image generation keeps gear/face identity across frames far
better than per-frame re-rolls -- the per-frame archer face restore drifted
into four different outfits). This tool turns that row into a drop-in strip:

  1. slice the row into N equal cells
  2. chroma-key the green + despill the 2px rim (G > max(R,B)+20 edge band)
  3. tone-match the new content to the OLD strip's palette (per-channel
     mean/std over solid pixels -- generated masters come back brighter than
     the installed, in-game-judged art)
  4. re-seat each frame to the OLD strip's frame-i content geometry: body
     bbox height, feet baseline, centroid-x (the halla re-seat pattern; keeps
     HEROBODY / anchors / scale-locks exactly as the accepted strip)
  5. write the strip to every --out; write the horizontally flipped strip to
     every --mirror-out (W-family = mirror of E, the quadrant scheme)

Old strips are backed up into --backup-dir before overwrite. After install:
run --import, then tools/art/verify_art.py <base>.

Usage:
  python tools/art/install_row_strip.py --row <master.png> --old <strip.png> \
      --frames 8 --out <a.png> [--out <b.png>] [--mirror-out <c.png>] \
      [--backup-dir <dir>]
"""
from __future__ import annotations

import argparse
import shutil
from pathlib import Path

import numpy as np
from PIL import Image

A_SOLID = 8


def key_green(arr: np.ndarray) -> np.ndarray:
    """Flat #00ff00-family background -> alpha 0, then despill the rim."""
    r = arr[..., 0].astype(np.int32)
    g = arr[..., 1].astype(np.int32)
    b = arr[..., 2].astype(np.int32)
    bg = (g >= 160) & (r <= 130) & (b <= 130) & (g > r + 60) & (g > b + 60)
    out = arr.copy()
    out[..., 3] = np.where(bg, 0, out[..., 3])
    # despill: green-dominant pixels within 2px of transparency get G clamped
    alpha = out[..., 3] > A_SOLID
    edge = alpha & ~_erode(alpha, 2)
    spill = edge & (g > np.maximum(r, b) + 20)
    out[..., 1] = np.where(spill, np.maximum(r, b).astype(arr.dtype), out[..., 1])
    return out


def _erode(mask: np.ndarray, iterations: int) -> np.ndarray:
    out = mask
    for _ in range(iterations):
        p = np.pad(out, 1, constant_values=False)
        out = p[1:-1, 1:-1] & p[:-2, 1:-1] & p[2:, 1:-1] & p[1:-1, :-2] & p[1:-1, 2:]
    return out


def tone_match(new: np.ndarray, old: np.ndarray) -> np.ndarray:
    """Per-channel mean/std match of new solid content to old solid content."""
    ns = new[..., 3] > 128
    os_ = old[..., 3] > 128
    if ns.sum() < 100 or os_.sum() < 100:
        return new
    out = new.astype(np.float64)
    for c in range(3):
        nv = out[..., c][ns]
        ov = old[..., c][os_].astype(np.float64)
        n_std = max(nv.std(), 1e-6)
        out[..., c][ns] = (nv - nv.mean()) * (ov.std() / n_std) + ov.mean()
    return np.clip(out, 0, 255).astype(np.uint8)


def _metrics(frame: np.ndarray) -> dict | None:
    a = frame[..., 3]
    ys, xs = np.where(a > A_SOLID)
    if not len(ys):
        return None
    return {
        "x0": int(xs.min()), "x1": int(xs.max()),
        "y0": int(ys.min()), "y1": int(ys.max()),
        "cx": float(xs.mean()),
        "bh": int(ys.max() - ys.min() + 1),
        "bw": int(xs.max() - xs.min() + 1),
    }


def seat(new_frame: np.ndarray, old_m: dict, cell: int) -> np.ndarray:
    """Scale new content to the old frame's bbox height, feet on the old
    baseline, centroid-x on the old centroid."""
    m = _metrics(new_frame)
    canvas = np.zeros((cell, cell, 4), dtype=np.uint8)
    if m is None:
        return canvas
    crop = new_frame[m["y0"]:m["y1"] + 1, m["x0"]:m["x1"] + 1]
    scale = old_m["bh"] / m["bh"]
    tw = max(1, round(m["bw"] * scale))
    th = max(1, round(m["bh"] * scale))
    if tw > cell:  # never wider than the cell
        s2 = cell / m["bw"]
        tw, th = cell, max(1, round(m["bh"] * s2))
    img = Image.fromarray(crop).resize((tw, th), Image.LANCZOS)
    scaled = np.asarray(img)
    sm = _metrics(scaled)
    if sm is None:
        return canvas
    # target: feet on old y1, centroid-x on old cx
    y_off = old_m["y1"] - sm["y1"]
    x_off = round(old_m["cx"] - sm["cx"])
    x0, y0 = x_off, y_off
    sx0, sy0 = max(0, -x0), max(0, -y0)
    dx0, dy0 = max(0, x0), max(0, y0)
    hh = min(scaled.shape[0] - sy0, cell - dy0)
    ww = min(scaled.shape[1] - sx0, cell - dx0)
    if hh > 0 and ww > 0:
        canvas[dy0:dy0 + hh, dx0:dx0 + ww] = scaled[sy0:sy0 + hh, sx0:sx0 + ww]
    return canvas


def despeck(frame: np.ndarray, min_px: int = 40) -> np.ndarray:
    """Clear tiny detached components (keying residue slivers) from one cell.
    The main figure is the largest component; anything else below min_px is
    noise from the chroma key, not content."""
    mask = frame[..., 3] > A_SOLID
    if not mask.any():
        return frame
    h, w = mask.shape
    lab = np.zeros((h, w), dtype=np.int32)
    nxt = 0
    sizes: dict[int, int] = {}
    stack: list[tuple[int, int]] = []
    for sy in range(h):
        for sx in range(w):
            if mask[sy, sx] and lab[sy, sx] == 0:
                nxt += 1
                stack.append((sy, sx))
                lab[sy, sx] = nxt
                n = 0
                while stack:
                    y, x = stack.pop()
                    n += 1
                    for yy, xx in ((y-1, x), (y+1, x), (y, x-1), (y, x+1)):
                        if 0 <= yy < h and 0 <= xx < w and mask[yy, xx] and lab[yy, xx] == 0:
                            lab[yy, xx] = nxt
                            stack.append((yy, xx))
                sizes[nxt] = n
    if len(sizes) <= 1:
        return frame
    keep = max(sizes, key=sizes.get)
    out = frame.copy()
    kill = (lab != 0) & (lab != keep)
    for cid, n in sizes.items():
        if cid != keep and n >= min_px:
            kill &= lab != cid   # a big detached piece is real content -- keep it
    out[kill] = 0
    return out


def _feet_cx(frame: np.ndarray) -> float:
    """Mean x of the content's bottom 10px band (the feet), for planted-feet
    anchoring of re-choreographed clips."""
    m = _metrics(frame)
    if m is None:
        return frame.shape[1] / 2.0
    band = frame[max(m["y0"], m["y1"] - 9):m["y1"] + 1, :, 3]
    ys, xs = np.where(band > A_SOLID)
    return float(xs.mean()) if len(xs) else m["cx"]


def seat_uniform(new_frame: np.ndarray, scale: float, baseline: int,
                 feet_x: float, cell: int) -> np.ndarray:
    """One shared transform for every frame: same scale, feet on one baseline,
    feet-center pinned at one x. Whole-body centroid anchoring would shove the
    body opposite an extending arm (the FEETSLIDE trap), so anchor by the feet."""
    m = _metrics(new_frame)
    canvas = np.zeros((cell, cell, 4), dtype=np.uint8)
    if m is None:
        return canvas
    crop = new_frame[m["y0"]:m["y1"] + 1, m["x0"]:m["x1"] + 1]
    tw = max(1, round(m["bw"] * scale))
    th = max(1, round(m["bh"] * scale))
    scaled = np.asarray(Image.fromarray(crop).resize((tw, th), Image.LANCZOS))
    sm = _metrics(scaled)
    if sm is None:
        return canvas
    y_off = baseline - sm["y1"]
    x_off = round(feet_x - _feet_cx(scaled))
    sx0, sy0 = max(0, -x_off), max(0, -y_off)
    dx0, dy0 = max(0, x_off), max(0, y_off)
    hh = min(scaled.shape[0] - sy0, cell - dy0)
    ww = min(scaled.shape[1] - sx0, cell - dx0)
    if hh > 0 and ww > 0:
        canvas[dy0:dy0 + hh, dx0:dx0 + ww] = scaled[sy0:sy0 + hh, sx0:sx0 + ww]
    return canvas


def solidify(strip: np.ndarray) -> np.ndarray:
    """Installed strips are fully solidified (BLEED gate: semi-alpha == 0 on
    extracted art). Threshold the LANCZOS fringe, then despill the solid
    outline band (green edge pixels that survived the key)."""
    out = strip.copy()
    a = out[..., 3]
    out[..., 3] = np.where(a >= 128, 255, 0).astype(strip.dtype)
    solid = out[..., 3] == 255
    band = solid & ~_erode(solid, 2)
    r = out[..., 0].astype(np.int32)
    g = out[..., 1].astype(np.int32)
    b = out[..., 2].astype(np.int32)
    spill = band & (g > np.maximum(r, b) + 20)
    out[..., 1] = np.where(spill, np.maximum(r, b).astype(strip.dtype), out[..., 1])
    return out


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--row", required=True, help="Codex row master (N figures on green)")
    ap.add_argument("--old", required=True, help="current installed strip (geometry + palette authority)")
    ap.add_argument("--frames", type=int, required=True)
    ap.add_argument("--out", action="append", default=[], help="strip destination (repeatable)")
    ap.add_argument("--mirror-out", action="append", default=[],
                    help="destination for the horizontally flipped strip (repeatable)")
    ap.add_argument("--backup-dir", default=None)
    ap.add_argument("--seat", choices=["perframe", "uniform"], default="perframe",
                    help="perframe: match each frame to the old frame's geometry (faithful "
                         "re-draws of the same motion). uniform: one scale + baseline from "
                         "old frame 1, feet-center anchored (re-choreographed clips whose "
                         "poses no longer correspond to the old frames)")
    args = ap.parse_args()

    row = np.asarray(Image.open(args.row).convert("RGBA"))
    old_im = Image.open(args.old).convert("RGBA")
    ow, oh = old_im.size
    cell = oh
    if ow % cell or ow // cell != args.frames:
        print(f"note: old strip {ow}x{oh} has {ow // cell} frames; installing {args.frames}")
    old = np.asarray(old_im)
    old_frames = [old[:, i * cell:(i + 1) * cell] for i in range(ow // cell)]

    keyed = key_green(row)
    fw = keyed.shape[1] // args.frames
    cells = [keyed[:, i * fw:(i + 1) * fw] for i in range(args.frames)]
    # tone-match once over the whole row against the whole old strip
    toned = tone_match(np.concatenate(cells, axis=1), old)
    cells = [toned[:, i * fw:(i + 1) * fw] for i in range(args.frames)]

    strip = np.zeros((cell, cell * args.frames, 4), dtype=np.uint8)
    om0 = _metrics(old_frames[0])
    m0 = _metrics(cells[0])
    uni_scale = (om0["bh"] / m0["bh"]) if (args.seat == "uniform" and om0 and m0) else 1.0
    uni_feet_x = _feet_cx(old_frames[0]) if om0 else cell / 2.0
    for i, cf in enumerate(cells):
        if args.seat == "uniform":
            if om0 is None:
                print(f"  f{i + 1}: old frame 1 empty, cannot seat")
                continue
            seated = despeck(seat_uniform(cf, uni_scale, om0["y1"], uni_feet_x, cell))
        else:
            om = _metrics(old_frames[min(i, len(old_frames) - 1)])
            if om is None:
                print(f"  f{i + 1}: old frame empty, skipping seat")
                continue
            seated = despeck(seat(cf, om, cell))
        strip[:, i * cell:(i + 1) * cell] = seated
        nm = _metrics(seated)
        if nm and args.seat == "uniform":
            print(f"  f{i + 1}: body {nm['bh']}px, feet y {nm['y1']} (baseline {om0['y1']}), "
                  f"feet-x {_feet_cx(seated):.0f} (target {uni_feet_x:.0f})")
        elif nm:
            print(f"  f{i + 1}: body {nm['bh']}px (old {om['bh']}), feet y {nm['y1']} "
                  f"(old {om['y1']}), cx {nm['cx']:.0f} (old {om['cx']:.0f})")

    strip = solidify(strip)
    # mirror: flip each frame in place, keep frame order (W-family = mirror of E)
    mirror = np.concatenate(
        [strip[:, i * cell:(i + 1) * cell][:, ::-1]
         for i in range(args.frames)], axis=1)

    if args.backup_dir:
        Path(args.backup_dir).mkdir(parents=True, exist_ok=True)
    for dest, data in [(d, strip) for d in args.out] + [(d, mirror) for d in args.mirror_out]:
        dp = Path(dest)
        bak = Path(args.backup_dir) / dp.name if args.backup_dir else None
        if bak and dp.exists() and not bak.exists():  # never clobber the first backup
            shutil.copy(dp, bak)
        Image.fromarray(data).save(dp)
        print(f"wrote {dest}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
