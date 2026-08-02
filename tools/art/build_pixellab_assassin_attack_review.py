#!/usr/bin/env python3
"""Build candidate-only QA sheets for canonical PixelLab Assassin attacks."""

from __future__ import annotations

import argparse
from pathlib import Path

from PIL import Image, ImageDraw

from build_preservation_walk_candidate import _font, _shown


ROOT = Path(__file__).resolve().parents[2]
DEFAULT_EXPORT = (
    ROOT
    / "art_src/class_preservation_upscale_2026-08-01/assassin"
    / "attacks_pixellab_2026-08-02/canonical_export/extracted/Assassin_v2/animations"
)
DIRECTIONS = ("south", "south-east", "east", "north-east", "north")
SHORT = {
    "south": "S",
    "south-east": "SE",
    "east": "E",
    "north-east": "NE",
    "north": "N",
}
DEFAULT_FRAMES = 7


def _load(export: Path, clip: str, direction: str, frame_count: int) -> list[Image.Image]:
    folder = export / clip / direction
    paths = sorted(folder.glob("frame_*.png"))
    if len(paths) != frame_count:
        raise ValueError(f"{folder}: expected {frame_count} frames, got {len(paths)}")
    return [Image.open(path).convert("RGBA") for path in paths]


def _write_clip(export: Path, output: Path, clip: str, frame_count: int) -> None:
    cell, header = 170, 30
    contact = Image.new(
        "RGBA", (cell * frame_count, (cell + header) * len(DIRECTIONS)), (25, 28, 34, 255)
    )
    draw = ImageDraw.Draw(contact)
    rows: dict[str, list[Image.Image]] = {}
    for row, direction in enumerate(DIRECTIONS):
        frames = _load(export, clip, direction, frame_count)
        rows[direction] = frames
        y = row * (cell + header)
        draw.text((8, y + 5), f"{clip.upper()} {SHORT[direction]}", font=_font(15), fill=(255, 224, 126, 255))
        for column, frame in enumerate(frames):
            contact.alpha_composite(_shown(frame, 145, cell), (column * cell, y + header))
            draw.text((column * cell + 5, y + header + 4), f"f{column + 1}", font=_font(12), fill=(255, 224, 126, 255))
    safe_clip = clip.lower().replace(" ", "_")[:48]
    contact.save(output / f"assassin_{safe_clip}_raw_5dir_contact.png")

    # One page per animation phase, showing all five authored facings together.
    pages: list[Image.Image] = []
    for frame_index in range(frame_count):
        page = Image.new("RGBA", (cell * len(DIRECTIONS), cell + header), (25, 28, 34, 255))
        page_draw = ImageDraw.Draw(page)
        for column, direction in enumerate(DIRECTIONS):
            page_draw.text((column * cell + 7, 5), SHORT[direction], font=_font(15), fill=(255, 224, 126, 255))
            page.alpha_composite(_shown(rows[direction][frame_index], 145, cell), (column * cell, header))
        pages.append(page.convert("P", palette=Image.Palette.ADAPTIVE))
    pages[0].save(
        output / f"assassin_{safe_clip}_raw_5dir_10fps.gif",
        save_all=True,
        append_images=pages[1:],
        duration=100,
        loop=0,
        disposal=2,
    )


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--export", type=Path, default=DEFAULT_EXPORT)
    parser.add_argument("--output", type=Path)
    parser.add_argument("--clips", default="attack,attack2")
    parser.add_argument("--frames", type=int, default=DEFAULT_FRAMES)
    args = parser.parse_args()
    output = args.output or args.export.parents[2] / "raw_review"
    output.mkdir(parents=True, exist_ok=True)
    for clip in (value for value in args.clips.split(",") if value):
        _write_clip(args.export, output, clip, args.frames)
    print(f"wrote canonical raw attack QA to {output}")


if __name__ == "__main__":
    main()
