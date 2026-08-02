"""Transplant accepted Assassin hood pixels into the opposite gait half.

Frames 4-6 receive the exact hood/face/scarf raster from frames 1-3.  Patches
are aligned by the cyan eye so that only the generated head treatment is
replaced; the authored lower-body gait and daggers remain untouched.
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

import numpy as np
from PIL import Image


TOOLS = Path(__file__).resolve().parent
if str(TOOLS) not in sys.path:
    sys.path.insert(0, str(TOOLS))

from build_preservation_walk_candidate import _write_qa  # noqa: E402


CELL = 277


def _eye(frame: np.ndarray) -> tuple[int, int]:
    rgb = frame[:, :, :3].astype(np.int16)
    alpha = frame[:, :, 3] > 0
    cyan = (
        alpha
        & (rgb[:, :, 2] > 90)
        & (rgb[:, :, 1] > 55)
        & (rgb[:, :, 2] > rgb[:, :, 0] * 1.8)
        & (rgb[:, :, 1] > rgb[:, :, 0] * 1.5)
    )
    ys, xs = np.nonzero(cyan)
    if not len(xs):
        raise ValueError("could not locate cyan eye")
    return round(float(xs.mean())), round(float(ys.mean()))


def _transplant(source: np.ndarray, target: np.ndarray) -> tuple[np.ndarray, tuple[int, int]]:
    sx, sy = _eye(source)
    tx, ty = _eye(target)
    dx, dy = tx - sx, ty - sy

    # The accepted hood/face/scarf occupies this compact window around the
    # eye.  Its bottom edge ends above the arms, hands, daggers, belt, and legs.
    left, right = sx - 61, sx + 25
    top, bottom = sy - 32, sy + 43
    dleft, dright = left + dx, right + dx
    dtop, dbottom = top + dy, bottom + dy
    if min(left, top, dleft, dtop) < 0 or max(right, dright) > CELL or max(bottom, dbottom) > CELL:
        raise ValueError("hood transplant window exceeds frame")

    result = target.copy()
    result[dtop:dbottom, dleft:dright] = source[top:bottom, left:right]
    return result, (dx, dy)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("source", type=Path)
    parser.add_argument("output_dir", type=Path)
    parser.add_argument("--stem", required=True)
    parser.add_argument("--label", required=True)
    parser.add_argument("--fps", type=float, default=9.0)
    args = parser.parse_args()

    image = Image.open(args.source).convert("RGBA")
    if image.size != (CELL * 6, CELL):
        raise ValueError(f"expected six 277 px cells, got {image.size}")
    frames = [
        np.array(image.crop((i * CELL, 0, (i + 1) * CELL, CELL)), copy=True)
        for i in range(6)
    ]
    originals = [frame.copy() for frame in frames]

    offsets: list[tuple[int, int]] = []
    for accepted, generated in zip(range(3), range(3, 6), strict=True):
        frames[generated], offset = _transplant(frames[accepted], frames[generated])
        offsets.append(offset)

    for index in range(3):
        if not np.array_equal(frames[index], originals[index]):
            raise AssertionError(f"accepted frame {index + 1} changed")

    args.output_dir.mkdir(parents=True, exist_ok=True)
    strip = Image.new("RGBA", image.size, (0, 0, 0, 0))
    rendered: list[Image.Image] = []
    for index, frame in enumerate(frames):
        rendered_frame = Image.fromarray(frame, "RGBA")
        rendered.append(rendered_frame)
        strip.alpha_composite(rendered_frame, (index * CELL, 0))
    strip.save(args.output_dir / f"{args.stem}_candidate.png")
    _write_qa(
        args.output_dir,
        args.stem,
        args.label,
        rendered,
        args.fps,
        opposite_contact=4,
    )
    print(
        f"{args.stem}: exact hood transplants f1->f4, f2->f5, f3->f6; "
        f"eye-alignment offsets={offsets}; lower gait untouched"
    )


if __name__ == "__main__":
    main()
