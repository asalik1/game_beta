#!/usr/bin/env python
"""Stitch shot-rig FRAME SERIES into review GIFs (gameplay-polish 2026-08-18).

A rig's --gif mode (shot_polish.gd) writes user://shots/<rig>/gif_<beat>/f_%04d.png
at the engine frame rate (30 with --fixed-fps=30). This turns each folder into
one GIF: every `step`-th frame kept (30 -> 15 fps), scaled to `--width`, a
16 ms x step frame delay, an adaptive 256-colour palette per GIF, and writes
<out>/<beat>.gif. Owner-facing review artefacts go to Downloads by default.

  python tools/art/gif_from_frames.py [--src <shots/polish>] [--out <dir>]
                                      [--width 960] [--step 2] [--only beat,beat]
"""
import argparse
import glob
import os
import sys

from PIL import Image

DEFAULT_SRC = os.path.join(os.environ.get("APPDATA", ""), "Godot", "app_userdata", "Crownless", "shots", "polish")
DEFAULT_OUT = os.path.join(os.path.expanduser("~"), "Downloads", "crownless_polish_gifs")


def build(folder: str, out_path: str, width: int, step: int, fps_in: int) -> tuple:
    frames = sorted(glob.glob(os.path.join(folder, "f_*.png")))[::step]
    if not frames:
        return (0, 0)
    ims = []
    for p in frames:
        im = Image.open(p).convert("RGB")
        if im.width != width:
            im = im.resize((width, round(im.height * width / im.width)), Image.LANCZOS)
        ims.append(im)
    # One shared adaptive palette from a strided sample keeps colours stable
    # frame to frame (per-frame palettes flicker on a dark, low-contrast world).
    sample = Image.new("RGB", (ims[0].width, ims[0].height * min(6, len(ims))))
    for i, im in enumerate(ims[:: max(1, len(ims) // 6)][:6]):
        sample.paste(im, (0, i * ims[0].height))
    pal = sample.quantize(colors=256, method=Image.Quantize.MEDIANCUT)
    q = [im.quantize(palette=pal, dither=Image.Dither.FLOYDSTEINBERG) for im in ims]
    delay = int(round(1000.0 * step / fps_in))
    q[0].save(out_path, save_all=True, append_images=q[1:], duration=delay, loop=0, optimize=False)
    return (len(q), os.path.getsize(out_path))


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--src", default=DEFAULT_SRC)
    ap.add_argument("--out", default=DEFAULT_OUT)
    ap.add_argument("--width", type=int, default=960)
    ap.add_argument("--step", type=int, default=2)
    ap.add_argument("--fps", type=int, default=30, help="capture rate of the frame series")
    ap.add_argument("--only", default="", help="comma list of beats (folder names without gif_)")
    a = ap.parse_args()
    os.makedirs(a.out, exist_ok=True)
    only = set(x for x in a.only.split(",") if x)
    made = 0
    for folder in sorted(glob.glob(os.path.join(a.src, "gif_*"))):
        beat = os.path.basename(folder)[4:]
        if only and beat not in only:
            continue
        out_path = os.path.join(a.out, beat + ".gif")
        n, size = build(folder, out_path, a.width, a.step, a.fps)
        if n:
            print("%-24s %3d frames  %5.1f MB  -> %s" % (beat, n, size / 1e6, out_path))
            made += 1
        else:
            print("%-24s (no frames)" % beat)
    print("gifs:", made, "->", a.out)
    return 0 if made else 1


if __name__ == "__main__":
    sys.exit(main())
