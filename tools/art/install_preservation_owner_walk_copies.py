#!/usr/bin/env python3
"""Install the owner's final Archer/Warlock walk direction copies.

The operation is literal: selected accepted candidate PNGs are copied without
resampling, mirroring, frame reordering, or re-encoding. Warlock South is also
replaced by the corrected seven-frame extraction of its seven-figure source.
"""

from __future__ import annotations

import argparse
import hashlib
import os
import shutil
from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[2]
PASS = ROOT / "art_src" / "class_preservation_upscale_2026-08-01"
SPRITES = ROOT / "game" / "assets" / "sprites"
CELL = 277

JOBS = (
    (
        "archer",
        PASS
        / "archer"
        / "walk_sw"
        / "archer_walk_sw_v02_neutral_alpha_fixed_candidate.png",
        SPRITES / "archer_walk_w.png",
        6,
    ),
    (
        "archer",
        PASS
        / "archer"
        / "walk_se"
        / "archer_walk_se_v02_neutral_alpha_fixed_candidate.png",
        SPRITES / "archer_walk_e.png",
        6,
    ),
    (
        "warlock",
        PASS / "warlock" / "walk_sw" / "warlock_walk_sw_v01_candidate.png",
        SPRITES / "warlock_walk_w.png",
        6,
    ),
    (
        "warlock",
        PASS / "warlock" / "walk_se" / "warlock_walk_se_v02_candidate.png",
        SPRITES / "warlock_walk_e.png",
        6,
    ),
    (
        "warlock",
        PASS / "warlock" / "walk_s" / "warlock_walk_s_v02_7frame_candidate.png",
        SPRITES / "warlock_walk_s.png",
        7,
    ),
    (
        "warlock",
        PASS / "warlock" / "walk_s" / "warlock_walk_s_v02_7frame_candidate.png",
        SPRITES / "warlock_walk.png",
        7,
    ),
)


def _sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for block in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest().upper()


def _validate(path: Path, frames: int) -> None:
    image = Image.open(path).convert("RGBA")
    expected = (frames * CELL, CELL)
    if image.size != expected:
        raise ValueError(f"{path}: expected {expected}, got {image.size}")
    for index in range(frames):
        frame = image.crop((index * CELL, 0, (index + 1) * CELL, CELL))
        alpha = frame.getchannel("A")
        if alpha.getbbox() is None:
            raise ValueError(f"{path}: empty frame {index + 1}")
        if alpha.getextrema()[0] != 0:
            raise ValueError(f"{path}: frame {index + 1} has no transparent field")


def _atomic_copy(source: Path, target: Path) -> None:
    temporary = target.with_name(f"{target.stem}.installing.png")
    shutil.copy2(source, temporary)
    os.replace(temporary, target)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--apply", action="store_true")
    args = parser.parse_args()

    for _class_name, source, target, frames in JOBS:
        _validate(source, frames)
        print(
            f"prepared {target.relative_to(ROOT)} <- {source.relative_to(ROOT)} "
            f"({frames} frames, {_sha256(source)})"
        )
    if not args.apply:
        print("audit passed; runtime untouched (use --apply to install)")
        return

    manifests: dict[Path, list[str]] = {}
    for class_name, source, target, _frames in JOBS:
        archive = (
            PASS
            / class_name
            / "runtime_pre_owner_walk_direction_copies_2026-08-01"
        )
        archive.mkdir(parents=True, exist_ok=True)
        archived = archive / target.name
        if not archived.exists():
            shutil.copy2(target, archived)
        manifests.setdefault(archive, []).append(
            f"{_sha256(archived)}  {archived.name}"
        )

        _atomic_copy(source, target)
        if _sha256(target) != _sha256(source):
            raise ValueError(f"post-install byte check failed: {target}")
        print(f"installed exact copy: {target.relative_to(ROOT)}")

    for archive, entries in manifests.items():
        (archive / "SHA256SUMS.txt").write_text(
            "\n".join(entries) + "\n", encoding="ascii"
        )
        print(f"rollback archive: {archive.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
