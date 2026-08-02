#!/usr/bin/env python3
"""Historical Archer walk mirror installer without frame-order changes.

Northwest is mirrored per cell into Northeast, and West is mirrored per cell
into East. Repaired source candidates are geometry-validated, current target
strips are guarded by pixel digests, and installed outputs are re-read and
verified before completion. This mapping was superseded by the owner's later
SW-to-W and SE-to-E exact-copy instruction; do not use it for the current set.
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
ARCHER = PASS / "archer"
SPRITES = ROOT / "game" / "assets" / "sprites"
ARCHIVE = ARCHER / "runtime_pre_owner_mirrored_walks_2026-08-01"
CELL = 277
FRAMES = 6
SIZE = (CELL * FRAMES, CELL)

JOBS = (
    {
        "source_runtime": SPRITES / "archer_walk_nw.png",
        "source_fixed": ARCHER
        / "walk_nw"
        / "archer_walk_nw_v02_alpha_fixed_candidate.png",
        "target_runtime": SPRITES / "archer_walk_ne.png",
        "target_approved": ARCHER / "walk_ne" / "archer_walk_ne_v01_candidate.png",
        "derived": ARCHER
        / "walk_ne"
        / "archer_walk_ne_v02_mirrored_nw_candidate.png",
    },
    {
        "source_runtime": SPRITES / "archer_walk_w.png",
        "source_fixed": ARCHER
        / "walk_w"
        / "archer_walk_w_v02_alpha_fixed_candidate.png",
        "target_runtime": SPRITES / "archer_walk_e.png",
        "target_approved": ARCHER / "walk_e" / "archer_walk_e_v01_candidate.png",
        "derived": ARCHER / "walk_e" / "archer_walk_e_v02_mirrored_w_candidate.png",
    },
)


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


def _load(path: Path) -> Image.Image:
    image = Image.open(path).convert("RGBA")
    if image.size != SIZE:
        raise ValueError(f"{path}: expected {SIZE}, got {image.size}")
    return image


def _mirror_per_cell(source: Image.Image) -> Image.Image:
    output = Image.new("RGBA", SIZE, (0, 0, 0, 0))
    for index in range(FRAMES):
        frame = source.crop((index * CELL, 0, (index + 1) * CELL, CELL))
        mirrored = frame.transpose(Image.Transpose.FLIP_LEFT_RIGHT)
        restored = mirrored.transpose(Image.Transpose.FLIP_LEFT_RIGHT)
        if restored.tobytes() != frame.tobytes():
            raise ValueError(f"non-lossless mirror at frame {index + 1}")
        output.alpha_composite(mirrored, (index * CELL, 0))
    return output


def _atomic_save(image: Image.Image, target: Path) -> None:
    target.parent.mkdir(parents=True, exist_ok=True)
    temporary = target.with_name(f"{target.stem}.installing.png")
    image.save(temporary, optimize=True)
    os.replace(temporary, target)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--apply", action="store_true")
    args = parser.parse_args()

    prepared: list[tuple[dict[str, Path], Image.Image]] = []
    for job in JOBS:
        source_fixed = _load(job["source_fixed"])

        target_live = _load(job["target_runtime"])
        target_approved = _load(job["target_approved"])
        allowed_targets = {_image_digest(target_approved)}
        if job["derived"].is_file():
            allowed_targets.add(_image_digest(_load(job["derived"])))
        if _image_digest(target_live) not in allowed_targets:
            raise ValueError(
                f"guard failed: {job['target_runtime'].name} is not its installed candidate"
            )

        replacement = _mirror_per_cell(source_fixed)
        prepared.append((job, replacement))
        print(
            f"prepared {job['target_runtime'].name} as exact per-cell mirror of "
            f"{job['source_runtime'].name}: {replacement.size}"
        )

    if not args.apply:
        print("audit passed; runtime untouched (use --apply to install)")
        return

    ARCHIVE.mkdir(parents=True, exist_ok=True)
    manifest: list[str] = []
    for job, replacement in prepared:
        archived = ARCHIVE / job["target_runtime"].name
        if not archived.exists():
            shutil.copy2(job["target_runtime"], archived)
        manifest.append(f"{_sha256(archived)}  {archived.name}")

        _atomic_save(replacement, job["derived"])
        _atomic_save(replacement, job["target_runtime"])
        installed = _load(job["target_runtime"])
        if _image_digest(installed) != _image_digest(replacement):
            raise ValueError(f"post-install verification failed: {job['target_runtime']}")
        print(
            f"installed {job['target_runtime'].relative_to(ROOT)} "
            f"{_sha256(job['target_runtime'])}"
        )

    (ARCHIVE / "SHA256SUMS.txt").write_text(
        "\n".join(manifest) + "\n", encoding="ascii"
    )
    print(f"rollback archive: {ARCHIVE.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
