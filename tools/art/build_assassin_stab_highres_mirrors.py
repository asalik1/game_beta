"""Build candidate-only high-resolution Assassin Stab west-side mirrors.

The approved low-resolution Stab set defines W/NW/SW as exact mirrors of
E/NE/SE.  This helper applies that same lossless per-cell transform after the
PixelLab redraw pass and writes review assets under ``art_src`` only.
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path

from PIL import Image, ImageDraw

from build_preservation_walk_candidate import _write_qa


CELL = 277
FRAMES = 8
MIRRORS = {
    "west": "east",
    "north-west": "north-east",
    "south-west": "south-east",
}
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
    parser.add_argument("root", type=Path)
    args = parser.parse_args()

    for target, source in MIRRORS.items():
        source_dir = args.root / source
        target_dir = args.root / target
        target_dir.mkdir(parents=True, exist_ok=True)
        mirrored: list[Image.Image] = []

        for number in range(1, FRAMES + 1):
            source_path = (
                source_dir / f"assassin_stab_{source}_f{number:02d}_normalized.png"
            )
            frame = Image.open(source_path).convert("RGBA")
            if frame.size != (CELL, CELL):
                raise ValueError(f"expected {CELL}px frame: {source_path}")
            result = frame.transpose(Image.Transpose.FLIP_LEFT_RIGHT)
            if result.transpose(Image.Transpose.FLIP_LEFT_RIGHT).tobytes() != frame.tobytes():
                raise ValueError(f"non-lossless mirror at {source} frame {number}")
            result.save(
                target_dir
                / f"assassin_stab_{target}_f{number:02d}_normalized.png"
            )
            mirrored.append(result)

        stem = f"assassin_stab_{target}_pixellab_resize_v01"
        strip = Image.new("RGBA", (CELL * FRAMES, CELL), (0, 0, 0, 0))
        for index, frame in enumerate(mirrored):
            strip.alpha_composite(frame, (index * CELL, 0))
        strip.save(target_dir / f"{stem}_candidate.png")
        _write_qa(
            target_dir,
            stem,
            f"Assassin Stab {target.title()} - exact {source.title()} mirror",
            mirrored,
            fps=12.0,
            opposite_contact=5,
        )
        (target_dir / "manifest.json").write_text(
            json.dumps(
                {
                    "direction": target,
                    "source_direction": source,
                    "source_dir": str(source_dir),
                    "transform": "lossless per-cell horizontal mirror",
                    "cell": CELL,
                    "frames": FRAMES,
                    "candidate_only": True,
                },
                indent=2,
            ),
            encoding="utf-8",
        )
        print(f"{target}: mirrored {FRAMES} frames from {source}")

    clips = {
        direction: [
            Image.open(
                args.root
                / direction
                / f"assassin_stab_{direction}_f{number:02d}_normalized.png"
            ).convert("RGBA")
            for number in range(1, FRAMES + 1)
        ]
        for direction in DIRECTIONS
    }
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
    contact.save(args.root / "assassin_stab_highres_8dir_contact.png")

    grid_frames: list[Image.Image] = []
    grid_cell = 120
    for frame_index in range(FRAMES):
        grid = Image.new(
            "RGBA", (grid_cell * 4, (grid_cell + 18) * 2), (24, 25, 29, 255)
        )
        grid_draw = ImageDraw.Draw(grid)
        for index, direction in enumerate(DIRECTIONS):
            x = (index % 4) * grid_cell
            y = (index // 4) * (grid_cell + 18)
            shown = clips[direction][frame_index].resize(
                (grid_cell, grid_cell), Image.Resampling.NEAREST
            )
            grid.alpha_composite(shown, (x, y))
            grid_draw.text(
                (x + 4, y + grid_cell + 2),
                direction,
                fill=(230, 230, 235, 255),
            )
        grid_frames.append(grid)
    _gif(args.root / "assassin_stab_highres_8dir_12fps.gif", grid_frames)


if __name__ == "__main__":
    main()
