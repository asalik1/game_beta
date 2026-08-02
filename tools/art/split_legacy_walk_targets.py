"""Create one large chroma edit target per archived runtime walk frame."""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

from PIL import Image


TOOLS = Path(__file__).resolve().parent
if str(TOOLS) not in sys.path:
    sys.path.insert(0, str(TOOLS))

from build_ledgerbound_warlock import _hard_alpha, _remove_green  # noqa: E402


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("source", type=Path)
    parser.add_argument("output_dir", type=Path)
    parser.add_argument("--prefix", required=True)
    parser.add_argument(
        "--key-green",
        action="store_true",
        help="remove a generated chroma-green background before isolating each figure",
    )
    args = parser.parse_args()

    strip = Image.open(args.source).convert("RGBA")
    cell = strip.height
    if strip.width % cell:
        raise ValueError(f"strip does not tile square cells: {strip.size}")
    args.output_dir.mkdir(parents=True, exist_ok=True)
    for index in range(strip.width // cell):
        frame = strip.crop((index * cell, 0, (index + 1) * cell, cell))
        if args.key_green:
            frame = _hard_alpha(_remove_green(frame))
        box = frame.getbbox()
        if box is None:
            raise ValueError(f"empty frame {index + 1}")
        figure = frame.crop(box)
        target_h = 390
        scale = target_h / figure.height
        figure = figure.resize(
            (max(1, round(figure.width * scale)), target_h),
            Image.Resampling.NEAREST,
        )
        canvas = Image.new("RGBA", (512, 512), (0, 255, 0, 255))
        canvas.alpha_composite(figure, ((512 - figure.width) // 2, 472 - figure.height))
        path = args.output_dir / f"{args.prefix}_f{index + 1}.png"
        canvas.convert("RGB").save(path)
        print(path)


if __name__ == "__main__":
    main()
