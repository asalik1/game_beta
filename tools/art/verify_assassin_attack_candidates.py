"""Verify candidate-only Assassin attack direction sets before installation."""

from __future__ import annotations

import argparse
from pathlib import Path

from PIL import Image


CELL = 277
FRAMES = 8
DIRECTIONS = (
    "south",
    "south-east",
    "east",
    "north-east",
    "north",
    "north-west",
    "west",
    "south-west",
)


def _split(strip: Image.Image) -> list[Image.Image]:
    return [
        strip.crop((index * CELL, 0, (index + 1) * CELL, CELL))
        for index in range(FRAMES)
    ]


def _load(path: Path) -> tuple[list[Image.Image], list[int]]:
    strip = Image.open(path).convert("RGBA")
    if strip.size != (CELL * FRAMES, CELL):
        raise ValueError(f"bad strip size {strip.size}: {path}")
    alpha_values = set(strip.getchannel("A").getdata())
    if not alpha_values.issubset({0, 255}):
        raise ValueError(f"semi-transparent pixels in {path}: {sorted(alpha_values)}")
    if any(
        strip.getpixel(point)[3] != 0
        for point in ((0, 0), (strip.width - 1, 0), (0, CELL - 1), (strip.width - 1, CELL - 1))
    ):
        raise ValueError(f"opaque strip corner: {path}")
    frames = _split(strip)
    boxes = [frame.getbbox() for frame in frames]
    if any(box is None for box in boxes):
        raise ValueError(f"empty frame: {path}")
    heights = [box[3] - box[1] for box in boxes if box is not None]
    return frames, heights


def _mirror_equal(left: list[Image.Image], right: list[Image.Image]) -> bool:
    return all(
        a.transpose(Image.Transpose.FLIP_LEFT_RIGHT).tobytes() == b.tobytes()
        for a, b in zip(left, right, strict=True)
    )


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--stab-root", type=Path, required=True)
    parser.add_argument("--fan-root", type=Path, required=True)
    args = parser.parse_args()

    stab: dict[str, list[Image.Image]] = {}
    fan: dict[str, list[Image.Image]] = {}
    for direction in DIRECTIONS:
        stab_path = (
            args.stab_root
            / direction
            / f"assassin_stab_{direction}_pixellab_resize_v01_candidate.png"
        )
        fan_path = args.fan_root / f"assassin_fan_of_knives_{direction}_candidate.png"
        stab[direction], stab_heights = _load(stab_path)
        fan[direction], fan_heights = _load(fan_path)
        print(
            f"{direction:10} stab_height={min(stab_heights)}..{max(stab_heights)} "
            f"fan_height={min(fan_heights)}..{max(fan_heights)}"
        )

    for west, east in (
        ("west", "east"),
        ("north-west", "north-east"),
        ("south-west", "south-east"),
    ):
        if not _mirror_equal(stab[east], stab[west]):
            raise ValueError(f"Stab {west} is not an exact mirror of {east}")

    if not (fan["east"][0].size == (CELL, CELL)):
        raise AssertionError("unreachable fan cell check")
    for copy_direction in ("north-east", "south-east"):
        if any(
            source.tobytes() != copy.tobytes()
            for source, copy in zip(fan["east"], fan[copy_direction], strict=True)
        ):
            raise ValueError(f"Fan {copy_direction} is not an exact East copy")
    for direction in ("west", "north-west", "south-west"):
        if not _mirror_equal(fan["east"], fan[direction]):
            raise ValueError(f"Fan {direction} is not an exact East mirror")

    print("PASS: Assassin Stab and Fan of Knives candidate sets are structurally valid")


if __name__ == "__main__":
    main()
