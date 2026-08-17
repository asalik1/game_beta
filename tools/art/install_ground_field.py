#!/usr/bin/env python3
"""Install an authored seamless FLOOR-FIELD tile as ground_field_<kind>.png.

These are the native-resolution crisp floor textures that game_world GPU-tiles
across a room (Art.ground_field / _apply_ground_field). Source tiles come from
Codex ImageGen (large, ~1254px, seamless). This downscales to a game-density
tile, verifies the seam wraps, and writes BOTH the desktop and mobile copies so
the two trees stay in sync. Run `--import` afterward so Godot sees the new PNG.

Usage:
  python tools/art/install_ground_field.py <kind> <src.png> [--size 512] [--no-mobile]

The tile is left crisp (LANCZOS) — the game renders it NEAREST-filtered at 1:1,
so it reads at prop pixel density. Tint is applied live by the CanvasModulate,
so DO NOT bake the terrain tint here.
"""
import argparse
import sys
from pathlib import Path

from PIL import Image

REPO = Path(__file__).resolve().parents[2]
DESK = REPO / "game" / "assets" / "sprites"
MOBILE = REPO / "mobile" / "game" / "assets" / "sprites"


def seam_diff(im: Image.Image) -> tuple[float, float]:
    import numpy as np
    a = np.asarray(im.convert("RGB")).astype(int)
    lr = float(abs(a[:, 0] - a[:, -1]).mean())
    tb = float(abs(a[0] - a[-1]).mean())
    return lr, tb


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("kind")
    ap.add_argument("src")
    ap.add_argument("--size", type=int, default=512,
                    help="stored tile edge in px (on-screen tile period); default 512")
    ap.add_argument("--gamma", type=float, default=0.82,
                    help="pre-brighten exponent (<1 brightens) to counter the Forward+ "
                         "tonemap + terrain tint sink; default 0.82. Use ~0.95 for the "
                         "intentionally-dark void.")
    ap.add_argument("--no-mobile", action="store_true")
    args = ap.parse_args()

    src = Path(args.src)
    if not src.exists():
        print(f"ERR: source not found: {src}", file=sys.stderr)
        return 2
    im = Image.open(src).convert("RGBA")
    # Square-crop centered if the generator returned a non-square frame.
    if im.width != im.height:
        s = min(im.width, im.height)
        left = (im.width - s) // 2
        top = (im.height - s) // 2
        im = im.crop((left, top, left + s, top + s))
    im = im.resize((args.size, args.size), Image.LANCZOS)

    if abs(args.gamma - 1.0) > 1e-3:
        import numpy as np
        arr = np.asarray(im).astype(np.float32) / 255.0
        arr[..., :3] = np.power(arr[..., :3], args.gamma)  # <1 brightens; leave alpha
        im = Image.fromarray((np.clip(arr, 0, 1) * 255).round().astype("uint8"), "RGBA")

    lr, tb = seam_diff(im)
    flag = "" if (lr < 12 and tb < 12) else "  <-- SEAM RISK (>12)"
    print(f"{args.kind}: {args.size}x{args.size}  seam L/R={lr:.1f} T/B={tb:.1f}{flag}")

    for root, on in ((DESK, True), (MOBILE, not args.no_mobile)):
        if not on:
            continue
        out = root / f"ground_field_{args.kind}.png"
        out.parent.mkdir(parents=True, exist_ok=True)
        im.save(out)
        print(f"  wrote {out.relative_to(REPO)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
