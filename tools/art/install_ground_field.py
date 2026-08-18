#!/usr/bin/env python3
"""Install an authored seamless FLOOR-FIELD tile as ground_field_<kind>.png
(or, with --prefix wall_field_, a WALL-FIELD tile as wall_field_<kind>.png —
the seamless square wall tile game_world._wall draws at 1 texel = 1 world px).

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

# Per-kind stored tile edge = FEATURE SCALE (2026-08-18 gameplay-polish pass).
# The tile renders 1 texel = 1 world px, so its edge sets how big a cobble is
# next to the 88px hero (HERO_TARGET_BODY 52 * CHAR_RENDER_SCALE 1.7). At 512
# the ImageGen masters put one cobble/plate at 80-120px — the hero stood ONE
# stone tall and read as a figurine on a macro photo. Cobble/plate floors go
# to 256 (stone ~40-55px, a third to a half of the hero), crystals/flagstones a
# touch larger, forest leaf-litter 400 (leaves were a quarter of the hero).
# Fine-grain kinds (grass, dirt, sand, snow, spore, marsh, bog, storm) stay 512.
# --size on the command line still overrides.
SIZE_BY_KIND = {
    "stone": 256, "basalt": 256, "voidstone": 256,
    "crystalfloor": 288, "holystone": 320, "forest": 400,
    # wall fields (--prefix wall_field_): a 48px-tall wall wants small courses.
    "wallblock": 128, "wall_castle": 128, "wall_grave": 128, "wall_hedge": 128,
    "wall_ice": 128, "wall_moss": 128, "wall_sand": 128, "wall_sewer": 128,
    "wall_volcanic": 128, "wall_wood": 128,
}


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
    ap.add_argument("--size", type=int, default=None,
                    help="stored tile edge in px (on-screen tile period = feature scale); "
                         "default SIZE_BY_KIND[kind] else 512")
    ap.add_argument("--gamma", type=float, default=0.82,
                    help="pre-brighten exponent (<1 brightens) to counter the Forward+ "
                         "tonemap + terrain tint sink; default 0.82. Use ~0.95 for the "
                         "intentionally-dark void.")
    ap.add_argument("--no-mobile", action="store_true")
    ap.add_argument("--prefix", default="ground_field_",
                    help="output name prefix: ground_field_ (floors) or wall_field_ (walls, "
                         "the seamless square tile game_world._wall draws at 1:1)")
    args = ap.parse_args()
    if args.size is None:
        args.size = SIZE_BY_KIND.get(args.kind, 512)

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
        out = root / f"{args.prefix}{args.kind}.png"
        out.parent.mkdir(parents=True, exist_ok=True)
        im.save(out)
        print(f"  wrote {out.relative_to(REPO)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
