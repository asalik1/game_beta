"""Enlarge archived runtime walk frames into an ImageGen motion reference."""

from __future__ import annotations

import argparse
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont


def _font(size: int) -> ImageFont.ImageFont:
    for path in (Path("C:/Windows/Fonts/seguisb.ttf"), Path("C:/Windows/Fonts/arialbd.ttf")):
        if path.exists():
            return ImageFont.truetype(str(path), size)
    return ImageFont.load_default()


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("source", type=Path)
    parser.add_argument("output", type=Path)
    parser.add_argument("--label", default="LEGACY WALK MOTION REFERENCE")
    parser.add_argument(
        "--start-frame",
        type=int,
        default=1,
        help="first 1-based source frame to include",
    )
    parser.add_argument(
        "--end-frame",
        type=int,
        help="last 1-based source frame to include (inclusive)",
    )
    parser.add_argument(
        "--chroma-target",
        action="store_true",
        help="write a label-free #00ff00 ImageGen edit target",
    )
    args = parser.parse_args()

    strip = Image.open(args.source).convert("RGBA")
    cell = strip.height
    if strip.width % cell:
        raise ValueError(f"strip does not tile square cells: {strip.size}")
    frame_count = strip.width // cell
    end_frame = args.end_frame if args.end_frame is not None else frame_count
    if not 1 <= args.start_frame <= end_frame <= frame_count:
        raise ValueError(
            f"invalid frame range {args.start_frame}..{end_frame} for {frame_count} frames"
        )
    frames = [
        strip.crop((i * cell, 0, (i + 1) * cell, cell))
        for i in range(args.start_frame - 1, end_frame)
    ]
    target_h, out_cell = 236, 270
    header = 0 if args.chroma_target else 62
    footer = 18 if args.chroma_target else 26
    background = (0, 255, 0, 255) if args.chroma_target else (245, 242, 233, 255)
    canvas = Image.new("RGBA", (out_cell * len(frames), target_h + header + footer), background)
    draw = ImageDraw.Draw(canvas)
    if not args.chroma_target:
        draw.text((14, 10), args.label, font=_font(22), fill=(23, 25, 31, 255))
    for index, frame in enumerate(frames):
        box = frame.getbbox()
        if box is None:
            raise ValueError(f"empty frame {index + 1}")
        figure = frame.crop(box)
        scale = target_h / figure.height
        figure = figure.resize(
            (max(1, round(figure.width * scale)), target_h),
            Image.Resampling.NEAREST,
        )
        x = index * out_cell + (out_cell - figure.width) // 2
        y = header
        canvas.alpha_composite(figure, (x, y))
        if not args.chroma_target:
            draw.text((index * out_cell + 10, header + 8), f"f{index + 1}", font=_font(17), fill=(255, 221, 102, 255))
            draw.line(
                (index * out_cell + 12, header + target_h, (index + 1) * out_cell - 12, header + target_h),
                fill=(70, 73, 82, 255),
                width=3,
            )
    args.output.parent.mkdir(parents=True, exist_ok=True)
    canvas.convert("RGB").save(args.output)
    print(args.output)


if __name__ == "__main__":
    main()
