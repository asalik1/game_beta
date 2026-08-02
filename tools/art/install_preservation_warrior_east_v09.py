"""Install the owner-approved Warrior East V09 transition repair.

This revision is intentionally East-only. It verifies that the live strip is
exactly the previously installed V06, archives that file with a checksum, and
then installs the approved eight-frame V09 strip. No other direction is readied
for writing.
"""

from __future__ import annotations

import argparse
import hashlib
import os
import shutil
from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[2]
WALK_E = (
    ROOT
    / "art_src"
    / "class_preservation_upscale_2026-08-01"
    / "warrior"
    / "walk_e"
)
RUNTIME = ROOT / "game" / "assets" / "sprites" / "warrior_walk_e.png"
ARCHIVE = WALK_E / "runtime_pre_v09_2026-08-01"

V06 = WALK_E / "warrior_walk_e_v06_candidate.png"
V09 = WALK_E / "warrior_walk_e_v09_candidate.png"
SOURCE_CELL = 277
RUNTIME_CELL = 244
CROP_BOX = (16, 15, 260, 259)


def _sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for block in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest().upper()


def _prepared_strip(source: Path, frame_count: int) -> Image.Image:
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
        alpha = frame.getchannel("A")
        bbox = alpha.getbbox()
        if bbox is None:
            raise ValueError(f"{source}: frame {index + 1} is empty")
        if any(value not in (0, 255) for value in alpha.get_flattened_data()):
            raise ValueError(f"{source}: frame {index + 1} has semi-transparent pixels")
        left, top, right, bottom = CROP_BOX
        if bbox[0] < left or bbox[1] < top or bbox[2] > right or bbox[3] > bottom:
            raise ValueError(
                f"{source}: frame {index + 1} bbox {bbox} exceeds {CROP_BOX}"
            )
        cropped = frame.crop(CROP_BOX)
        cropped_bbox = cropped.getchannel("A").getbbox()
        if cropped_bbox is None or cropped_bbox[3] - 1 != 239:
            raise ValueError(
                f"{source}: frame {index + 1} does not ground on runtime row 239"
            )
        output.alpha_composite(cropped, (index * RUNTIME_CELL, 0))
    return output


def _image_digest(image: Image.Image) -> str:
    digest = hashlib.sha256()
    digest.update(image.mode.encode("ascii"))
    digest.update(str(image.size).encode("ascii"))
    digest.update(image.tobytes())
    return digest.hexdigest().upper()


def _atomic_save(image: Image.Image, target: Path) -> None:
    temporary = target.with_name(f"{target.stem}.installing.png")
    image.save(temporary, optimize=True)
    os.replace(temporary, target)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--apply", action="store_true")
    args = parser.parse_args()

    if not RUNTIME.exists():
        raise FileNotFoundError(RUNTIME)
    expected_live = _prepared_strip(V06, 6)
    live = Image.open(RUNTIME).convert("RGBA")
    if _image_digest(live) != _image_digest(expected_live):
        raise ValueError(
            "guard failed: live warrior_walk_e.png is not the installed V06 strip"
        )
    replacement = _prepared_strip(V09, 8)
    print(f"live V06 verified: {RUNTIME} {live.size} {_sha256(RUNTIME)}")
    print(f"V09 prepared: {replacement.size}; 8 frames at {RUNTIME_CELL}px")

    if not args.apply:
        print("audit passed; runtime untouched (use --apply to install)")
        return

    ARCHIVE.mkdir(parents=True, exist_ok=True)
    archived = ARCHIVE / RUNTIME.name
    if not archived.exists():
        shutil.copy2(RUNTIME, archived)
    (ARCHIVE / "SHA256SUMS.txt").write_text(
        f"{_sha256(archived)}  {archived.name}\n", encoding="ascii"
    )
    _atomic_save(replacement, RUNTIME)
    installed = Image.open(RUNTIME).convert("RGBA")
    if _image_digest(installed) != _image_digest(replacement):
        raise ValueError("post-install verification failed")
    print(f"archived V06: {archived} {_sha256(archived)}")
    print(f"installed V09: {RUNTIME} {installed.size} {_sha256(RUNTIME)}")


if __name__ == "__main__":
    main()
