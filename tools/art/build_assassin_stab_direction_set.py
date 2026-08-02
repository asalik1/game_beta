"""Assemble approved Assassin Stab motion into an eight-direction candidate.

This is a no-generation, candidate-only step.  East supplies E/NE/SE, its
exact horizontal mirror supplies W/NW/SW, and authored clips supply N/S.
Runtime assets are never modified.
"""

from __future__ import annotations

import argparse
from pathlib import Path
import shutil

from PIL import Image, ImageDraw


FRAMES = 8
SOURCE_CELL = 212
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


def _load(directory: Path) -> list[Image.Image]:
    frames = [
        Image.open(directory / f"frame_{index:03d}.png").convert("RGBA")
        for index in range(FRAMES)
    ]
    if any(frame.size != (SOURCE_CELL, SOURCE_CELL) for frame in frames):
        raise ValueError(f"expected eight {SOURCE_CELL}px frames in {directory}")
    return frames


def _save_gif(path: Path, frames: list[Image.Image], duration: int = 83) -> None:
    frames[0].save(
        path,
        save_all=True,
        append_images=frames[1:],
        duration=duration,
        loop=0,
        disposal=2,
        transparency=0,
    )


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--east", type=Path, required=True)
    parser.add_argument("--south", type=Path, required=True)
    parser.add_argument("--north", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()

    east = _load(args.east)
    clips = {
        "south": _load(args.south),
        "south-east": [frame.copy() for frame in east],
        "east": [frame.copy() for frame in east],
        "north-east": [frame.copy() for frame in east],
        "north": _load(args.north),
        "north-west": [frame.transpose(Image.Transpose.FLIP_LEFT_RIGHT) for frame in east],
        "west": [frame.transpose(Image.Transpose.FLIP_LEFT_RIGHT) for frame in east],
        "south-west": [frame.transpose(Image.Transpose.FLIP_LEFT_RIGHT) for frame in east],
    }

    args.output.mkdir(parents=True, exist_ok=True)
    for direction, frames in clips.items():
        direction_dir = args.output / direction
        direction_dir.mkdir(parents=True, exist_ok=True)
        for index, frame in enumerate(frames):
            frame.save(direction_dir / f"frame_{index:03d}.png")
        strip = Image.new("RGBA", (SOURCE_CELL * FRAMES, SOURCE_CELL), (0, 0, 0, 0))
        for index, frame in enumerate(frames):
            strip.alpha_composite(frame, (index * SOURCE_CELL, 0))
        strip.save(args.output / f"assassin_stab_{direction}_raw_candidate.png")
        _save_gif(args.output / f"assassin_stab_{direction}_raw_12fps.gif", frames)

    # One animation that lets motion/facing drift be checked across all eight
    # directions at once.  The cells are review-scale only; sources stay intact.
    preview_cell = SOURCE_CELL // 2
    grid_frames: list[Image.Image] = []
    for frame_index in range(FRAMES):
        grid = Image.new("RGBA", (preview_cell * 4, (preview_cell + 18) * 2), (24, 25, 29, 255))
        draw = ImageDraw.Draw(grid)
        for index, direction in enumerate(DIRECTIONS):
            x = (index % 4) * preview_cell
            y = (index // 4) * (preview_cell + 18)
            preview = clips[direction][frame_index].resize(
                (preview_cell, preview_cell), Image.Resampling.NEAREST
            )
            grid.alpha_composite(preview, (x, y))
            draw.text((x + 4, y + preview_cell + 2), direction, fill=(230, 230, 235, 255))
        grid_frames.append(grid)
    _save_gif(args.output / "assassin_stab_raw_8dir_12fps.gif", grid_frames)

    # Static audit sheet: every source frame is visible simultaneously.
    thumb = 96
    label = 18
    contact = Image.new("RGBA", (thumb * FRAMES, (thumb + label) * len(DIRECTIONS)), (24, 25, 29, 255))
    draw = ImageDraw.Draw(contact)
    for row, direction in enumerate(DIRECTIONS):
        y = row * (thumb + label)
        draw.text((4, y + 2), direction, fill=(230, 230, 235, 255))
        for column, frame in enumerate(clips[direction]):
            preview = frame.resize((thumb, thumb), Image.Resampling.NEAREST)
            contact.alpha_composite(preview, (column * thumb, y + label))
    contact.save(args.output / "assassin_stab_raw_8dir_contact.png")

    (args.output / "README.txt").write_text(
        "Candidate only; runtime untouched.\n"
        "E/NE/SE: approved corrected east PixelLab clip.\n"
        "W/NW/SW: exact horizontal mirror of east.\n"
        "S: approved authored south PixelLab clip.\n"
        "N: endpoint-pinned rear-facing PixelLab reroll.\n",
        encoding="utf-8",
    )


if __name__ == "__main__":
    main()
