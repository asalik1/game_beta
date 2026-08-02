"""Install the approved Archer/Warlock/Warrior ImageGen attack strips.

Dry-run is the default. ``--apply`` archives the current desktop and mobile
runtime files, then atomically installs the explicit accepted manifest used by
``build_attack_regen_review.py``. Flat clip aliases are exact South copies.
"""

from __future__ import annotations

import argparse
import hashlib
import os
import shutil
import sys
from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[2]
TOOLS = Path(__file__).resolve().parent
if str(TOOLS) not in sys.path:
    sys.path.insert(0, str(TOOLS))

from build_attack_regen_review import (  # noqa: E402
    ACCEPTED,
    CELL,
    DIRS,
    FRAMES,
    audit,
    stabilized_path,
)


DESTINATIONS = {
    "game": ROOT / "game" / "assets" / "sprites",
    "mobile": ROOT / "mobile" / "game" / "assets" / "sprites",
}
ARCHIVE = (
    ROOT
    / "art_src"
    / "class_attack_regen_imagegen_2026-08-02"
    / "runtime_pre_install_2026-08-02"
)


def digest(path: Path) -> str:
    value = hashlib.sha256()
    with path.open("rb") as handle:
        for block in iter(lambda: handle.read(1024 * 1024), b""):
            value.update(block)
    return value.hexdigest().upper()


def source(character: str, clip: str, direction: str) -> Path:
    version = ACCEPTED[character][clip][direction]
    return ROOT / "art_src" / "class_attack_regen_imagegen_2026-08-02" / stabilized_path(
        character, clip, direction, version
    )


def runtime_name(character: str, clip: str, direction: str | None) -> str:
    suffix = f"_{direction}" if direction else ""
    return f"{character}_{clip}{suffix}.png"


def validate_source(path: Path, frames: int) -> None:
    audit(path, frames)
    image = Image.open(path)
    if image.height != 352 or image.size != (frames * image.height, image.height):
        raise ValueError(f"{path}: invalid geometry {image.size}")


def archive_runtime(targets: list[tuple[str, Path]]) -> None:
    for scope, target in targets:
        archived = ARCHIVE / scope / target.name
        archived.parent.mkdir(parents=True, exist_ok=True)
        if not archived.exists():
            shutil.copy2(target, archived)
    lines: list[str] = []
    for scope in DESTINATIONS:
        for path in sorted((ARCHIVE / scope).glob("*.png"), key=lambda item: item.name):
            lines.append(f"{digest(path)}  {scope}/{path.name}")
    manifest = ARCHIVE / "SHA256SUMS.txt"
    manifest.write_text("\n".join(lines) + "\n", encoding="ascii")


def atomic_copy(src: Path, target: Path) -> None:
    temporary = target.with_name(f"{target.stem}.installing.png")
    shutil.copy2(src, temporary)
    os.replace(temporary, target)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--apply", action="store_true")
    args = parser.parse_args()

    installs: list[tuple[Path, Path]] = []
    existing: list[tuple[str, Path]] = []
    for character, clips in ACCEPTED.items():
        frames = FRAMES[character]
        for clip in clips:
            for direction in DIRS:
                src = source(character, clip, direction)
                validate_source(src, frames)
                for scope, destination in DESTINATIONS.items():
                    target = destination / runtime_name(character, clip, direction)
                    if not target.exists():
                        raise FileNotFoundError(target)
                    installs.append((src, target))
                    existing.append((scope, target))
            south = source(character, clip, "s")
            for scope, destination in DESTINATIONS.items():
                flat = destination / runtime_name(character, clip, None)
                if not flat.exists():
                    raise FileNotFoundError(flat)
                installs.append((south, flat))
                existing.append((scope, flat))

    print(
        f"validated 48 directional sources and {len(installs)} runtime writes "
        f"across desktop/mobile"
    )
    if not args.apply:
        print("dry-run passed; runtime untouched (use --apply)")
        return

    archive_runtime(existing)
    for src, target in installs:
        atomic_copy(src, target)

    for src, target in installs:
        if digest(src) != digest(target):
            raise ValueError(f"post-install hash mismatch: {src} -> {target}")

    for character, clips in ACCEPTED.items():
        for clip in clips:
            for scope, destination in DESTINATIONS.items():
                flat = destination / runtime_name(character, clip, None)
                south = destination / runtime_name(character, clip, "s")
                if digest(flat) != digest(south):
                    raise ValueError(f"{scope}: flat/South mismatch for {character} {clip}")
    print(f"archived previous runtime files under {ARCHIVE}")
    print(
        f"installed and hash-verified {len(installs)} approved runtime files "
        "across game and mobile/game"
    )


if __name__ == "__main__":
    main()
