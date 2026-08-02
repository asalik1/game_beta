#!/usr/bin/env python3
"""Install the owner-approved Assassin east walk and deterministic facings.

East is copied byte-for-byte to NE/SE. West is a framewise mirror of east and
is copied byte-for-byte to NW/SW. North, south, and the south alias are not
touched. The replaced runtime strips are archived on the first run.
"""

from __future__ import annotations

import shutil
import os
from pathlib import Path

from PIL import Image, ImageOps


ROOT = Path(__file__).resolve().parents[2]
CELL = 277
FRAMES = 6
SOURCE = (
    ROOT
    / "art_src/class_preservation_upscale_2026-08-01/assassin/walk_e"
    / "pixellab_second_dagger_v03_selected"
    / "assassin_walk_e_pixellab_second_dagger_v03_selected_candidate.png"
)
OUTPUT = (
    ROOT
    / "art_src/class_preservation_upscale_2026-08-01/assassin"
    / "walk_owner_mapping_v01"
)
BACKUP = OUTPUT / "runtime_pre_owner_east_mapping_2026-08-02"
GAME = ROOT / "game/assets/sprites"
MOBILE = ROOT / "mobile/game/assets/sprites"


def _load_strip(path: Path) -> Image.Image:
    image = Image.open(path).convert("RGBA")
    expected = (CELL * FRAMES, CELL)
    if image.size != expected:
        raise ValueError(f"{path}: expected {expected}, got {image.size}")
    for index in range(FRAMES):
        frame = image.crop((index * CELL, 0, (index + 1) * CELL, CELL))
        if frame.getbbox() is None:
            raise ValueError(f"{path}: empty frame {index + 1}")
    return image


def _mirror_frames(strip: Image.Image) -> Image.Image:
    mirrored = Image.new("RGBA", strip.size, (0, 0, 0, 0))
    for index in range(FRAMES):
        frame = strip.crop((index * CELL, 0, (index + 1) * CELL, CELL))
        mirrored.alpha_composite(ImageOps.mirror(frame), (index * CELL, 0))
    return mirrored


def _copy_if_changed(source: Path, target: Path) -> None:
    payload = source.read_bytes()
    if target.exists() and target.read_bytes() == payload:
        return
    # Replace via a sibling temp file: Windows refuses to truncate a PNG while
    # the Godot importer has a mapped view, but permits an atomic replacement.
    temporary = target.with_name(f"{target.stem}.codex-tmp{target.suffix}")
    temporary.write_bytes(payload)
    os.replace(temporary, target)


def main() -> None:
    east = _load_strip(SOURCE)
    west = _mirror_frames(east)
    OUTPUT.mkdir(parents=True, exist_ok=True)
    east_path = OUTPUT / "assassin_walk_e_approved_two_daggers.png"
    west_path = OUTPUT / "assassin_walk_w_mirrored_two_daggers.png"
    east.save(east_path)
    west.save(west_path)

    direction_sources = {
        "e": east_path,
        "ne": east_path,
        "se": east_path,
        "w": west_path,
        "nw": west_path,
        "sw": west_path,
    }
    for runtime_dir in (GAME, MOBILE):
        backup_dir = BACKUP / runtime_dir.relative_to(ROOT)
        backup_dir.mkdir(parents=True, exist_ok=True)
        for direction, source in direction_sources.items():
            target = runtime_dir / f"assassin_walk_{direction}.png"
            backup = backup_dir / target.name
            if target.exists() and not backup.exists():
                shutil.copy2(target, backup)
            _copy_if_changed(source, target)

    # Exact equality is intentional for the copied diagonals.
    east_bytes = east_path.read_bytes()
    west_bytes = west_path.read_bytes()
    for runtime_dir in (GAME, MOBILE):
        for direction in ("e", "ne", "se"):
            assert (runtime_dir / f"assassin_walk_{direction}.png").read_bytes() == east_bytes
        for direction in ("w", "nw", "sw"):
            assert (runtime_dir / f"assassin_walk_{direction}.png").read_bytes() == west_bytes
    print("installed Assassin E/NE/SE and mirrored W/NW/SW in game + mobile")


if __name__ == "__main__":
    main()
