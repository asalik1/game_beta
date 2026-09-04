#!/usr/bin/env python
"""RE-SEAT an installed locomotion strip onto its idle's geometry — no regen.

The enemy renderer normalises a LOCOMOTION strip by its OWN cell (enemy.gd
_apply_strip: `ref = cell` unless the sprite is in MOB_BODY_SCALE_WALK), so a
walk authored on a different canvas than the idle, or with the body drawn
smaller / off-centre in its cell, renders at the wrong size or lurches
sideways the moment the creature moves. The 2026-09-03 boss audit measured
the class: nullwarden's walks at body/cell 0.52 against an idle at 0.84 (a
boss walking at ~60 % size, centred at 0.2 of the cell), saint_varo_standing's
E/W on an 812 px cell beside 627 px siblings, sexton/serane walk facings
0.13 of a cell off centre, morwen 7 % small. All are geometry, all fixable
in place:

  1. scale every frame by ONE factor so the strip's median body height /
     cell equals the reference's (--match <ref strip>, usually the idle) —
     or --scale F explicitly;
  2. recentre every frame's body horizontally on the cell centre (bbox
     centre by default, --anchor torso for a figure whose limbs reach);
  3. pin every frame's feet to the reference's feet fraction of the cell
     (so idle<->walk never pops vertically);
  4. optional --tone <ref>: luma/chroma tone-match to the reference (the
     brightness-shift drift class — vess's walk facings read 24-50 % brighter
     than her idle, vargoth's north cape 45 %).

    python tools/art/reseat_strip.py nullwarden_walk_codex_s --match nullwarden_anim_codex
    python tools/art/reseat_strip.py vess_walk_codex_e --tone vess_anim_codex --no-geometry
    python tools/art/reseat_strip.py morwen_walk --scale 1.074

Backs up into art_src/_backups and writes atomically. The output keeps the
strip's own cell size (frame count and cell are what the engine reads).
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
sys.path.insert(0, str(Path(__file__).resolve().parent))
from install_gait_walk import tone_match  # noqa: E402

A = 40


def _cells(im: Image.Image) -> list[np.ndarray]:
    c = im.height
    a = np.asarray(im.convert("RGBA"))
    return [a[:, f * c:(f + 1) * c].copy() for f in range(max(1, im.width // c))]


def _bbox(alpha: np.ndarray):
    ys, xs = np.nonzero(alpha > A)
    if not len(ys):
        return None
    return int(xs.min()), int(ys.min()), int(xs.max()), int(ys.max())


def geometry(path: Path) -> tuple[int, float, float]:
    """(cell, median body/cell, frame-0 feet/cell) of a strip."""
    im = Image.open(path)
    cells = _cells(im)
    c = im.height
    bodies, feet = [], None
    for cell in cells:
        bb = _bbox(cell[:, :, 3])
        if bb is None:
            continue
        bodies.append((bb[3] - bb[1] + 1) / c)
        if feet is None:
            feet = bb[3] / c
    return c, float(np.median(bodies)), float(feet if feet is not None else 0.95)


def anchor_x(alpha: np.ndarray, mode: str) -> float:
    ys, xs = np.nonzero(alpha > A)
    if mode == "torso":
        top, bot = ys.min(), ys.max()
        band = ys <= top + int((bot - top) * 0.40)
        return float(xs[band].mean())
    return (xs.min() + xs.max()) / 2.0


def reseat(path: Path, scale: float, feet_frac: float | None, anchor: str) -> Image.Image:
    im = Image.open(path).convert("RGBA")
    c = im.height
    out = Image.new("RGBA", im.size, (0, 0, 0, 0))
    for f, cell in enumerate(_cells(im)):
        bb = _bbox(cell[:, :, 3])
        if bb is None:
            continue
        sub = Image.fromarray(cell[bb[1]:bb[3] + 1, bb[0]:bb[2] + 1], "RGBA")
        if abs(scale - 1.0) > 1e-3:
            sub = sub.resize((max(1, int(round(sub.width * scale))),
                              max(1, int(round(sub.height * scale)))), Image.LANCZOS)
        sa = np.asarray(sub)[:, :, 3]
        ax = anchor_x(sa, anchor)
        px = int(round(c / 2.0 - ax))
        feet_row = (feet_frac * c) if feet_frac is not None else (bb[3] * scale)
        py = int(round(feet_row - (sub.height - 1)))
        # paste with clipping
        x0, y0 = f * c + px, py
        sx0, sy0 = max(0, -px), max(0, -py)
        ex, ey = min(sub.width, c - px), min(sub.height, c - py)
        if ex > sx0 and ey > sy0:
            crop = sub.crop((sx0, sy0, ex, ey))
            out.paste(crop, (x0 + sx0, y0 + sy0), crop)
    return out


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("name", help="strip base name under game/assets/sprites (no .png)")
    ap.add_argument("--match", help="reference strip whose body/cell + feet/cell to match")
    ap.add_argument("--scale", type=float, default=None, help="explicit scale instead of --match")
    ap.add_argument("--tone", help="reference strip to tone-match to")
    ap.add_argument("--anchor", choices=["bbox", "torso"], default="bbox")
    ap.add_argument("--no-geometry", action="store_true", help="tone only")
    ap.add_argument("--out", help="write here instead of in place")
    ap.add_argument("--dry", action="store_true")
    args = ap.parse_args()

    p = SPR / f"{args.name}.png"
    if not p.exists():
        raise SystemExit(f"no strip {p}")
    c, body, feet = geometry(p)
    print(f"{args.name}: cell {c} body/cell {body:.3f} feet/cell {feet:.3f}")
    result: Image.Image | None = None
    if not args.no_geometry:
        scale = args.scale
        feet_frac = None
        if args.match:
            rc, rbody, rfeet = geometry(SPR / f"{args.match}.png")
            scale = scale if scale is not None else rbody / max(body, 1e-6)
            feet_frac = rfeet
            print(f"  match {args.match}: cell {rc} body/cell {rbody:.3f} feet/cell {rfeet:.3f} -> scale x{scale:.3f}")
        if scale is None:
            scale = 1.0
        result = reseat(p, scale, feet_frac, args.anchor)
    if args.tone:
        src = result if result is not None else Image.open(p).convert("RGBA")
        result = tone_match(src, SPR / f"{args.tone}.png")
        print(f"  tone-matched to {args.tone}")
    if result is None:
        print("  nothing to do"); return 0
    nc, nbody, nfeet = None, None, None
    dest = Path(args.out) if args.out else p
    if args.dry:
        print(f"  DRY would write {dest}"); return 0
    bak = ROOT / "art_src" / "_backups" / f"{p.stem}.pre_reseat.png"
    bak.parent.mkdir(parents=True, exist_ok=True)
    if not bak.exists():
        shutil.copy2(p, bak)
    tmp = dest.with_name(f".{dest.stem}.reseat.tmp.png")
    result.save(tmp)
    tmp.replace(dest)
    c2, b2, f2 = geometry(dest)
    print(f"  wrote {dest.name}: body/cell {b2:.3f} feet/cell {f2:.3f}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
