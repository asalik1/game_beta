"""Restore archived old-design Warrior attack/attack2 strips at 180px body.

The archived poses and timing are preserved exactly. Each direction uses one
frame-1-derived scale for all seven frames, hard alpha, and a 288px square cell
large enough to retain every authored sword arc. Current redesign attack files
are archived before the guarded install.
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

from build_ledgerbound_warlock import _hard_alpha  # noqa: E402
from build_preservation_walk_candidate import _write_qa  # noqa: E402


BACKUP = ROOT / "backup" / "warrior_base_pre_emberbound_heir_2026-07-31"
WARRIOR = (
    ROOT / "art_src" / "class_preservation_upscale_2026-08-01" / "warrior"
)
OUTPUT = WARRIOR / "attacks_old_normalized"
SPRITES = ROOT / "game" / "assets" / "sprites"
ARCHIVE = WARRIOR / "runtime_pre_attack_restore_2026-08-01"

DIRECTIONS = ("s", "se", "e", "ne", "n", "nw", "w", "sw")
FAMILIES = ("attack", "attack2")
SOURCE_CELL = 182
RUNTIME_CELL = 288
FRAME_COUNT = 7
TARGET_BODY = 180
BASELINE = 283


def _sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for block in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest().upper()


def _source(family: str, direction: str) -> Path:
    return BACKUP / f"warrior_{family}_{direction}.png"


def _runtime(family: str, direction: str) -> Path:
    return SPRITES / f"warrior_{family}_{direction}.png"


def _normalize(source: Path) -> list[Image.Image]:
    strip = Image.open(source).convert("RGBA")
    expected = (FRAME_COUNT * SOURCE_CELL, SOURCE_CELL)
    if strip.size != expected:
        raise ValueError(f"{source}: expected {expected}, got {strip.size}")
    source_frames = [
        strip.crop((i * SOURCE_CELL, 0, (i + 1) * SOURCE_CELL, SOURCE_CELL))
        for i in range(FRAME_COUNT)
    ]
    first_box = source_frames[0].getbbox()
    if first_box is None:
        raise ValueError(f"{source}: empty first frame")
    scale = TARGET_BODY / float(first_box[3] - first_box[1])

    frames: list[Image.Image] = []
    for index, frame in enumerate(source_frames):
        box = frame.getbbox()
        if box is None:
            raise ValueError(f"{source}: empty frame {index + 1}")
        figure = frame.crop(box)
        size = (
            max(1, round(figure.width * scale)),
            max(1, round(figure.height * scale)),
        )
        figure = _hard_alpha(figure.resize(size, Image.Resampling.LANCZOS))
        if figure.width > RUNTIME_CELL - 8 or figure.height > BASELINE - 4:
            raise ValueError(
                f"{source}: frame {index + 1} normalized to {figure.size}, "
                f"exceeding {RUNTIME_CELL}px cell"
            )
        canvas = Image.new("RGBA", (RUNTIME_CELL, RUNTIME_CELL), (0, 0, 0, 0))
        canvas.alpha_composite(
            figure,
            ((RUNTIME_CELL - figure.width) // 2, BASELINE - figure.height),
        )
        frames.append(canvas)
    return frames


def _strip(frames: list[Image.Image]) -> Image.Image:
    output = Image.new(
        "RGBA", (RUNTIME_CELL * len(frames), RUNTIME_CELL), (0, 0, 0, 0)
    )
    for index, frame in enumerate(frames):
        output.alpha_composite(frame, (index * RUNTIME_CELL, 0))
    return output


def _archive_runtime(paths: list[Path]) -> None:
    ARCHIVE.mkdir(parents=True, exist_ok=True)
    for path in paths:
        if not path.exists():
            raise FileNotFoundError(path)
        archived = ARCHIVE / path.name
        if not archived.exists():
            shutil.copy2(path, archived)
    lines = [
        f"{_sha256(path)}  {path.name}"
        for path in sorted(ARCHIVE.glob("warrior_attack*.png"), key=lambda p: p.name)
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

    prepared: dict[tuple[str, str], Image.Image] = {}
    runtime_paths: list[Path] = []
    for family in FAMILIES:
        family_out = OUTPUT / family
        family_out.mkdir(parents=True, exist_ok=True)
        for direction in DIRECTIONS:
            source = _source(family, direction)
            target = _runtime(family, direction)
            if not source.exists() or not target.exists():
                raise FileNotFoundError(source if not source.exists() else target)
            frames = _normalize(source)
            strip = _strip(frames)
            prepared[(family, direction)] = strip
            runtime_paths.append(target)
            stem = f"warrior_{family}_{direction}_old_normalized"
            strip.save(family_out / f"{stem}_candidate.png")
            _write_qa(
                family_out,
                stem,
                f"Warrior archived {family} {direction.upper()} normalized (180px)",
                frames,
                22.0,
                4,
            )
            print(f"{family} {direction}: {source.name} -> {strip.size}")

    # Flat files are South aliases in the runtime contract.
    flat_paths = [SPRITES / "warrior_attack.png", SPRITES / "warrior_attack2.png"]
    runtime_paths.extend(flat_paths)
    if any(not path.exists() for path in flat_paths):
        raise FileNotFoundError(next(path for path in flat_paths if not path.exists()))

    if not args.apply:
        print("audit and QA build passed; runtime untouched (use --apply to install)")
        return

    _archive_runtime(runtime_paths)
    for (family, direction), strip in prepared.items():
        _atomic_save(strip, _runtime(family, direction))
    _atomic_save(prepared[("attack", "s")], flat_paths[0])
    _atomic_save(prepared[("attack2", "s")], flat_paths[1])
    print(f"archived redesign attacks under {ARCHIVE}")
    for path in sorted(runtime_paths, key=lambda p: p.name):
        print(f"installed {path.name}: {path.stat().st_size} bytes {_sha256(path)}")


if __name__ == "__main__":
    main()
