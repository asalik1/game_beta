#!/usr/bin/env python
"""Install a Codex DEATH row as `<base>_death.png` at the idle's geometry.

The enemy renderer plays an action strip at the IDLE's scale (its cell >= the idle
cell), so the row is scaled so that FRAME 0's body height equals the idle's frame-0
body height; every frame keeps its own extent (a lying body is wide and low), its
lowest opaque row pinned to the idle's feet line and its x-centroid at the cell
centre. Cell = the idle cell (grown to the next multiple of 32 if a lying frame is
wider than it). Rim despill + tone-match to the idle as install_gait_row does.

    python tools/art/install_death_row.py <base> --row <row.png> [--frames N]
"""
from __future__ import annotations

import argparse
import sys
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
SPR = ROOT / "game" / "assets" / "sprites"
sys.path.insert(0, str(Path(__file__).resolve().parent))
from install_gait_row import slice_row  # noqa: E402


def key_green(rgba: np.ndarray) -> np.ndarray:
    """Flat #00ff00 background -> alpha 0 (same thresholds as the row slicer)."""
    a = rgba.copy()
    r, g, b = a[:, :, 0].astype(int), a[:, :, 1].astype(int), a[:, :, 2].astype(int)
    green = (g > 180) & (r < 110) & (b < 110)
    a[green] = 0
    return a


def despill(rgba: np.ndarray) -> np.ndarray:
    """Neutralise the green antialias rim: within 3px of the alpha edge, G may not
    exceed max(R, B) + 6."""
    from scipy import ndimage
    a = rgba.copy()
    al = a[:, :, 3] > 0
    rim = al & ~ndimage.binary_erosion(al, iterations=3)
    r, g, b = a[:, :, 0].astype(int), a[:, :, 1].astype(int), a[:, :, 2].astype(int)
    m = rim & (g > np.maximum(r, b) + 6)
    a[:, :, 1][m] = (np.maximum(r, b)[m] + 6).clip(0, 255).astype(np.uint8)
    return a


def tone_match(rgba: np.ndarray, ref: np.ndarray, max_gain: float = 1.25) -> np.ndarray:
    """Luma-only match of the opaque body to the reference's mean luminance,
    saturated accents protected (chroma > 40 keeps its value)."""
    def lum(x):
        return 0.299 * x[:, :, 0] + 0.587 * x[:, :, 1] + 0.114 * x[:, :, 2]
    src_al, ref_al = rgba[:, :, 3] > 128, ref[:, :, 3] > 128
    if not src_al.any() or not ref_al.any():
        return rgba
    k = float(np.clip(lum(ref.astype(float))[ref_al].mean() / max(1.0, lum(rgba.astype(float))[src_al].mean()), 1 / max_gain, max_gain))
    if abs(k - 1.0) < 0.04:
        return rgba
    a = rgba.astype(float)
    chroma = a[:, :, :3].max(axis=2) - a[:, :, :3].min(axis=2)
    keep = chroma > 40
    scaled = a[:, :, :3] * k
    a[:, :, :3] = np.where(keep[:, :, None], a[:, :, :3], scaled)
    a[:, :, :3] = a[:, :, :3].clip(0, 255)
    return a.astype(np.uint8)


def body_box(a: np.ndarray):
    al = a[:, :, 3] > 60
    ys, xs = np.nonzero(al)
    return int(ys.min()), int(ys.max()), int(xs.min()), int(xs.max())


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("base")
    ap.add_argument("--row", required=True)
    ap.add_argument("--frames", type=int, default=None)
    ap.add_argument("--no-tone", action="store_true")
    args = ap.parse_args()
    idle = next((SPR / f"{args.base}_{k}.png" for k in ("anim", "anim_codex") if (SPR / f"{args.base}_{k}.png").exists()), None)
    if idle is None:
        raise SystemExit(f"no idle for {args.base}")
    iim = Image.open(idle).convert("RGBA")
    cell = iim.height
    ia = np.array(iim.crop((0, 0, cell, cell)))
    it, ib, _, _ = body_box(ia)
    idle_body, feet_y = ib - it + 1, ib
    row = np.array(Image.open(args.row).convert("RGBA"))
    row = key_green(row)
    cells = slice_row(row, args.frames, True, 4)
    f0t, f0b, _, _ = body_box(cells[0])
    S = idle_body / float(f0b - f0t + 1)
    scaled = []
    for c in cells:
        im = Image.fromarray(c)
        bb = im.getchannel("A").getbbox()
        im = im.crop(bb)
        im = im.resize((max(1, int(round(im.width * S))), max(1, int(round(im.height * S)))), Image.LANCZOS)
        scaled.append(despill(np.array(im)))
    need = max(s.shape[1] for s in scaled) + 8
    out_cell = cell
    while out_cell < need:
        out_cell += 32
    out = Image.new("RGBA", (out_cell * len(scaled), out_cell), (0, 0, 0, 0))
    feet = feet_y + (out_cell - cell)  # keep the idle's bottom margin
    for f, s in enumerate(scaled):
        im = Image.fromarray(s)
        al = s[:, :, 3] > 60
        cols = al.sum(axis=0)
        cx = (np.arange(s.shape[1]) * cols).sum() / max(1, cols.sum())
        px = int(round(f * out_cell + out_cell / 2 - cx))
        py = feet - (s.shape[0] - 1)
        out.alpha_composite(im, (max(f * out_cell, px), max(0, py)))
        print(f"  f{f}: {s.shape[1]}x{s.shape[0]} px, feet {feet}")
    arr = np.array(out)
    if not args.no_tone:
        arr = tone_match(arr, np.array(iim))
    dest = SPR / f"{args.base}_death.png"
    tmp = dest.with_suffix(".tmp")
    Image.fromarray(arr).save(tmp, "PNG")
    tmp.replace(dest)
    print(f"wrote {dest.name} ({out.width}x{out.height}, {len(scaled)} frames, scale {S:.3f}, cell {out_cell})")
    return 0


if __name__ == "__main__":
    sys.exit(main())
