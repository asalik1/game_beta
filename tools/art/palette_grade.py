#!/usr/bin/env python
"""Grade a style-outlier sprite's PALETTE toward a sibling that already sits in
the house palette — colour only, structure untouched.

The world was unified painterly in Aug 2026, but a handful of variant rolls came
back candy-bright and still read as another game's asset next to their family
(the 2026-09-03 QA sweep: tree_green2/4's lime canopies beside tree_green's
olive, grass2/3's bright blades beside grass, toadstool/mushroom2/3 beside
mushroom). A repaint is the thorough fix; this is the cheap one the review asked
for — match the reference's SATURATION and VALUE statistics over the masked
pixels while keeping every hue, edge and pixel in place.

  python tools/art/palette_grade.py tree_green2 --toward tree_green --mask green
  python tools/art/palette_grade.py grass2 grass3 --toward grass --sat 0.7 --val 0.9

  --mask green|warm|all   which pixels to grade (a tree keeps its trunk: grade
                          only the green canopy).
  --sat / --val           explicit multipliers instead of matching the reference.
  --max-shift             cap on how far either may move (default 0.45) — a grade
                          that has to move more than this is really a repaint.

The transform is computed ONCE and applied identically to the static and to
every cell of its `<name>_anim.png`, so a graded prop cannot drift between
frames (the animate-in-place contract). Backs both files up into
art_src/_backups/ (never beside the sprite, where a stray PNG would ship with
the game) and writes atomically.
"""
from __future__ import annotations

import argparse
import shutil
import sys
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
SPR = ROOT / "game" / "assets" / "sprites"


def _backup_path(path: Path, tag: str) -> Path:
    """Backups live in art_src/_backups, never beside the sprite: a stray
    <name>.pre_*.png inside game/assets/sprites ships with the game, rides
    every mobile sync and turns up in asset scans as a phantom sprite."""
    d = ROOT / "art_src" / "_backups"
    d.mkdir(parents=True, exist_ok=True)
    return d / f"{path.stem}.{tag}.png"


def _hsv(rgb: np.ndarray) -> np.ndarray:
    """Vectorised RGB(0-255) -> HSV(0-1)."""
    a = rgb.astype(np.float64) / 255.0
    mx = a.max(axis=-1)
    mn = a.min(axis=-1)
    d = mx - mn
    h = np.zeros_like(mx)
    r, g, b = a[..., 0], a[..., 1], a[..., 2]
    nz = d > 1e-9
    idx = (mx == r) & nz
    h[idx] = ((g - b)[idx] / d[idx]) % 6
    idx = (mx == g) & nz
    h[idx] = ((b - r)[idx] / d[idx]) + 2
    idx = (mx == b) & nz
    h[idx] = ((r - g)[idx] / d[idx]) + 4
    h = h / 6.0
    s = np.where(mx > 1e-9, d / np.maximum(mx, 1e-9), 0.0)
    return np.stack([h, s, mx], axis=-1)


def _rgb(hsv: np.ndarray) -> np.ndarray:
    h, s, v = hsv[..., 0], hsv[..., 1], hsv[..., 2]
    i = np.floor(h * 6.0).astype(int) % 6
    f = h * 6.0 - np.floor(h * 6.0)
    p, q, t = v * (1 - s), v * (1 - f * s), v * (1 - (1 - f) * s)
    out = np.zeros(hsv.shape, dtype=np.float64)
    for k, (rr, gg, bb) in enumerate([(v, t, p), (q, v, p), (p, v, t),
                                      (p, q, v), (t, p, v), (v, p, q)]):
        m = i == k
        out[..., 0][m] = rr[m]
        out[..., 1][m] = gg[m]
        out[..., 2][m] = bb[m]
    return np.clip(out * 255.0, 0, 255).astype(np.uint8)


def mask_for(rgb: np.ndarray, alpha: np.ndarray, kind: str) -> np.ndarray:
    op = alpha > 40
    if kind == "all":
        return op
    r, g, b = (rgb[..., i].astype(int) for i in range(3))
    if kind == "green":
        return op & (g > r) & (g > b)
    if kind == "warm":
        return op & (r >= g) & (g >= b) & (r - b > 25)
    raise SystemExit(f"unknown mask {kind}")


def stats(path: Path, kind: str) -> tuple[float, float]:
    a = np.asarray(Image.open(path).convert("RGBA"))
    m = mask_for(a[..., :3], a[..., 3], kind)
    if m.sum() < 50:
        raise SystemExit(f"{path.name}: mask '{kind}' selects almost nothing")
    hsv = _hsv(a[..., :3])
    return float(hsv[..., 1][m].mean()), float(hsv[..., 2][m].mean())


def grade(path: Path, kind: str, ks: float, kv: float, dry: bool) -> None:
    im = Image.open(path).convert("RGBA")
    a = np.asarray(im).copy()
    m = mask_for(a[..., :3], a[..., 3], kind)
    hsv = _hsv(a[..., :3])
    hsv[..., 1][m] = np.clip(hsv[..., 1][m] * ks, 0.0, 1.0)
    hsv[..., 2][m] = np.clip(hsv[..., 2][m] * kv, 0.0, 1.0)
    a[..., :3] = _rgb(hsv)
    if dry:
        print(f"  DRY {path.name}")
        return
    bak = _backup_path(path, "pre_grade")
    if not bak.exists():
        shutil.copy2(path, bak)
    tmp = path.with_name(f".{path.stem}.grade.tmp.png")
    Image.fromarray(a, "RGBA").save(tmp, optimize=True)
    tmp.replace(path)
    print(f"  wrote {path.name}")


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("names", nargs="+")
    ap.add_argument("--toward", help="sibling sprite whose palette stats to match")
    ap.add_argument("--mask", default="all", choices=["all", "green", "warm"])
    ap.add_argument("--sat", type=float, default=None)
    ap.add_argument("--val", type=float, default=None)
    ap.add_argument("--max-shift", type=float, default=0.45)
    ap.add_argument("--dry", action="store_true")
    args = ap.parse_args()

    for name in args.names:
        p = SPR / f"{name}.png"
        if not p.exists():
            print(f"skip {name}: no sprite")
            continue
        ks, kv = args.sat, args.val
        if ks is None or kv is None:
            if not args.toward:
                raise SystemExit("give --toward, or both --sat and --val")
            rs, rv = stats(SPR / f"{args.toward}.png", args.mask)
            ts, tv = stats(p, args.mask)
            ks = ks if ks is not None else rs / max(ts, 1e-6)
            kv = kv if kv is not None else rv / max(tv, 1e-6)
        lo, hi = 1.0 - args.max_shift, 1.0 + args.max_shift
        ks, kv = float(np.clip(ks, lo, hi)), float(np.clip(kv, lo, hi))
        print(f"{name}: sat x{ks:.3f} val x{kv:.3f} (mask {args.mask})")
        grade(p, args.mask, ks, kv, args.dry)
        # The SAME transform on the anim strip, so no frame can drift from the
        # static (the animate-in-place contract).
        anim = SPR / f"{name}_anim.png"
        if anim.exists():
            grade(anim, args.mask, ks, kv, args.dry)
    return 0


if __name__ == "__main__":
    sys.exit(main())
