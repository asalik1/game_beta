"""Build the high-resolution Moonstone sprite from its keyed ImageGen master.

The master is already keyed to alpha so this step is deliberately small and
deterministic: crop the visible object, fit it into a 128 px square cell, and
anchor the stone to the bottom of that cell.  Keeping the runtime texture
larger than the old 22 px icon lets the Codex downsample clean painted facets
instead of enlarging individual source pixels.
"""

from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "art_src" / "moonstone_2026-08-02" / "moonstone_alpha_master.png"
OUTPUT = ROOT / "game" / "assets" / "sprites" / "rv_mat_gem_moon.png"

CELL = 128
PADDING_X = 10
PADDING_TOP = 6
PADDING_BOTTOM = 4


def build() -> None:
    source = Image.open(SOURCE).convert("RGBA")
    alpha_box = source.getchannel("A").getbbox()
    if alpha_box is None:
        raise RuntimeError(f"Moonstone master has no visible pixels: {SOURCE}")

    stone = source.crop(alpha_box)
    available_w = CELL - PADDING_X * 2
    available_h = CELL - PADDING_TOP - PADDING_BOTTOM
    scale = min(available_w / stone.width, available_h / stone.height)
    size = (max(1, round(stone.width * scale)), max(1, round(stone.height * scale)))
    stone = stone.resize(size, Image.Resampling.LANCZOS)

    cell = Image.new("RGBA", (CELL, CELL), (0, 0, 0, 0))
    x = (CELL - stone.width) // 2
    y = CELL - PADDING_BOTTOM - stone.height
    cell.alpha_composite(stone, (x, y))
    cell.save(OUTPUT, optimize=True)

    alpha = cell.getchannel("A")
    if alpha.getbbox() is None or alpha.getextrema() != (0, 255):
        raise RuntimeError("Built Moonstone must contain both transparent and opaque pixels")
    print(f"Wrote {OUTPUT.relative_to(ROOT)} ({CELL}x{CELL}, visible {stone.width}x{stone.height})")


if __name__ == "__main__":
    build()
