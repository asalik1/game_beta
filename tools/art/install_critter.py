#!/usr/bin/env python3
"""Turn a painterly Codex critter sheet into a crisp pixel-art animation strip.

Owner chose "painterly, then pixelate": Codex renders a rich N-frame flap sheet,
this cuts it to frames, trims/centres each, downscales + light-posterizes toward
pixel-art, keys the background transparent if needed, and writes a horizontal
N-frame strip as game/assets/sprites/critter_<kind>.png (each frame square, so
the engine reads frames = width/height). Ambience's Critter sets hframes and
cycles them. Live tint is applied in-engine, so DO NOT bake terrain tint.

Usage:
  python tools/art/install_critter.py <kind> <src.png> [--frames 4] [--size 48]
                                      [--colors 20] [--no-mobile]
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
    """Guarantee a real alpha channel; chroma-key a near-uniform bg if opaque."""
    im = im.convert("RGBA")
    a = np.asarray(im).astype(np.int16)
    if (a[..., 3] < 20).mean() > 0.03:
        return im  # already has meaningful transparency
    # Key out the background = the modal corner color (tolerance in RGB).
    h, w, _ = a.shape
    corners = np.concatenate([a[0, :, :3], a[-1, :, :3], a[:, 0, :3], a[:, -1, :3]])
    bg = np.median(corners, axis=0)
    dist = np.sqrt(((a[..., :3] - bg) ** 2).sum(axis=2))
    mask = dist < 42
    a[..., 3] = np.where(mask, 0, 255)
    return Image.fromarray(a.astype("uint8"), "RGBA")


def content_bbox(im: Image.Image):
    a = np.asarray(im)
    ys, xs = np.where(a[..., 3] > 24)
    if len(xs) == 0:
        return (0, 0, im.width, im.height)
    return (int(xs.min()), int(ys.min()), int(xs.max()) + 1, int(ys.max()) + 1)


def union_bbox(frames: list[Image.Image]):
    """The tightest box covering the content of EVERY frame. Cropping all frames
    to this shared box + a uniform scale preserves the body position Codex kept
    fixed per cell — per-frame trimming would jitter the body as wings extend."""
    boxes = [content_bbox(f) for f in frames]
    return (min(b[0] for b in boxes), min(b[1] for b in boxes),
            max(b[2] for b in boxes), max(b[3] for b in boxes))


def finish_frame(fr: Image.Image, box, scale: float, size: int, colors: int,
                 alpha_cut: int = 110) -> Image.Image:
    fr = fr.crop(box)
    fr = fr.resize((max(1, round(fr.width * scale)), max(1, round(fr.height * scale))),
                   Image.LANCZOS)
    canvas = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    canvas.paste(fr, ((size - fr.width) // 2, (size - fr.height) // 2), fr)
    if colors > 0:  # light posterize for the pixel-art feel
        rgb = canvas.convert("RGB").quantize(colors=colors, method=Image.MEDIANCUT
                                             ).convert("RGB")
        out = np.dstack([np.asarray(rgb), np.asarray(canvas)[..., 3]])
        canvas = Image.fromarray(out.astype("uint8"), "RGBA")
    a = np.asarray(canvas).copy()  # harden the alpha edge (no downscale halo)
    a[..., 3] = np.where(a[..., 3] > alpha_cut, 255, 0)  # low cut keeps thin bodies (dragonfly)
    return Image.fromarray(a, "RGBA")


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("kind")
    ap.add_argument("src")
    ap.add_argument("--frames", type=int, default=4)
    ap.add_argument("--size", type=int, default=48)
    ap.add_argument("--colors", type=int, default=20)
    ap.add_argument("--alpha-cut", type=int, default=110,
                    help="alpha threshold to keep a pixel opaque; LOW (~35) keeps "
                         "thin anti-aliased bodies like a dragonfly's abdomen")
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
    box = union_bbox(cells)
    inner = int(args.size * 0.92)  # small margin so wing tips aren't clipped
    scale = min(inner / (box[2] - box[0]), inner / (box[3] - box[1]))
    frames = [finish_frame(c, box, scale, args.size, args.colors, args.alpha_cut) for c in cells]
    strip = Image.new("RGBA", (args.size * n, args.size), (0, 0, 0, 0))
    for i, fr in enumerate(frames):
        strip.paste(fr, (i * args.size, 0), fr)
    print(f"{args.kind}: {n} frames @ {args.size}px -> {strip.size}")
    for root, on in ((DESK, True), (MOBILE, not args.no_mobile)):
        if not on:
            continue
        out = root / f"critter_{args.kind}.png"
        strip.save(out)
        print(f"  wrote {out.relative_to(REPO)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
