"""Install Warrior East V10 as the exact per-cell mirror of live West V03.

The live West strip is first verified against its approved review candidate.
The live East strip is verified as installed V09 and archived before replacement.
Only ``warrior_walk_e.png`` is written.
"""

from __future__ import annotations

import argparse
import hashlib
import os
import shutil
from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[2]
WARRIOR = (
    ROOT / "art_src" / "class_preservation_upscale_2026-08-01" / "warrior"
)
SPRITES = ROOT / "game" / "assets" / "sprites"
WEST_RUNTIME = SPRITES / "warrior_walk_w.png"
EAST_RUNTIME = SPRITES / "warrior_walk_e.png"
WEST_SOURCE = WARRIOR / "walk_w" / "warrior_walk_w_v03_candidate.png"
EAST_V09_SOURCE = WARRIOR / "walk_e" / "warrior_walk_e_v09_candidate.png"
ARCHIVE = WARRIOR / "walk_e" / "runtime_pre_v10_mirrored_west_2026-08-01"

SOURCE_CELL = 277
RUNTIME_CELL = 244
CROP_BOX = (16, 15, 260, 259)


def _sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for block in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest().upper()


def _image_digest(image: Image.Image) -> str:
    digest = hashlib.sha256()
    digest.update(image.mode.encode("ascii"))
    digest.update(str(image.size).encode("ascii"))
    digest.update(image.tobytes())
    return digest.hexdigest().upper()


def _prepared_review(source: Path, frame_count: int) -> Image.Image:
    strip = Image.open(source).convert("RGBA")
    expected = (frame_count * SOURCE_CELL, SOURCE_CELL)
    if strip.size != expected:
        raise ValueError(f"{source}: expected {expected}, got {strip.size}")
    output = Image.new(
        "RGBA", (frame_count * RUNTIME_CELL, RUNTIME_CELL), (0, 0, 0, 0)
    )
    for index in range(frame_count):
        frame = strip.crop(
            (index * SOURCE_CELL, 0, (index + 1) * SOURCE_CELL, SOURCE_CELL)
        )
        output.alpha_composite(frame.crop(CROP_BOX), (index * RUNTIME_CELL, 0))
    return output


def _mirrored_runtime(west: Image.Image) -> Image.Image:
    frame_count = 6
    expected = (frame_count * RUNTIME_CELL, RUNTIME_CELL)
    if west.size != expected:
        raise ValueError(f"live West is {west.size}, expected {expected}")
    east = Image.new("RGBA", expected, (0, 0, 0, 0))
    for index in range(frame_count):
        frame = west.crop(
            (index * RUNTIME_CELL, 0, (index + 1) * RUNTIME_CELL, RUNTIME_CELL)
        )
        mirrored = frame.transpose(Image.Transpose.FLIP_LEFT_RIGHT)
        if mirrored.transpose(Image.Transpose.FLIP_LEFT_RIGHT).tobytes() != frame.tobytes():
            raise ValueError(f"non-lossless runtime mirror at frame {index + 1}")
        east.alpha_composite(mirrored, (index * RUNTIME_CELL, 0))
    return east


def _atomic_save(image: Image.Image, target: Path) -> None:
    temporary = target.with_name(f"{target.stem}.installing.png")
    image.save(temporary, optimize=True)
    os.replace(temporary, target)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--apply", action="store_true")
    args = parser.parse_args()

    live_west = Image.open(WEST_RUNTIME).convert("RGBA")
    expected_west = _prepared_review(WEST_SOURCE, 6)
    if _image_digest(live_west) != _image_digest(expected_west):
        raise ValueError("guard failed: live West is not approved West V03")

    live_east = Image.open(EAST_RUNTIME).convert("RGBA")
    expected_east_v09 = _prepared_review(EAST_V09_SOURCE, 8)
    if _image_digest(live_east) != _image_digest(expected_east_v09):
        raise ValueError("guard failed: live East is not installed East V09")

    replacement = _mirrored_runtime(live_west)
    print(f"West V03 verified: {live_west.size} {_sha256(WEST_RUNTIME)}")
    print(f"East V09 verified: {live_east.size} {_sha256(EAST_RUNTIME)}")
    print(f"East V10 prepared as exact West mirror: {replacement.size}")
    if not args.apply:
        print("audit passed; runtime untouched (use --apply to install)")
        return

    ARCHIVE.mkdir(parents=True, exist_ok=True)
    archived = ARCHIVE / EAST_RUNTIME.name
    if not archived.exists():
        shutil.copy2(EAST_RUNTIME, archived)
    (ARCHIVE / "SHA256SUMS.txt").write_text(
        f"{_sha256(archived)}  {archived.name}\n", encoding="ascii"
    )
    _atomic_save(replacement, EAST_RUNTIME)
    installed = Image.open(EAST_RUNTIME).convert("RGBA")
    if _image_digest(installed) != _image_digest(replacement):
        raise ValueError("post-install verification failed")
    print(f"archived V09: {archived} {_sha256(archived)}")
    print(f"installed V10: {EAST_RUNTIME} {_sha256(EAST_RUNTIME)}")


if __name__ == "__main__":
    main()
