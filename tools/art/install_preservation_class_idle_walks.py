#!/usr/bin/env python3
"""Install the approved old-design idle/walk upscales for Archer, Assassin,
and Warlock.

Only the base + eight directional idle/walk PNGs are touched.  The restored
old-design action strips remain byte-for-byte unchanged.  The first run also
archives the current runtime PNGs so this install is reversible.
"""

from __future__ import annotations

import argparse
import shutil
from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[2]
SPRITES = ROOT / "game" / "assets" / "sprites"
SOURCE = ROOT / "art_src" / "class_preservation_upscale_2026-08-01"
BACKUP = SOURCE / "runtime_pre_upscaled_idle_walk_2026-08-01"
DIRS = ("s", "se", "e", "ne", "n", "nw", "w", "sw")
CELL = 277
TARGET_BODY = 180


APPROVED = {
    "archer": {
        "idle": {
            "s": "idle_s/archer_idle_s_v03_closed_mouth_alpha_fixed_candidate.png",
            "se": "idle_se/archer_idle_se_v03_neutral_alpha_fixed_candidate.png",
            "e": "idle_e/archer_idle_e_v01_alpha_fixed_candidate.png",
            "ne": "idle_ne/archer_idle_ne_v01_alpha_fixed_candidate.png",
            "n": "idle_n/archer_idle_n_v01_alpha_fixed_candidate.png",
            "nw": "idle_nw/archer_idle_nw_v01_alpha_fixed_candidate.png",
            "w": "idle_w/archer_idle_w_v01_alpha_fixed_candidate.png",
            "sw": "idle_sw/archer_idle_sw_v02_neutral_alpha_fixed_candidate.png",
        },
        "walk": {
            "s": "walk_s/archer_walk_s_v02_neutral_alpha_fixed_candidate.png",
            "se": "walk_se/archer_walk_se_v02_neutral_alpha_fixed_candidate.png",
            "e": "walk_se/archer_walk_se_v02_neutral_alpha_fixed_candidate.png",
            "ne": "walk_ne/archer_walk_ne_v02_mirrored_nw_candidate.png",
            "n": "walk_n/archer_walk_n_v01_alpha_fixed_candidate.png",
            "nw": "walk_nw/archer_walk_nw_v02_alpha_fixed_candidate.png",
            "w": "walk_sw/archer_walk_sw_v02_neutral_alpha_fixed_candidate.png",
            "sw": "walk_sw/archer_walk_sw_v02_neutral_alpha_fixed_candidate.png",
        },
    },
    "assassin": {
        "idle": {
            "s": "idle_regen_2026-08-02/final/assassin_idle_s_full_regen_candidate.png",
            "se": "idle_regen_2026-08-02/final/assassin_idle_se_full_regen_candidate.png",
            "e": "idle_regen_2026-08-02/final/assassin_idle_e_full_regen_candidate.png",
            "ne": "idle_regen_2026-08-02/final/assassin_idle_ne_full_regen_candidate.png",
            "n": "idle_regen_2026-08-02/final/assassin_idle_n_full_regen_candidate.png",
            "nw": "idle_regen_2026-08-02/final/assassin_idle_nw_full_regen_candidate.png",
            "w": "idle_regen_2026-08-02/final/assassin_idle_w_full_regen_candidate.png",
            "sw": "idle_regen_2026-08-02/final/assassin_idle_sw_full_regen_candidate.png",
        },
        "walk": {
            "s": "walk_s/assassin_walk_s_v04_alternating_contacts_candidate.png",
            "se": "walk_owner_mapping_v01/assassin_walk_e_approved_two_daggers.png",
            "e": "walk_owner_mapping_v01/assassin_walk_e_approved_two_daggers.png",
            "ne": "walk_owner_mapping_v01/assassin_walk_e_approved_two_daggers.png",
            "n": "walk_n/assassin_walk_n_v01_candidate.png",
            "nw": "walk_owner_mapping_v01/assassin_walk_w_mirrored_two_daggers.png",
            "w": "walk_owner_mapping_v01/assassin_walk_w_mirrored_two_daggers.png",
            "sw": "walk_owner_mapping_v01/assassin_walk_w_mirrored_two_daggers.png",
        },
    },
    "warlock": {
        "idle": {
            "s": "idle_s/warlock_idle_s_v01_candidate.png",
            "se": "idle_se/warlock_idle_se_v01_candidate.png",
            "e": "idle_e/warlock_idle_e_v01_candidate.png",
            "ne": "idle_ne/warlock_idle_ne_v02_candidate.png",
            "n": "idle_n/warlock_idle_n_v02_candidate.png",
            "nw": "idle_nw/warlock_idle_nw_v01_candidate.png",
            "w": "idle_w/warlock_idle_w_v01_candidate.png",
            "sw": "idle_sw/warlock_idle_sw_v01_candidate.png",
        },
        "walk": {
            "s": "walk_s/warlock_walk_s_v02_7frame_candidate.png",
            "se": "walk_se/warlock_walk_se_v02_candidate.png",
            "e": "walk_se/warlock_walk_se_v02_candidate.png",
            "ne": "walk_ne/warlock_walk_ne_v02_candidate.png",
            "n": "walk_n/warlock_walk_n_v01_candidate.png",
            "nw": "walk_nw/warlock_walk_nw_v02_candidate.png",
            "w": "walk_sw/warlock_walk_sw_v01_candidate.png",
            "sw": "walk_sw/warlock_walk_sw_v01_candidate.png",
        },
    },
}


def _runtime_name(cls: str, kind: str, direction: str | None) -> str:
    stem = "anim" if kind == "idle" else "walk"
    return f"{cls}_{stem}{'_' + direction if direction else ''}.png"


def _validate(path: Path) -> int:
    if not path.is_file():
        raise FileNotFoundError(path)
    image = Image.open(path).convert("RGBA")
    if image.height != CELL or image.width % CELL != 0:
        raise ValueError(
            f"{path}: expected a horizontal strip of {CELL}px square cells, "
            f"got {image.size}"
        )
    frames = image.width // CELL
    if frames < 1:
        raise ValueError(f"{path}: strip contains no frames")
    alpha = image.crop((0, 0, CELL, CELL)).getchannel("A")
    box = alpha.getbbox()
    if box is None:
        raise ValueError(f"{path}: empty first frame")
    body = box[3] - box[1]
    if not TARGET_BODY - 2 <= body <= TARGET_BODY + 2:
        raise ValueError(f"{path}: first-frame body {body}, expected about {TARGET_BODY}")
    if alpha.getextrema()[0] != 0:
        raise ValueError(f"{path}: first frame has no transparent background")
    return frames


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--class",
        dest="classes",
        action="append",
        choices=tuple(APPROVED),
        help="install only this class (repeatable); default installs all classes",
    )
    args = parser.parse_args()
    selected = set(args.classes or APPROVED)
    jobs: list[tuple[Path, Path]] = []
    for cls, kinds in APPROVED.items():
        if cls not in selected:
            continue
        for kind, directions in kinds.items():
            for direction in DIRS:
                source = SOURCE / cls / directions[direction]
                _validate(source)
                jobs.append((source, SPRITES / _runtime_name(cls, kind, direction)))
            # The non-directional alias is the accepted South strip.
            source = SOURCE / cls / directions["s"]
            jobs.append((source, SPRITES / _runtime_name(cls, kind, None)))

    for _source, destination in jobs:
        relative = destination.relative_to(SPRITES)
        backup = BACKUP / relative
        backup.parent.mkdir(parents=True, exist_ok=True)
        if not backup.exists():
            shutil.copy2(destination, backup)

    for source, destination in jobs:
        shutil.copy2(source, destination)
        print(f"{destination.relative_to(ROOT)} <- {source.relative_to(ROOT)}")

    print(f"Installed {len(jobs)} idle/walk PNGs; rollback archive: {BACKUP.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
