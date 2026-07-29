#!/usr/bin/env python3
"""Build Crownfall mob strips from the approved ImageGen source sheets.

Each source sheet is a strict 4x4 grid:
  row 1: idle, row 2: walk, row 3: attack, row 4: defeat.

The source masters are committed at art_src/Custom/MobRedesign_2026-07-25 so
the installed strips are never the only editable copy. Set CROWNLESS_ART_SRC
to override the location.
"""

from __future__ import annotations

import argparse
import os
from pathlib import Path

import numpy as np
from PIL import Image


MOBS = (
    "skeleton",
    "zombie",
    "orc",
    "orc_rogue",
    "fungus_heavy",
    "elf_ranger",
    "skeleton_warrior",
    "null_acolyte",
    "mummy",
    "skeleton_mage",
    "skeleton_rogue",
    "stone_base",
    "mummy_mage",
    "stone_broken",
    "royal_knight",
    "banshee",
    "elf_druid",
    "fungus_long",
    "static_caller",
    "bandit_scout",
    "vow_sentinel",
)

ANIMATIONS = ("anim", "walk", "attack", "death")
TARGET_CELL = 192


def default_source_dir() -> Path:
    root = os.environ.get("CROWNLESS_ART_SRC")
    if root:
        candidate = Path(root).expanduser()
        nested = candidate / "MobRedesign_2026-07-25"
        return nested if nested.exists() else candidate
    return Path(__file__).resolve().parents[2] / "art_src" / "Custom" / "MobRedesign_2026-07-25"


def remove_chroma(source: Path) -> Image.Image:
    """Remove the deliberately artificial green or magenta screen."""
    image = Image.open(source).convert("RGBA")
    pixels = np.asarray(image).copy()
    rgb = pixels[..., :3].astype(np.float32)
    border = np.zeros((image.height, image.width), dtype=bool)
    band = max(8, min(image.size) // 40)
    border[:band, :] = True
    border[-band:, :] = True
    border[:, :band] = True
    border[:, -band:] = True
    key = np.median(rgb[border], axis=0)
    distance = np.max(np.abs(rgb - key), axis=2)

    key_max = float(np.max(key))
    spill_channels = [index for index, value in enumerate(key) if value >= key_max - 16 and value >= 128]
    non_spill = [index for index in range(3) if index not in spill_channels]
    if not spill_channels or not non_spill:
        raise ValueError(f"{source.name}: could not identify a chroma channel from {key}")

    if len(spill_channels) > 1:
        key_strength = np.min(rgb[..., spill_channels], axis=2)
    else:
        key_strength = rgb[..., spill_channels[0]]
    non_key_strength = np.max(rgb[..., non_spill], axis=2)
    dominance = key_strength - non_key_strength

    ratio = np.clip((distance - 12.0) / (220.0 - 12.0), 0.0, 1.0)
    distance_alpha = 255.0 * ratio * ratio * (3.0 - 2.0 * ratio)
    denominator = np.maximum(1.0, key_max - non_key_strength)
    dominance_alpha = 255.0 * (
        1.0 - np.minimum(1.0, np.maximum(0.0, dominance) / denominator)
    )
    key_like = (distance <= 32.0) | (dominance >= 16.0)
    alpha = np.where(key_like, np.minimum(distance_alpha, dominance_alpha), 255.0)
    alpha[alpha <= 8.0] = 0.0
    pixels[..., 3] = np.round(alpha).astype(np.uint8)

    # Despill only the narrow matte edge beside pixels that will become fully
    # transparent. This keeps real green cloth and pink flower interiors while
    # removing the artificial screen-colored antialias fringe.
    transparent_zone = alpha < 96.0
    edge_zone = transparent_zone.copy()
    for _ in range(3):
        padded = np.pad(edge_zone, 1, mode="constant", constant_values=False)
        edge_zone = np.logical_or.reduce(
            [
                padded[dy : dy + image.height, dx : dx + image.width]
                for dy in range(3)
                for dx in range(3)
            ]
        )
    fringe = key_like & edge_zone & (alpha >= 96.0) & (alpha < 245.0)
    anchor = np.maximum(0.0, non_key_strength - 1.0)
    for channel in spill_channels:
        pixels[..., channel][fringe] = np.minimum(
            rgb[..., channel][fringe],
            anchor[fringe],
        ).astype(np.uint8)

    return Image.fromarray(pixels, "RGBA")


def resize_frame(frame: Image.Image) -> Image.Image:
    if frame.size != (TARGET_CELL, TARGET_CELL):
        frame = frame.resize((TARGET_CELL, TARGET_CELL), Image.Resampling.LANCZOS)
    data = np.asarray(frame).copy()
    data[..., 3] = np.where(data[..., 3] >= 96, 255, 0).astype(np.uint8)
    return Image.fromarray(data, "RGBA")


def extract_grid(master: Image.Image, mob: str, output_dir: Path) -> None:
    source_w = master.width / 4
    source_h = master.height / 4
    if abs(source_w - source_h) > 2:
        raise ValueError(f"{mob}: expected square cells, got {source_w}x{source_h}")

    built: dict[str, Image.Image] = {}
    for row, animation in enumerate(ANIMATIONS):
        frames: list[Image.Image] = []
        for column in range(4):
            box = (
                round(column * source_w),
                round(row * source_h),
                round((column + 1) * source_w),
                round((row + 1) * source_h),
            )
            frames.append(resize_frame(master.crop(box)))

        strip = Image.new("RGBA", (TARGET_CELL * 4, TARGET_CELL))
        for index, frame in enumerate(frames):
            strip.alpha_composite(frame, (index * TARGET_CELL, 0))
        built[animation] = strip
        strip.save(output_dir / f"{mob}_{animation}.png", optimize=True)

    built["anim"].crop((0, 0, TARGET_CELL, TARGET_CELL)).save(
        output_dir / f"{mob}.png",
        optimize=True,
    )


def validate(output_dir: Path) -> None:
    errors: list[str] = []
    for mob in MOBS:
        base = output_dir / f"{mob}.png"
        expected = (TARGET_CELL, TARGET_CELL)
        if not base.exists() or Image.open(base).size != expected:
            errors.append(f"{base.name}: expected {expected}")
        for animation in ANIMATIONS:
            strip = output_dir / f"{mob}_{animation}.png"
            expected = (TARGET_CELL * 4, TARGET_CELL)
            if not strip.exists() or Image.open(strip).size != expected:
                errors.append(f"{strip.name}: expected {expected}")
    if errors:
        raise RuntimeError("\n".join(errors))


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--source", type=Path, default=default_source_dir())
    parser.add_argument(
        "--out",
        type=Path,
        default=Path(__file__).resolve().parents[2] / "game" / "assets" / "sprites",
    )
    args = parser.parse_args()
    source_dir = args.source.resolve()
    output_dir = args.out.resolve()
    output_dir.mkdir(parents=True, exist_ok=True)

    missing = [source_dir / f"{mob}_master.png" for mob in MOBS]
    missing = [path for path in missing if not path.exists()]
    if missing:
        raise FileNotFoundError("Missing source masters:\n" + "\n".join(map(str, missing)))

    for mob in MOBS:
        master = remove_chroma(source_dir / f"{mob}_master.png")
        extract_grid(master, mob, output_dir)

    validate(output_dir)
    print(
        f"Built {len(MOBS)} mobs x {len(ANIMATIONS)} strips "
        f"plus base sprites in {output_dir}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
