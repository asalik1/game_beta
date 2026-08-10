"""Install the approved PixelLab Assassin Stab and Fan of Knives candidates.

The installer validates all 8-direction, 8-frame, 277px-cell strips; archives
the current desktop and mobile runtime files with SHA-256 hashes; and replaces
each target atomically.  Flat attack/attack2 files remain byte-identical South
aliases.  Without ``--apply`` this is an audit-only dry run.
"""

from __future__ import annotations

import argparse
import hashlib
import os
from pathlib import Path
import shutil

from PIL import Image


ROOT = Path(__file__).resolve().parents[2]
STAB_ROOT = (
    ROOT
    / "art_src"
    / "class_preservation_upscale_2026-08-01"
    / "assassin"
    / "attacks_pixellab_2026-08-02"
    / "stab_upscaled_unique_v01"
)
FAN_ROOT = (
    ROOT
    / "art_src"
    / "class_preservation_upscale_2026-08-01"
    / "assassin"
    / "attacks_pixellab_2026-08-09"
    / "fan_of_knives_8dir_candidate_v01"
)
SPRITE_ROOTS = (
    ROOT / "game" / "assets" / "sprites",
    ROOT / "mobile" / "game" / "assets" / "sprites",
)
ARCHIVE = (
    ROOT
    / "art_src"
    / "class_preservation_upscale_2026-08-01"
    / "assassin"
    / "runtime_pre_pixellab_attacks_2026-08-10"
)

CELL = 277
FRAMES = 8
DIRECTIONS = {
    "s": "south",
    "se": "south-east",
    "e": "east",
    "ne": "north-east",
    "n": "north",
    "nw": "north-west",
    "w": "west",
    "sw": "south-west",
}


def _sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for block in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest().upper()


def _source(family: str, direction: str) -> Path:
    long_direction = DIRECTIONS[direction]
    if family == "attack":
        return (
            STAB_ROOT
            / long_direction
            / f"assassin_stab_{long_direction}_pixellab_resize_v01_candidate.png"
        )
    return FAN_ROOT / f"assassin_fan_of_knives_{long_direction}_candidate.png"


def _target(sprite_root: Path, family: str, direction: str | None) -> Path:
    suffix = f"_{direction}" if direction else ""
    return sprite_root / f"assassin_{family}{suffix}.png"


def _validate_source(path: Path) -> None:
    image = Image.open(path).convert("RGBA")
    expected = (CELL * FRAMES, CELL)
    if image.size != expected:
        raise ValueError(f"{path}: expected {expected}, got {image.size}")
    alpha_values = set(image.getchannel("A").getdata())
    if not alpha_values.issubset({0, 255}):
        raise ValueError(f"{path}: semi-transparent alpha values")
    for index in range(FRAMES):
        frame = image.crop((index * CELL, 0, (index + 1) * CELL, CELL))
        if frame.getbbox() is None:
            raise ValueError(f"{path}: empty frame {index + 1}")


def _archive(paths: list[Path]) -> None:
    for path in paths:
        relative = path.relative_to(ROOT)
        archived = ARCHIVE / relative
        archived.parent.mkdir(parents=True, exist_ok=True)
        if not archived.exists():
            shutil.copy2(path, archived)
    lines = []
    for path in sorted(ARCHIVE.rglob("*.png")):
        lines.append(f"{_sha256(path)}  {path.relative_to(ARCHIVE).as_posix()}")
    (ARCHIVE / "SHA256SUMS.txt").write_text(
        "\n".join(lines) + "\n", encoding="ascii"
    )


def _atomic_copy(source: Path, target: Path) -> None:
    temporary = target.with_name(f"{target.stem}.installing.png")
    shutil.copy2(source, temporary)
    os.replace(temporary, target)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--apply", action="store_true")
    args = parser.parse_args()

    prepared: dict[tuple[str, str], Path] = {}
    runtime_paths: list[Path] = []
    for family in ("attack", "attack2"):
        for direction in DIRECTIONS:
            source = _source(family, direction)
            if not source.exists():
                raise FileNotFoundError(source)
            _validate_source(source)
            prepared[(family, direction)] = source
            for sprite_root in SPRITE_ROOTS:
                target = _target(sprite_root, family, direction)
                if not target.exists():
                    raise FileNotFoundError(target)
                runtime_paths.append(target)
        for sprite_root in SPRITE_ROOTS:
            flat = _target(sprite_root, family, None)
            if not flat.exists():
                raise FileNotFoundError(flat)
            runtime_paths.append(flat)

    print(
        f"validated {len(prepared)} candidates: "
        f"{FRAMES} frames x {CELL}px cells"
    )
    if not args.apply:
        print("audit passed; runtime untouched (use --apply to install)")
        return

    _archive(runtime_paths)
    for sprite_root in SPRITE_ROOTS:
        for family in ("attack", "attack2"):
            for direction in DIRECTIONS:
                _atomic_copy(
                    prepared[(family, direction)],
                    _target(sprite_root, family, direction),
                )
            _atomic_copy(
                prepared[(family, "s")],
                _target(sprite_root, family, None),
            )

    for family in ("attack", "attack2"):
        for direction in DIRECTIONS:
            desktop = _target(SPRITE_ROOTS[0], family, direction)
            mobile = _target(SPRITE_ROOTS[1], family, direction)
            if desktop.read_bytes() != mobile.read_bytes():
                raise ValueError(f"desktop/mobile mismatch: {desktop.name}")
        flat_desktop = _target(SPRITE_ROOTS[0], family, None)
        south_desktop = _target(SPRITE_ROOTS[0], family, "s")
        if flat_desktop.read_bytes() != south_desktop.read_bytes():
            raise ValueError(f"flat {family} is not a South alias")

    print(f"archived previous runtime under {ARCHIVE}")
    for path in sorted(runtime_paths, key=lambda item: str(item)):
        print(f"installed {path.relative_to(ROOT)}  {_sha256(path)}")


if __name__ == "__main__":
    main()
