#!/usr/bin/env python3
"""Build the lore-authored gem level icons from ImageGen 5x2 masters.

Each master contains levels 1-5 on the first row and levels 6-10 on the
second. The artificial green/magenta screen is removed before the fixed grid
is sampled down to the game's native 32x32 icon size.
"""

from __future__ import annotations

import argparse
from collections import deque
from pathlib import Path
import shutil

import numpy as np
from PIL import Image, ImageDraw, ImageFont


ROOT = Path(__file__).resolve().parents[2]
DEFAULT_SOURCE = ROOT / "art_src" / "gems_2026-07-30"
DEFAULT_OUTPUT = ROOT / "game" / "assets" / "icons"
DEFAULT_MOBILE = ROOT / "mobile" / "game" / "assets" / "icons"
TARGET = 32
SHEET_COLS = 5
SHEET_ROWS = 2

# Source family -> the exact Items.GEM_STATS key used by the runtime.
FAMILIES = {
    "ruby": "atk_flat",
    "garnet": "hp_pct",
    "topaz": "crit",
    "sunstone": "dmg_pct",
    "sapphire": "cdr",
    "opal": "combo",
    "onyx": "physres",
    "lapis": "magres",
    "bloodstone": "physpen",
    "amethyst": "magpen",
    "jade": "eva",
    "amber": "dex",
    "tenacity": "flat_dr",
    "vampire_eye": "lifesteal",
}


def _flood_from_border(mask: np.ndarray) -> np.ndarray:
    """Return the part of a boolean mask connected to the image border."""
    height, width = mask.shape
    seen = np.zeros_like(mask, dtype=bool)
    queue: deque[tuple[int, int]] = deque()

    for x in range(width):
        if mask[0, x]:
            seen[0, x] = True
            queue.append((0, x))
        if mask[height - 1, x] and not seen[height - 1, x]:
            seen[height - 1, x] = True
            queue.append((height - 1, x))
    for y in range(height):
        if mask[y, 0] and not seen[y, 0]:
            seen[y, 0] = True
            queue.append((y, 0))
        if mask[y, width - 1] and not seen[y, width - 1]:
            seen[y, width - 1] = True
            queue.append((y, width - 1))

    while queue:
        y, x = queue.popleft()
        for ny, nx in ((y - 1, x), (y + 1, x), (y, x - 1), (y, x + 1)):
            if 0 <= ny < height and 0 <= nx < width and mask[ny, nx] and not seen[ny, nx]:
                seen[ny, nx] = True
                queue.append((ny, nx))
    return seen


def remove_connected_chroma(cell: Image.Image) -> Image.Image:
    """Remove only screen pixels connected to a cell edge.

    The Opal contains tiny rainbow pinks close to its magenta screen. A global
    color key would erase those lore-bearing inclusions. Edge-connected removal
    preserves them while clearing the backdrop.
    """
    pixels = np.asarray(cell.convert("RGBA")).copy()
    rgb = pixels[..., :3].astype(np.int16)
    border = np.concatenate((rgb[0], rgb[-1], rgb[:, 0], rgb[:, -1]), axis=0)
    key = np.median(border, axis=0)
    distance = np.max(np.abs(rgb - key), axis=2)
    key_max = float(np.max(key))
    spill_channels = [
        channel
        for channel, value in enumerate(key)
        if value >= key_max - 16 and value >= 128
    ]
    other_channels = [channel for channel in range(3) if channel not in spill_channels]
    if not spill_channels or not other_channels:
        raise ValueError(f"Could not identify chroma channels from border color {key}")
    key_strength = np.min(rgb[..., spill_channels], axis=2)
    non_key_strength = np.max(rgb[..., other_channels], axis=2)
    dominance = key_strength - non_key_strength

    # Generated screens are saturated and nearly uniform. The dominance arm
    # catches the small chroma variation around anti-aliased sprite edges.
    candidate = (distance <= 64) | ((dominance >= 48) & (key_strength >= 112))
    connected = _flood_from_border(candidate)
    pixels[..., 3][connected] = 0

    # Generated screen spill can survive immediately outside the black outline
    # at darker values than the main key. Remove only that narrow outer matte;
    # enclosed Opal/Vampire Eye color remains untouched.
    transparent = pixels[..., 3] == 0
    edge_zone = transparent.copy()
    for _ in range(4):
        padded = np.pad(edge_zone, 1, mode="constant", constant_values=False)
        edge_zone = np.logical_or.reduce(
            [
                padded[dy : dy + cell.height, dx : dx + cell.width]
                for dy in range(3)
                for dx in range(3)
            ]
        )
    spill_fringe = edge_zone & ~transparent & (dominance >= 12) & (key_strength >= 48)
    pixels[..., 3][spill_fringe] = 0
    if spill_channels == [1]:
        # None of the green-screen families use green in their authored
        # palette. Dark screen-shadow pixels can sit behind the black outline
        # and evade connectivity, so reject that hue globally for this lane.
        dark_green_spill = (dominance >= 8) & (key_strength >= 16)
        pixels[..., 3][dark_green_spill] = 0
        neutralize = (dominance >= 8) & (key_strength >= 8) & ~dark_green_spill
        pixels[..., 1][neutralize] = np.maximum(
            pixels[..., 0][neutralize],
            pixels[..., 2][neutralize],
        )

    # Hard alpha prevents green/magenta bleed over dark inventory slots.
    pixels[..., 3] = np.where(pixels[..., 3] >= 128, 255, 0).astype(np.uint8)
    return Image.fromarray(pixels, "RGBA")


def square_cell(master: Image.Image, row: int, column: int) -> Image.Image:
    """Crop the centered square authored area from one fixed grid cell."""
    left = round(column * master.width / SHEET_COLS)
    right = round((column + 1) * master.width / SHEET_COLS)
    top = round(row * master.height / SHEET_ROWS)
    bottom = round((row + 1) * master.height / SHEET_ROWS)
    width = right - left
    height = bottom - top
    side = min(width, height)
    left += (width - side) // 2
    top += (height - side) // 2
    return master.crop((left, top, left + side, top + side))


def build_family(master_path: Path, stat: str, output_dir: Path) -> list[Path]:
    master = Image.open(master_path).convert("RGBA")
    ratio = master.width / master.height
    if not 1.95 <= ratio <= 2.05:
        raise ValueError(f"{master_path.name}: expected a roughly 2:1 5x2 sheet, got {master.size}")

    written: list[Path] = []
    for level in range(1, 11):
        row = 0 if level <= 5 else 1
        column = (level - 1) % 5
        frame = remove_connected_chroma(square_cell(master, row, column))
        frame = frame.resize((TARGET, TARGET), Image.Resampling.NEAREST)
        data = np.asarray(frame).copy()
        data[..., 3] = np.where(data[..., 3] >= 128, 255, 0).astype(np.uint8)
        frame = Image.fromarray(data, "RGBA")

        visible = int(np.count_nonzero(data[..., 3]))
        if not 20 <= visible <= TARGET * TARGET * 0.9:
            raise ValueError(
                f"{master_path.name} Lv{level}: implausible visible area {visible}/{TARGET * TARGET}"
            )

        out = output_dir / f"gem_{stat}_lv{level}.png"
        frame.save(out, optimize=True)
        written.append(out)
    return written


def make_contact_sheet(output_dir: Path, destination: Path) -> None:
    scale = 3
    label_width = 150
    cell = TARGET * scale
    header = 30
    row_height = cell + 24
    sheet = Image.new(
        "RGBA",
        (label_width + 10 * cell, header + len(FAMILIES) * row_height),
        (20, 18, 24, 255),
    )
    draw = ImageDraw.Draw(sheet)
    font = ImageFont.load_default()
    draw.text((8, 9), "Bands: rough 1-3 | cut 4-6 | fine 7-9 | perfected 10", fill="white", font=font)

    for row, (family, stat) in enumerate(FAMILIES.items()):
        y = header + row * row_height
        draw.text((8, y + 40), f"{family} [{stat}]", fill=(230, 220, 190, 255), font=font)
        for level in range(1, 11):
            icon = Image.open(output_dir / f"gem_{stat}_lv{level}.png").convert("RGBA")
            icon = icon.resize((cell, cell), Image.Resampling.NEAREST)
            x = label_width + (level - 1) * cell
            checker = Image.new("RGBA", (cell, cell), (39, 36, 45, 255))
            tile = 12
            checker_draw = ImageDraw.Draw(checker)
            for cy in range(0, cell, tile):
                for cx in range(0, cell, tile):
                    if (cx // tile + cy // tile) % 2:
                        checker_draw.rectangle(
                            (cx, cy, cx + tile - 1, cy + tile - 1),
                            fill=(52, 48, 59, 255),
                        )
            checker.alpha_composite(icon)
            sheet.alpha_composite(checker, (x, y))
            draw.text((x + 4, y + cell + 5), f"L{level}", fill=(190, 190, 200, 255), font=font)
        for boundary in (3, 6, 9):
            x = label_width + boundary * cell
            draw.line((x, y, x, y + cell), fill=(212, 170, 70, 255), width=2)

    destination.parent.mkdir(parents=True, exist_ok=True)
    sheet.convert("RGB").save(destination, optimize=True)


def validate(output_dir: Path) -> None:
    errors: list[str] = []
    for stat in FAMILIES.values():
        hashes: set[bytes] = set()
        for level in range(1, 11):
            path = output_dir / f"gem_{stat}_lv{level}.png"
            if not path.exists():
                errors.append(f"{path.name}: missing")
                continue
            image = Image.open(path).convert("RGBA")
            if image.size != (TARGET, TARGET):
                errors.append(f"{path.name}: expected {TARGET}x{TARGET}, got {image.size}")
            alpha = np.asarray(image)[..., 3]
            if np.any((alpha != 0) & (alpha != 255)):
                errors.append(f"{path.name}: semi-transparent pixels")
            hashes.add(image.tobytes())
        if len(hashes) != 10:
            errors.append(f"{stat}: levels are not all visually distinct ({len(hashes)}/10)")
    if errors:
        raise RuntimeError("\n".join(errors))


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--source", type=Path, default=DEFAULT_SOURCE)
    parser.add_argument("--out", type=Path, default=DEFAULT_OUTPUT)
    parser.add_argument("--mobile-out", type=Path, default=DEFAULT_MOBILE)
    parser.add_argument("--no-mobile", action="store_true")
    args = parser.parse_args()

    source_dir = args.source.resolve()
    output_dir = args.out.resolve()
    output_dir.mkdir(parents=True, exist_ok=True)
    missing = [source_dir / f"{family}_master.png" for family in FAMILIES]
    missing = [path for path in missing if not path.exists()]
    if missing:
        raise FileNotFoundError("Missing gem masters:\n" + "\n".join(map(str, missing)))

    written: list[Path] = []
    for family, stat in FAMILIES.items():
        written.extend(build_family(source_dir / f"{family}_master.png", stat, output_dir))
    validate(output_dir)
    contact = source_dir / "qa_contact_sheet.png"
    make_contact_sheet(output_dir, contact)

    if not args.no_mobile:
        mobile_dir = args.mobile_out.resolve()
        mobile_dir.mkdir(parents=True, exist_ok=True)
        for path in written:
            shutil.copy2(path, mobile_dir / path.name)
        validate(mobile_dir)

    print(f"Built {len(written)} lore-authored gem icons in {output_dir}")
    print(f"QA contact sheet: {contact}")
    if not args.no_mobile:
        print(f"Mirrored icons to {args.mobile_out.resolve()}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
