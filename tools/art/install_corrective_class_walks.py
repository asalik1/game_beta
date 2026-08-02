"""Install the audited lossless-cut V3 class walk corrections.

The corrective candidates were built in compact square cells.  Runtime class
families intentionally share the larger cell geometry established by their
other clips, so this installer pads (never rescales) each corrected frame into
the existing runtime cell.  Existing walk PNGs are archived before replacement.
"""

from __future__ import annotations

import shutil
from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[2]
SPRITES = ROOT / "game" / "assets" / "sprites"
PASS = ROOT / "art_src" / "class_corrective_pass_2026-07-31"
ARCHIVE = PASS / "rejected_runtime_walks" / "pre_lossless_v3_2026-07-31"

CLASSES = ("warrior", "warlock", "mage", "archer", "assassin")
DIRS = ("s", "se", "e", "ne", "n", "nw", "w", "sw")


def _hard_alpha(image: Image.Image) -> Image.Image:
    rgba = image.convert("RGBA")
    alpha = rgba.getchannel("A").point(lambda value: 255 if value >= 128 else 0)
    rgba.putalpha(alpha)
    return rgba


def _pad_strip(source: Path, target_cell: int) -> Image.Image:
    strip = _hard_alpha(Image.open(source))
    source_cell = strip.height
    if strip.width % source_cell:
        raise ValueError(f"{source}: width is not a whole number of square frames")
    if source_cell > target_cell:
        raise ValueError(
            f"{source}: corrective cell {source_cell}px exceeds runtime cell {target_cell}px"
        )

    frame_count = strip.width // source_cell
    output = Image.new("RGBA", (frame_count * target_cell, target_cell), (0, 0, 0, 0))
    x_inset = (target_cell - source_cell) // 2
    y_inset = target_cell - source_cell
    for frame_index in range(frame_count):
        frame = strip.crop(
            (frame_index * source_cell, 0, (frame_index + 1) * source_cell, source_cell)
        )
        if frame.getbbox() is None:
            raise ValueError(f"{source}: frame {frame_index} is empty")
        output.alpha_composite(
            frame,
            (frame_index * target_cell + x_inset, y_inset),
        )
    return output


def _archive_once(path: Path, class_archive: Path) -> None:
    destination = class_archive / path.name
    if not destination.exists():
        shutil.copy2(path, destination)


def install_class(class_name: str) -> None:
    candidate_dir = PASS / f"{class_name}_walk_v3_candidate"
    class_archive = ARCHIVE / class_name
    class_archive.mkdir(parents=True, exist_ok=True)

    runtime_south = SPRITES / f"{class_name}_walk_s.png"
    target_cell = Image.open(runtime_south).height
    installed: dict[str, Image.Image] = {}

    for direction in DIRS:
        runtime_path = SPRITES / f"{class_name}_walk_{direction}.png"
        source_path = candidate_dir / runtime_path.name
        if not runtime_path.exists() or not source_path.exists():
            raise FileNotFoundError(f"missing runtime/source pair: {runtime_path}, {source_path}")
        _archive_once(runtime_path, class_archive)
        installed[direction] = _pad_strip(source_path, target_cell)

    flat_runtime = SPRITES / f"{class_name}_walk.png"
    _archive_once(flat_runtime, class_archive)

    for direction, strip in installed.items():
        strip.save(SPRITES / f"{class_name}_walk_{direction}.png", optimize=True)
    installed["s"].save(flat_runtime, optimize=True)

    frame_count = installed["s"].width // target_cell
    print(
        f"installed {class_name}: {frame_count} frames/direction "
        f"in preserved {target_cell}px runtime cells"
    )


def main() -> None:
    for class_name in CLASSES:
        install_class(class_name)
    print(f"archived prior runtime walks under {ARCHIVE}")


if __name__ == "__main__":
    main()
