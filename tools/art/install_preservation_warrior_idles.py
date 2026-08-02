"""Install the self-QA-approved old-design Warrior idle preservation set.

Only the eight directional ``warrior_anim_<dir>.png`` files and the flat South
alias ``warrior_anim.png`` are replaced. The currently wired redesign files are
archived with SHA-256 checksums before any write occurs.
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
ARCHIVE = WARRIOR / "runtime_pre_idle_preservation_2026-08-01"

DIRECTIONS = ("s", "se", "e", "ne", "n", "nw", "w", "sw")
CANDIDATES = {
    direction: WARRIOR
    / f"idle_{direction}"
    / f"warrior_idle_{direction}_v01_candidate.png"
    for direction in DIRECTIONS
}
SOURCE_CELL = 277
RUNTIME_CELL = 244
FRAME_COUNT = 4
CROP_BOX = (16, 15, 260, 259)


def _sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for block in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest().upper()


def _runtime_paths() -> dict[str, Path]:
    paths = {
        direction: SPRITES / f"warrior_anim_{direction}.png"
        for direction in DIRECTIONS
    }
    paths["flat_s"] = SPRITES / "warrior_anim.png"
    return paths


def _prepared_strip(source: Path) -> Image.Image:
    strip = Image.open(source).convert("RGBA")
    expected = (FRAME_COUNT * SOURCE_CELL, SOURCE_CELL)
    if strip.size != expected:
        raise ValueError(f"{source}: expected {expected}, got {strip.size}")
    output = Image.new(
        "RGBA", (FRAME_COUNT * RUNTIME_CELL, RUNTIME_CELL), (0, 0, 0, 0)
    )
    for index in range(FRAME_COUNT):
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


def _archive_runtime(paths: dict[str, Path]) -> None:
    ARCHIVE.mkdir(parents=True, exist_ok=True)
    for path in paths.values():
        if not path.exists():
            raise FileNotFoundError(path)
        archived = ARCHIVE / path.name
        if not archived.exists():
            shutil.copy2(path, archived)
    lines = [
        f"{_sha256(path)}  {path.name}"
        for path in sorted(ARCHIVE.glob("warrior_anim*.png"), key=lambda p: p.name)
    ]
    (ARCHIVE / "SHA256SUMS.txt").write_text("\n".join(lines) + "\n", encoding="ascii")


def _atomic_save(image: Image.Image, target: Path) -> None:
    temporary = target.with_name(f"{target.stem}.installing.png")
    image.save(temporary, optimize=True)
    os.replace(temporary, target)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--apply", action="store_true")
    args = parser.parse_args()

    runtime = _runtime_paths()
    missing = [path for path in [*CANDIDATES.values(), *runtime.values()] if not path.exists()]
    if missing:
        raise FileNotFoundError("missing required files:\n" + "\n".join(map(str, missing)))

    prepared = {direction: _prepared_strip(source) for direction, source in CANDIDATES.items()}
    for direction in DIRECTIONS:
        print(f"{direction}: {CANDIDATES[direction].name} -> {prepared[direction].size}")
    if not args.apply:
        print("audit passed; runtime untouched (use --apply to install)")
        return

    _archive_runtime(runtime)
    for direction in DIRECTIONS:
        _atomic_save(prepared[direction], runtime[direction])
    _atomic_save(prepared["s"], runtime["flat_s"])
    print(f"archived redesign idles under {ARCHIVE}")
    for key, path in sorted(runtime.items()):
        print(f"installed {key}: {path.name} {_sha256(path)}")


if __name__ == "__main__":
    main()
