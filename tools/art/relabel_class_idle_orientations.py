"""Correct observed horizontal idle facings without altering sprite pixels.

The affected generated idle families were sliced and labeled from the
requested row order, but ImageGen returned the horizontal rows in the opposite
observed facing.  Swap filename labels in pairs; do not flip or resynthesize.
"""

from __future__ import annotations

import argparse
import os
import shutil
from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[2]
SPRITES = ROOT / "game" / "assets" / "sprites"
ARCHIVE = (
    ROOT
    / "art_src"
    / "class_corrective_pass_2026-07-31"
    / "idle_orientation_archive"
    / "pre_observed_facing_relabel_2026-07-31"
)
PAIRS = (("e", "w"), ("ne", "nw"), ("se", "sw"))
DEFAULT_CLASSES = ("archer", "mage", "warlock", "assassin")


def relabel(class_name: str) -> None:
    archive = ARCHIVE / class_name
    archive.mkdir(parents=True, exist_ok=True)
    for first, second in PAIRS:
        first_path = SPRITES / f"{class_name}_anim_{first}.png"
        second_path = SPRITES / f"{class_name}_anim_{second}.png"
        if not first_path.exists() or not second_path.exists():
            raise FileNotFoundError(f"missing idle pair: {first_path}, {second_path}")
        for path in (first_path, second_path):
            destination = archive / path.name
            if not destination.exists():
                shutil.copy2(path, destination)
        first_image = Image.open(first_path).convert("RGBA")
        second_image = Image.open(second_path).convert("RGBA")
        first_temp = first_path.with_name(f"{first_path.stem}.relabel.tmp.png")
        second_temp = second_path.with_name(f"{second_path.stem}.relabel.tmp.png")
        second_image.save(first_temp, optimize=True)
        first_image.save(second_temp, optimize=True)
        os.replace(first_temp, first_path)
        os.replace(second_temp, second_path)
    print(f"relabelled observed idle facings: {class_name}")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("classes", nargs="*", default=DEFAULT_CLASSES)
    args = parser.parse_args()
    for class_name in args.classes:
        relabel(class_name)
    print(f"archived prior labels under {ARCHIVE}")


if __name__ == "__main__":
    main()
