#!/usr/bin/env python3
"""Report complete-frame scale/anchor drift across mob animation strips."""

from __future__ import annotations

import argparse
from pathlib import Path

import numpy as np
from PIL import Image


ROOT = Path(__file__).resolve().parents[2]
SPRITES = ROOT / "game" / "assets" / "sprites"
SUFFIXES = ("", "_anim", "_walk", "_attack",
            "_walk_s", "_walk_se", "_walk_e", "_walk_ne",
            "_walk_n", "_walk_nw", "_walk_w", "_walk_sw")


def alpha_box(frame: Image.Image) -> tuple[int, int, int, int]:
    alpha = np.asarray(frame.getchannel("A")) > 32
    ys, xs = np.where(alpha)
    if not len(xs):
        raise ValueError("empty frame")
    return int(xs.min()), int(ys.min()), int(xs.max()) + 1, int(ys.max()) + 1


def metrics(path: Path) -> tuple[int, int, list[tuple[int, int, int, int]]]:
    with Image.open(path) as opened:
        image = opened.convert("RGBA")
    cell = image.height
    frames = max(1, image.width // cell)
    boxes = [alpha_box(image.crop((index * cell, 0,
                                   min((index + 1) * cell, image.width), cell)))
             for index in range(frames)]
    return cell, frames, boxes


def span(values: list[float]) -> str:
    return f"{min(values):.1f}-{max(values):.1f}"


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("keys", nargs="+")
    args = parser.parse_args()
    for key in args.keys:
        print(f"\n{key}")
        for suffix in SUFFIXES:
            path = SPRITES / f"{key}{suffix}.png"
            if not path.exists():
                continue
            cell, frames, boxes = metrics(path)
            heights = [float(box[3] - box[1]) for box in boxes]
            widths = [float(box[2] - box[0]) for box in boxes]
            centers = [(box[0] + box[2]) / 2 for box in boxes]
            bottoms = [float(box[3]) for box in boxes]
            label = suffix or "_base"
            print(f"{label:8} cell={cell:3} frames={frames:2} "
                  f"height={span(heights):>11} width={span(widths):>11} "
                  f"center={span(centers):>11} bottom={span(bottoms):>11}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
