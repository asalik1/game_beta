#!/usr/bin/env python3
"""Install a Codex 4-frame prop sheet as a self-animating <name>_anim.png.

For the PROCEDURAL fire/water/energy props (signal_fire, town_fountain, …) that
have no static PNG to derive from. Cuts the N frames, aligns them to a SHARED
bbox + uniform scale (so the rigid base doesn't wander while the flame/water
moves), BOTTOM-anchors each into a square cell (props stand on their base), and
lightly posterizes toward pixel-art. Square cells → anim_info() reads N frames.
Live tint is the CanvasModulate's job — do NOT bake terrain tint.

Usage:
  python tools/art/install_prop_anim.py <name> <src.png> [--frames 4]
        [--size 160] [--colors 32] [--no-mobile]
"""
import argparse
import sys
from pathlib import Path

import numpy as np
from PIL import Image

REPO = Path(__file__).resolve().parents[2]
DESK = REPO / "game" / "assets" / "sprites"
MOBILE = REPO / "mobile" / "game" / "assets" / "sprites"


def ensure_alpha(im: Image.Image) -> Image.Image:
    im = im.convert("RGBA")
    a = np.asarray(im).astype(np.int16)
    if (a[..., 3] < 20).mean() > 0.03:
        return im
    corners = np.concatenate([a[0, :, :3], a[-1, :, :3], a[:, 0, :3], a[:, -1, :3]])
    bg = np.median(corners, axis=0)
    dist = np.sqrt(((a[..., :3] - bg) ** 2).sum(axis=2))
    a[..., 3] = np.where(dist < 42, 0, 255)
    return Image.fromarray(a.astype("uint8"), "RGBA")


def bbox(im):
    a = np.asarray(im)
    ys, xs = np.where(a[..., 3] > 24)
    return (0, 0, im.width, im.height) if len(xs) == 0 else \
        (int(xs.min()), int(ys.min()), int(xs.max()) + 1, int(ys.max()) + 1)


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("name")
    ap.add_argument("src")
    ap.add_argument("--frames", type=int, default=4)
    ap.add_argument("--size", type=int, default=160)
    ap.add_argument("--colors", type=int, default=32)
    ap.add_argument("--no-mobile", action="store_true")
    args = ap.parse_args()

    src = Path(args.src)
    if not src.exists():
        print(f"ERR: no source {src}", file=sys.stderr)
        return 2
    sheet = Image.open(src).convert("RGBA")
    n = args.frames
    fw = sheet.width // n
    cells = [ensure_alpha(sheet.crop((i * fw, 0, (i + 1) * fw, sheet.height))) for i in range(n)]
    boxes = [bbox(c) for c in cells]
    box = (min(b[0] for b in boxes), min(b[1] for b in boxes),
           max(b[2] for b in boxes), max(b[3] for b in boxes))
    bw, bh = box[2] - box[0], box[3] - box[1]
    inner = int(args.size * 0.94)
    scale = min(inner / bw, inner / bh)
    fw2, fh2 = max(1, round(bw * scale)), max(1, round(bh * scale))
    s = args.size
    strip = Image.new("RGBA", (s * n, s), (0, 0, 0, 0))
    for i, c in enumerate(cells):
        fr = c.crop(box).resize((fw2, fh2), Image.LANCZOS)
        cell = Image.new("RGBA", (s, s), (0, 0, 0, 0))
        cell.paste(fr, ((s - fw2) // 2, s - fh2 - 2), fr)   # BOTTOM-anchored
        if args.colors > 0:
            rgb = cell.convert("RGB").quantize(colors=args.colors,
                                               method=Image.MEDIANCUT).convert("RGB")
            cell = Image.fromarray(
                np.dstack([np.asarray(rgb), np.asarray(cell)[..., 3]]).astype("uint8"), "RGBA")
        aa = np.asarray(cell).copy()
        aa[..., 3] = np.where(aa[..., 3] > 90, 255, 0)
        strip.paste(Image.fromarray(aa, "RGBA"), (i * s, 0))
    print(f"{args.name}: {n} frames @ {s}px (bottom-anchored)")
    for root, on in ((DESK, True), (MOBILE, not args.no_mobile)):
        if not on:
            continue
        out = root / f"{args.name}_anim.png"
        strip.save(out)
        print(f"  wrote {out.relative_to(REPO)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
