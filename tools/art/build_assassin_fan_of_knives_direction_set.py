"""Assemble the reviewed high-resolution Assassin Fan of Knives direction set.

South, East, and North are approved high-resolution PixelLab candidates.
The symmetric side-facing action reuses East for NE/SE and mirrors it
losslessly for W/NW/SW, matching the established Assassin direction policy.
Candidate-only: runtime assets are never modified.
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path

from PIL import Image, ImageDraw

from build_preservation_walk_candidate import _write_qa


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


def _load(path: Path) -> list[Image.Image]:
    strip = Image.open(path).convert("RGBA")
    expected = (CELL * FRAMES, CELL)
    if strip.size != expected:
        raise ValueError(f"expected {expected} strip: {path}")
    return [
        strip.crop((index * CELL, 0, (index + 1) * CELL, CELL))
        for index in range(FRAMES)
    ]


def _mirror(frames: list[Image.Image]) -> list[Image.Image]:
    result = [frame.transpose(Image.Transpose.FLIP_LEFT_RIGHT) for frame in frames]
    for index, (source, mirrored) in enumerate(zip(frames, result, strict=True)):
        if mirrored.transpose(Image.Transpose.FLIP_LEFT_RIGHT).tobytes() != source.tobytes():
            raise ValueError(f"non-lossless mirror at frame {index + 1}")
    return result


def _gif(path: Path, frames: list[Image.Image], duration: int = 83) -> None:
    pages = [frame.convert("P", palette=Image.Palette.ADAPTIVE) for frame in frames]
    pages[0].save(
        path,
        save_all=True,
        append_images=pages[1:],
        duration=duration,
        loop=0,
        disposal=2,
    )


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--south", type=Path, required=True)
    parser.add_argument("--east", type=Path, required=True)
    parser.add_argument("--north", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()

    south = _load(args.south)
    east = _load(args.east)
    north = _load(args.north)
    west = _mirror(east)
    clips = {
        "south": south,
        "south-east": [frame.copy() for frame in east],
        "east": [frame.copy() for frame in east],
        "north-east": [frame.copy() for frame in east],
        "north": north,
        "north-west": [frame.copy() for frame in west],
        "west": [frame.copy() for frame in west],
        "south-west": [frame.copy() for frame in west],
    }

    args.output.mkdir(parents=True, exist_ok=True)
    for direction, frames in clips.items():
        direction_dir = args.output / direction
        direction_dir.mkdir(parents=True, exist_ok=True)
        for index, frame in enumerate(frames):
            frame.save(direction_dir / f"frame_{index:03d}.png")
        stem = f"assassin_fan_of_knives_{direction}"
        strip = Image.new("RGBA", (CELL * FRAMES, CELL), (0, 0, 0, 0))
        for index, frame in enumerate(frames):
            strip.alpha_composite(frame, (index * CELL, 0))
        strip.save(args.output / f"{stem}_candidate.png")
        _write_qa(
            args.output,
            stem,
            f"Assassin Fan of Knives {direction.title()}",
            frames,
            fps=12.0,
            opposite_contact=5,
        )

    preview = 100
    label = 18
    contact = Image.new(
        "RGBA",
        (preview * FRAMES, (preview + label) * len(DIRECTIONS)),
        (24, 25, 29, 255),
    )
    draw = ImageDraw.Draw(contact)
    for row, direction in enumerate(DIRECTIONS):
        y = row * (preview + label)
        draw.text((4, y + 2), direction, fill=(230, 230, 235, 255))
        for column, frame in enumerate(clips[direction]):
            shown = frame.resize((preview, preview), Image.Resampling.NEAREST)
            contact.alpha_composite(shown, (column * preview, y + label))
    contact.save(args.output / "assassin_fan_of_knives_8dir_contact.png")

    grid_frames: list[Image.Image] = []
    grid_cell = 120
    for frame_index in range(FRAMES):
        grid = Image.new("RGBA", (grid_cell * 4, (grid_cell + 18) * 2), (24, 25, 29, 255))
        grid_draw = ImageDraw.Draw(grid)
        for index, direction in enumerate(DIRECTIONS):
            x = (index % 4) * grid_cell
            y = (index // 4) * (grid_cell + 18)
            shown = clips[direction][frame_index].resize(
                (grid_cell, grid_cell), Image.Resampling.NEAREST
            )
            grid.alpha_composite(shown, (x, y))
            grid_draw.text((x + 4, y + grid_cell + 2), direction, fill=(230, 230, 235, 255))
        grid_frames.append(grid)
    _gif(args.output / "assassin_fan_of_knives_8dir_12fps.gif", grid_frames)

    (args.output / "manifest.json").write_text(
        json.dumps(
            {
                "south": str(args.south),
                "east": str(args.east),
                "north": str(args.north),
                "mapping": {
                    "south": "unique south",
                    "south-east": "east copy",
                    "east": "unique east",
                    "north-east": "east copy",
                    "north": "unique north",
                    "north-west": "lossless east mirror",
                    "west": "lossless east mirror",
                    "south-west": "lossless east mirror",
                },
                "cell": CELL,
                "frames": FRAMES,
                "candidate_only": True,
            },
            indent=2,
        ),
        encoding="utf-8",
    )
    print("assembled Assassin Fan of Knives eight-direction candidate")


if __name__ == "__main__":
    main()
