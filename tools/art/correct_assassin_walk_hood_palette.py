"""Match generated Assassin walk hood colors to the accepted first half.

This is deliberately a palette-only repair.  It copies no geometry and cannot
move a pixel: frames 1-3 remain byte-identical, while the low-chroma hood and
scarf pixels in frames 4-6 are rank-matched to the accepted palette sampled
from frames 1-3.  Alpha, silhouettes, weapons, and gait poses are preserved.
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


def _hood_mask(frame: np.ndarray) -> np.ndarray:
    alpha = frame[:, :, 3] > 0
    ys, xs = np.nonzero(alpha)
    if not len(xs):
        raise ValueError("empty frame")
    top = int(ys.min())

    # All normalized Assassin walk frames are 180 px tall in a 277 px cell.
    # This box covers the hood and wrapped scarf while stopping above the belt
    # and legs.  The chroma gate excludes the cyan eye and red leather straps.
    region = np.zeros(alpha.shape, dtype=bool)
    region[top : top + 66, 96:184] = True
    rgb = frame[:, :, :3].astype(np.int16)
    high = rgb.max(axis=2)
    low = rgb.min(axis=2)
    chroma = high - low
    neutral_purple = (
        (high >= 24)
        & (high <= 205)
        & (chroma <= 48)
        & (rgb[:, :, 0] >= rgb[:, :, 1] - 3)
        & (rgb[:, :, 2] >= rgb[:, :, 1] - 3)
    )
    return alpha & region & neutral_purple


def _luma(rgb: np.ndarray) -> np.ndarray:
    return (
        rgb[:, 0].astype(np.float32) * 0.2126
        + rgb[:, 1].astype(np.float32) * 0.7152
        + rgb[:, 2].astype(np.float32) * 0.0722
    )


def _rank_match(target: np.ndarray, mask: np.ndarray, reference: np.ndarray) -> int:
    coords = np.argwhere(mask)
    if not len(coords):
        raise ValueError("hood mask selected no pixels")

    target_rgb = target[mask, :3]
    target_order = np.argsort(_luma(target_rgb), kind="stable")
    reference_order = np.argsort(_luma(reference), kind="stable")
    positions = np.linspace(0, len(reference_order) - 1, len(target_order))
    selected = reference[reference_order[np.rint(positions).astype(np.int64)]]

    # Preserve the target frame's authored spatial shading order while using
    # only colors from the accepted hood/scarf palette.
    mapped = np.empty_like(target_rgb)
    mapped[target_order] = selected
    target[coords[:, 0], coords[:, 1], :3] = mapped
    return len(coords)


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

    reference_parts = [frame[_hood_mask(frame), :3] for frame in frames[:3]]
    reference = np.concatenate(reference_parts, axis=0)
    counts = []
    for frame in frames[3:]:
        counts.append(_rank_match(frame, _hood_mask(frame), reference))

    for index in range(3):
        if not np.array_equal(frames[index], originals[index]):
            raise AssertionError(f"accepted frame {index + 1} changed")
    for index in range(3, 6):
        if not np.array_equal(frames[index][:, :, 3], originals[index][:, :, 3]):
            raise AssertionError(f"frame {index + 1} alpha changed")

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
        f"{args.stem}: recolored hood/scarf pixels f4-f6={counts}; "
        "f1-f3 byte-identical; all alpha unchanged"
    )


if __name__ == "__main__":
    main()
