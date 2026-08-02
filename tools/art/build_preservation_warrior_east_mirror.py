"""Build Warrior East V10 as a literal per-frame mirror of approved West V03.

Each fixed 277px cell is flipped independently. This changes facing without
reversing frame order or moving pixels across animation-cell boundaries.
"""

from __future__ import annotations

import sys
from pathlib import Path

from PIL import Image


TOOLS = Path(__file__).resolve().parent
if str(TOOLS) not in sys.path:
    sys.path.insert(0, str(TOOLS))

from build_preservation_walk_candidate import _write_qa  # noqa: E402


ROOT = Path(__file__).resolve().parents[2]
WARRIOR = (
    ROOT / "art_src" / "class_preservation_upscale_2026-08-01" / "warrior"
)
SOURCE = WARRIOR / "walk_w" / "warrior_walk_w_v03_candidate.png"
OUTPUT = WARRIOR / "walk_e"
STEM = "warrior_walk_e_v10_mirrored_west"
CELL = 277
FRAMES = 6


def main() -> None:
    source = Image.open(SOURCE).convert("RGBA")
    expected = (CELL * FRAMES, CELL)
    if source.size != expected:
        raise ValueError(f"{SOURCE}: expected {expected}, got {source.size}")

    frames: list[Image.Image] = []
    output = Image.new("RGBA", expected, (0, 0, 0, 0))
    for index in range(FRAMES):
        west = source.crop((index * CELL, 0, (index + 1) * CELL, CELL))
        east = west.transpose(Image.Transpose.FLIP_LEFT_RIGHT)
        # Mirroring must preserve every RGBA pixel and only reverse its x.
        if east.transpose(Image.Transpose.FLIP_LEFT_RIGHT).tobytes() != west.tobytes():
            raise ValueError(f"non-lossless mirror at frame {index + 1}")
        output.alpha_composite(east, (index * CELL, 0))
        frames.append(east)

    OUTPUT.mkdir(parents=True, exist_ok=True)
    candidate = OUTPUT / f"{STEM}_candidate.png"
    output.save(candidate)
    _write_qa(
        OUTPUT,
        STEM,
        "Warrior East V10 — literal mirror of approved West V03 (UNWIRED)",
        frames,
        9.0,
        4,
    )
    print(f"{STEM}: {FRAMES} losslessly mirrored cells -> {candidate}")


if __name__ == "__main__":
    main()
