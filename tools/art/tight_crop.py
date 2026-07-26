"""Tight-crop transparent sprite sources without disturbing animation frames.

For each positional static PNG, this tool crops the static image and its
optional ``<stem>_anim.png`` sibling to one shared alpha rectangle.  Animation
strips are rebuilt frame by frame, so every frame keeps identical dimensions
and alignment.  The static image's original dimensions determine the strip's
frame grid.

Use ``--static-only`` for redundant portrait/reference sprites whose animation
strip is already independently normalized.
"""

from __future__ import annotations

import argparse
from pathlib import Path

from PIL import Image


def save_png(image: Image.Image, output: Path) -> None:
    """Atomically replace a PNG so importers never observe a partial strip."""
    temporary = output.with_name(f".{output.stem}.tight-crop.tmp.png")
    image.save(temporary, optimize=True)
    temporary.replace(output)


def _visible_bbox(image: Image.Image, threshold: int) -> tuple[int, int, int, int]:
    alpha = image.convert("RGBA").getchannel("A")
    if threshold > 0:
        alpha = alpha.point(lambda value: 255 if value > threshold else 0)
    bbox = alpha.getbbox()
    if bbox is None:
        raise ValueError("image contains no visible pixels")
    return bbox


def _union(
    left: tuple[int, int, int, int],
    right: tuple[int, int, int, int],
) -> tuple[int, int, int, int]:
    return (
        min(left[0], right[0]),
        min(left[1], right[1]),
        max(left[2], right[2]),
        max(left[3], right[3]),
    )


def _strip_frames(strip: Image.Image, frame_size: tuple[int, int]) -> list[Image.Image]:
    frame_width, frame_height = frame_size
    if strip.height != frame_height or strip.width % frame_width != 0:
        raise ValueError(
            f"strip {strip.width}x{strip.height} is not a horizontal grid of "
            f"{frame_width}x{frame_height} frames"
        )
    return [
        strip.crop((x, 0, x + frame_width, frame_height))
        for x in range(0, strip.width, frame_width)
    ]


def crop_family(
    static_path: Path,
    *,
    threshold: int = 0,
    include_strip: bool = True,
) -> tuple[tuple[int, int], tuple[int, int], tuple[int, int]]:
    """Crop one static sprite and its animation strip; return old/new/origin."""
    static = Image.open(static_path).convert("RGBA")
    old_size = static.size
    strip_path = static_path.with_name(f"{static_path.stem}_anim.png")
    frames: list[Image.Image] = []
    if include_strip and strip_path.exists():
        strip = Image.open(strip_path).convert("RGBA")
        frames = _strip_frames(strip, old_size)

    bbox = _visible_bbox(static, threshold)
    for frame in frames:
        bbox = _union(bbox, _visible_bbox(frame, threshold))

    cropped_static = static.crop(bbox)
    save_png(cropped_static, static_path)
    if frames:
        cropped_frames = [frame.crop(bbox) for frame in frames]
        strip_out = Image.new(
            "RGBA",
            (cropped_static.width * len(cropped_frames), cropped_static.height),
            (0, 0, 0, 0),
        )
        for index, frame in enumerate(cropped_frames):
            strip_out.alpha_composite(frame, (index * cropped_static.width, 0))
        save_png(strip_out, strip_path)

    return old_size, cropped_static.size, (bbox[0], bbox[1])


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("images", nargs="+", type=Path, help="static PNG sources")
    parser.add_argument(
        "--threshold",
        type=int,
        default=0,
        help="discard pixels whose alpha is at or below this 0..255 value",
    )
    parser.add_argument(
        "--static-only",
        action="store_true",
        help="do not crop a matching _anim.png strip",
    )
    args = parser.parse_args()
    if not 0 <= args.threshold <= 254:
        parser.error("--threshold must be between 0 and 254")

    for path in args.images:
        old_size, new_size, origin = crop_family(
            path,
            threshold=args.threshold,
            include_strip=not args.static_only,
        )
        print(
            f"{path}: {old_size[0]}x{old_size[1]} -> "
            f"{new_size[0]}x{new_size[1]} (origin {origin[0]},{origin[1]})"
        )


if __name__ == "__main__":
    main()
