"""Build Assassin walk candidates with original gait and corrected weapons.

The first preservation walk candidates retained the acceptable authored leg
motion but hid the far-hand dagger in side and quarter views.  The later
two-dagger rows fixed the equipment while collapsing the gait.  This builder
combines only those complementary strengths: corrected upper body and weapons,
original lower body and feet.

No interpolation or resynthesis is performed.  The bottom motion-guard region
is asserted byte-for-byte identical to the original gait in every frame.
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

from PIL import Image


TOOLS = Path(__file__).resolve().parent
if str(TOOLS) not in sys.path:
    sys.path.insert(0, str(TOOLS))

from build_preservation_walk_candidate import _write_qa  # noqa: E402


ROOT = Path(__file__).resolve().parents[2]
ASSASSIN = ROOT / "art_src" / "class_preservation_upscale_2026-08-01" / "assassin"
CELL = 277
FRAMES = 6

# direction: (motion authority, two-dagger authority, weapon side, output stem)
JOBS = {
    "se": (
        "assassin_walk_se_v01_candidate.png",
        "assassin_walk_se_v02_two_daggers_candidate.png",
        "left",
        "assassin_walk_se_v07_motion_preserved",
    ),
    "e": (
        "assassin_walk_e_v01_candidate.png",
        "assassin_walk_e_v02_two_daggers_candidate.png",
        "left",
        "assassin_walk_e_v06_motion_preserved",
    ),
    "ne": (
        "assassin_walk_ne_v02_candidate.png",
        "assassin_walk_ne_v03_two_daggers_candidate.png",
        "left",
        "assassin_walk_ne_v07_motion_preserved",
    ),
    "nw": (
        "assassin_walk_nw_v01_candidate.png",
        "assassin_walk_nw_v02_two_daggers_candidate.png",
        "right",
        "assassin_walk_nw_v06_motion_preserved",
    ),
    "w": (
        "assassin_walk_w_v01_candidate.png",
        "assassin_walk_w_v02_two_daggers_candidate.png",
        "right",
        "assassin_walk_w_v06_motion_preserved",
    ),
    "sw": (
        "assassin_walk_sw_v01_candidate.png",
        "assassin_walk_sw_v02_two_daggers_candidate.png",
        "right",
        "assassin_walk_sw_v07_motion_preserved",
    ),
}


def _frames(path: Path) -> list[Image.Image]:
    strip = Image.open(path).convert("RGBA")
    expected = (CELL * FRAMES, CELL)
    if strip.size != expected:
        raise ValueError(f"{path}: expected {expected}, got {strip.size}")
    return [
        strip.crop((index * CELL, 0, (index + 1) * CELL, CELL))
        for index in range(FRAMES)
    ]


def _compose(motion: Image.Image, equipment: Image.Image, side: str) -> Image.Image:
    motion_box = motion.getbbox()
    equipment_box = equipment.getbbox()
    if motion_box is None or equipment_box is None:
        raise ValueError("empty Assassin walk frame")

    top = min(motion_box[1], equipment_box[1])
    bottom = max(motion_box[3], equipment_box[3])
    body_height = bottom - top
    # Cut beneath the sash, above the independently animated thighs.
    seam = top + round(body_height * 0.48)
    # No corrected pixels may enter this region: original knees, boots, and
    # ground contact remain exact motion authority.
    motion_guard = top + round(body_height * 0.68)
    center = CELL // 2
    weapon_inner = 18

    result = motion.copy()
    result_px = result.load()
    equipment_px = equipment.load()

    for y in range(CELL):
        for x in range(CELL):
            if y < seam:
                # Clear the old upper figure first so small silhouette changes
                # cannot leave doubled shoulders, arms, or hood edges.
                result_px[x, y] = (0, 0, 0, 0)

    result.alpha_composite(equipment.crop((0, 0, CELL, seam)), (0, 0))

    # Carry the corrected far-hand dagger below the sash while keeping all
    # central lower-body motion from the original frame.  The side band ends
    # before the guarded knee/foot region.
    if side == "left":
        weapon_range = range(0, center - weapon_inner)
    elif side == "right":
        weapon_range = range(center + weapon_inner, CELL)
    else:
        raise ValueError(f"invalid weapon side: {side}")
    for y in range(seam, motion_guard):
        for x in weapon_range:
            pixel = equipment_px[x, y]
            if pixel[3] > 0:
                result_px[x, y] = pixel

    # The gait contract is mechanical, not subjective.
    if (
        result.crop((0, motion_guard, CELL, CELL)).tobytes()
        != motion.crop((0, motion_guard, CELL, CELL)).tobytes()
    ):
        raise AssertionError("lower-body motion guard changed")
    return result


def build(direction: str) -> Path:
    motion_name, equipment_name, side, stem = JOBS[direction]
    folder = ASSASSIN / f"walk_{direction}"
    motion_frames = _frames(folder / motion_name)
    equipment_frames = _frames(folder / equipment_name)
    frames = [
        _compose(motion, equipment, side)
        for motion, equipment in zip(motion_frames, equipment_frames, strict=True)
    ]

    strip = Image.new("RGBA", (CELL * FRAMES, CELL), (0, 0, 0, 0))
    for index, frame in enumerate(frames):
        strip.alpha_composite(frame, (index * CELL, 0))
    candidate = folder / f"{stem}_candidate.png"
    strip.save(candidate)
    _write_qa(
        folder,
        stem,
        f"Assassin {direction.upper()} — original gait + two-dagger upper body",
        frames,
        9.0,
        4,
    )
    print(f"{direction}: original gait preserved below guard -> {candidate}")
    return candidate


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "directions",
        nargs="*",
        choices=tuple(JOBS),
        default=tuple(JOBS),
    )
    args = parser.parse_args()
    for direction in args.directions:
        build(direction)


if __name__ == "__main__":
    main()
