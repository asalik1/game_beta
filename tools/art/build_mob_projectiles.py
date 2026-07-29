#!/usr/bin/env python3
"""Build the authored Crownfall mob projectile family from its 3x3 master."""

from __future__ import annotations

import argparse
import os
from pathlib import Path

import numpy as np
from PIL import Image

from build_mob_redesigns import remove_chroma


PROJECTILES = (
    "mob_blight_thorn",
    "mob_storm_fork",
    "mob_howl_wave",
    "mob_null_shard",
    "mob_grave_nail",
    "mob_forge_brand",
    "mob_hush_wave",
    "mob_bloom_seed",
    "mob_plague_spore",
)

TARGET_CELL = 64


def default_source() -> Path:
    root = os.environ.get("CROWNLESS_ART_SRC")
    if root:
        candidate = Path(root).expanduser()
        nested = candidate / "MobProjectiles_2026-07-25" / "mob_projectiles_master.png"
        if nested.exists():
            return nested
        return candidate / "mob_projectiles_master.png"
    return (
        Path(__file__).resolve().parents[2]
        / "art_src"
        / "Custom"
        / "MobProjectiles_2026-07-25"
        / "mob_projectiles_master.png"
    )


def normalize(cell: Image.Image) -> Image.Image:
    cell = cell.resize((TARGET_CELL, TARGET_CELL), Image.Resampling.LANCZOS)
    pixels = np.asarray(cell).copy()
    pixels[..., 3] = np.where(pixels[..., 3] >= 96, 255, 0).astype(np.uint8)
    return Image.fromarray(pixels, "RGBA")


def validate(path: Path) -> None:
    image = Image.open(path).convert("RGBA")
    if image.size != (TARGET_CELL, TARGET_CELL):
        raise ValueError(f"{path.name}: expected {TARGET_CELL}px square, got {image.size}")
    alpha = np.asarray(image)[..., 3]
    coverage = float((alpha > 0).mean())
    if not 0.01 <= coverage <= 0.60:
        raise ValueError(f"{path.name}: implausible foreground coverage {coverage:.3f}")
    if any(alpha[y, x] for y, x in ((0, 0), (0, -1), (-1, 0), (-1, -1))):
        raise ValueError(f"{path.name}: a corner is not transparent")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--source", type=Path, default=default_source())
    parser.add_argument(
        "--out",
        type=Path,
        default=Path(__file__).resolve().parents[2] / "game" / "assets" / "sprites",
    )
    args = parser.parse_args()
    source = args.source.resolve()
    output = args.out.resolve()
    if not source.exists():
        raise FileNotFoundError(source)
    output.mkdir(parents=True, exist_ok=True)

    master = remove_chroma(source)
    cell_w = master.width / 3
    cell_h = master.height / 3
    for index, name in enumerate(PROJECTILES):
        row, column = divmod(index, 3)
        box = (
            round(column * cell_w),
            round(row * cell_h),
            round((column + 1) * cell_w),
            round((row + 1) * cell_h),
        )
        destination = output / f"{name}.png"
        normalize(master.crop(box)).save(destination, optimize=True)
        validate(destination)

    print(f"Built {len(PROJECTILES)} mob projectiles in {output}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
