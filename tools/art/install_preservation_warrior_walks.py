"""Install the owner-approved 2026-08-01 Warrior walk preservation pass.

The approved review strips use 277px square cells and a common painted-feet
row at y=254.  Warrior's live animation family uses 244px square cells and a
walk feet row at y=239.  Every approved figure fits inside the fixed crop below,
so installation removes transparent overscan only: visible pixels are never
rescaled, mirrored, warped, or otherwise altered.

Run without ``--apply`` for a read-only audit.  The applying path archives and
hashes the nine currently wired walk PNGs before replacing only those files.
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
WARRIOR = PASS / "warrior"
SPRITES = ROOT / "game" / "assets" / "sprites"
ARCHIVE = WARRIOR / "runtime_preinstall_2026-08-01"

SOURCE_CELL = 277
RUNTIME_CELL = 244
FRAME_COUNT = 6
# x=16 keeps the source center within half a pixel of the 244px cell center.
# y=15 maps the approved last painted row 254 to runtime walk row 239.
CROP_BOX = (16, 15, 260, 259)

CANDIDATES = {
    "s": WARRIOR / "walk_s" / "warrior_walk_s_v01_candidate.png",
    "se": WARRIOR / "walk_se" / "warrior_walk_se_v02_candidate.png",
    "e": WARRIOR / "walk_e" / "warrior_walk_e_v06_candidate.png",
    "ne": WARRIOR / "walk_ne" / "warrior_walk_ne_v02_candidate.png",
    "n": WARRIOR / "walk_n" / "warrior_walk_n_v02_candidate.png",
    "nw": WARRIOR / "walk_nw" / "warrior_walk_nw_v02_candidate.png",
    "w": WARRIOR / "walk_w" / "warrior_walk_w_v03_candidate.png",
    "sw": WARRIOR / "walk_sw" / "warrior_walk_sw_v02_candidate.png",
}


def _sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for block in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest().upper()


def _runtime_paths() -> dict[str, Path]:
    paths = {direction: SPRITES / f"warrior_walk_{direction}.png" for direction in CANDIDATES}
    paths["flat_s"] = SPRITES / "warrior_walk.png"
    return paths


def _prepared_strip(source: Path) -> tuple[Image.Image, list[tuple[int, int, int, int]]]:
    strip = Image.open(source).convert("RGBA")
    expected = (FRAME_COUNT * SOURCE_CELL, SOURCE_CELL)
    if strip.size != expected:
        raise ValueError(f"{source}: expected {expected}, got {strip.size}")

    output = Image.new(
        "RGBA", (FRAME_COUNT * RUNTIME_CELL, RUNTIME_CELL), (0, 0, 0, 0)
    )
    output_bounds: list[tuple[int, int, int, int]] = []
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
                f"{source}: frame {index + 1} bbox {bbox} exceeds safe crop {CROP_BOX}"
            )
        cropped = frame.crop(CROP_BOX)
        cropped_bbox = cropped.getchannel("A").getbbox()
        if cropped_bbox is None:
            raise ValueError(f"{source}: frame {index + 1} became empty")
        if cropped_bbox[3] - 1 != 239:
            raise ValueError(
                f"{source}: frame {index + 1} feet row is {cropped_bbox[3] - 1}, expected 239"
            )
        output.alpha_composite(cropped, (index * RUNTIME_CELL, 0))
        output_bounds.append(cropped_bbox)
    return output, output_bounds


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
        for path in sorted(ARCHIVE.glob("warrior_walk*.png"), key=lambda item: item.name)
    ]
    (ARCHIVE / "SHA256SUMS.txt").write_text("\n".join(lines) + "\n", encoding="ascii")


def _atomic_save(image: Image.Image, target: Path) -> None:
    temporary = target.with_name(f"{target.stem}.installing.png")
    image.save(temporary, optimize=True)
    os.replace(temporary, target)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--apply", action="store_true", help="archive current runtime PNGs and install"
    )
    args = parser.parse_args()

    runtime = _runtime_paths()
    missing = [path for path in [*CANDIDATES.values(), *runtime.values()] if not path.exists()]
    if missing:
        raise FileNotFoundError("missing required files:\n" + "\n".join(map(str, missing)))

    prepared: dict[str, Image.Image] = {}
    for direction, source in CANDIDATES.items():
        strip, bounds = _prepared_strip(source)
        prepared[direction] = strip
        print(f"{direction}: {source.name} -> {strip.size}; bounds={bounds}")

    if not args.apply:
        print("audit passed; runtime untouched (use --apply to install)")
        return

    _archive_runtime(runtime)
    for direction, strip in prepared.items():
        _atomic_save(strip, runtime[direction])
    _atomic_save(prepared["s"], runtime["flat_s"])

    print(f"archived prior runtime under {ARCHIVE}")
    for key, path in sorted(runtime.items()):
        print(f"installed {key}: {path.name} {_sha256(path)}")


if __name__ == "__main__":
    main()
