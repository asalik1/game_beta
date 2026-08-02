"""Reframe approved attack candidates around a stable dense-body X anchor.

The original 277px candidate builder centered each weapon-inclusive silhouette.
As bows and greatswords changed their horizontal extent, the character body
slid within the cell. This pass translates whole authored frames without
resampling into a larger transparent cell. Dense, tall body columns define the
anchor; thin weapon/effect columns are ignored. Pixel art and relative motion
inside each frame remain unchanged.
"""

from __future__ import annotations

import sys
from pathlib import Path

import numpy as np
from PIL import Image


ROOT = Path(__file__).resolve().parents[2]
TOOLS = Path(__file__).resolve().parent
if str(TOOLS) not in sys.path:
    sys.path.insert(0, str(TOOLS))

from build_attack_regen_review import (  # noqa: E402
    ACCEPTED,
    DIRS,
    FRAMES,
    ROOT as PASS_ROOT,
    accepted_path,
    stabilized_path,
)
from build_preservation_walk_candidate import _write_qa  # noqa: E402


SOURCE_CELL = 277
OUTPUT_CELL = 352
TARGET_X = OUTPUT_CELL / 2.0
DENSE_FRACTION = 0.35
MIN_COLUMN_PIXELS = 20
SAFE_MARGIN = 8


def dense_body_anchor(frame: Image.Image) -> float:
    alpha = np.asarray(frame.getchannel("A"), dtype=np.uint8) > 0
    occupancy = alpha.sum(axis=0)
    maximum = int(occupancy.max())
    threshold = max(MIN_COLUMN_PIXELS, maximum * DENSE_FRACTION)
    columns = np.flatnonzero(occupancy >= threshold)
    if columns.size == 0:
        raise ValueError("cannot locate dense body columns")
    weights = occupancy[columns].astype(np.float64)
    return float(np.dot(columns, weights) / weights.sum())


def stabilize_frame(frame: Image.Image) -> tuple[Image.Image, float, float, int]:
    before = dense_body_anchor(frame)
    box = frame.getbbox()
    if box is None:
        raise ValueError("empty frame")
    figure = frame.crop(box)
    shift = round(TARGET_X - before)
    x = box[0] + shift
    y = OUTPUT_CELL - SOURCE_CELL + box[1]
    if x < SAFE_MARGIN or x + figure.width > OUTPUT_CELL - SAFE_MARGIN:
        raise ValueError(
            f"anchored figure would breach {SAFE_MARGIN}px margin: "
            f"x={x}, width={figure.width}"
        )
    if y < SAFE_MARGIN or y + figure.height > OUTPUT_CELL - SAFE_MARGIN:
        raise ValueError(
            f"anchored figure would breach vertical margin: y={y}, "
            f"height={figure.height}"
        )
    output = Image.new("RGBA", (OUTPUT_CELL, OUTPUT_CELL), (0, 0, 0, 0))
    output.alpha_composite(figure, (x, y))
    after = dense_body_anchor(output)
    if abs(after - TARGET_X) > 0.6:
        raise ValueError(f"post-anchor drift {after - TARGET_X:+.2f}px")
    return output, before, after, shift


def main() -> None:
    report = [
        "Dense-body X-anchor stabilization",
        f"source_cell={SOURCE_CELL} output_cell={OUTPUT_CELL} target_x={TARGET_X:g}",
        "",
    ]
    strips = 0
    frames_total = 0
    for character, clips in ACCEPTED.items():
        count = FRAMES[character]
        peak = 6 if count == 9 else 4
        for clip, versions in clips.items():
            for direction in DIRS:
                source = ROOT / accepted_path(character, clip, direction, versions[direction])
                image = Image.open(source).convert("RGBA")
                expected = (SOURCE_CELL * count, SOURCE_CELL)
                if image.size != expected:
                    raise ValueError(f"{source}: expected {expected}, got {image.size}")
                stable_frames: list[Image.Image] = []
                entries: list[str] = []
                for index in range(count):
                    frame = image.crop((index * SOURCE_CELL, 0, (index + 1) * SOURCE_CELL, SOURCE_CELL))
                    stable, before, after, shift = stabilize_frame(frame)
                    stable_frames.append(stable)
                    entries.append(
                        f"f{index + 1}:{before:.1f}->{after:.1f} ({shift:+d})"
                    )
                output = Image.new(
                    "RGBA", (OUTPUT_CELL * count, OUTPUT_CELL), (0, 0, 0, 0)
                )
                for index, frame in enumerate(stable_frames):
                    output.alpha_composite(frame, (index * OUTPUT_CELL, 0))
                target = PASS_ROOT / stabilized_path(
                    character, clip, direction, versions[direction]
                )
                target.parent.mkdir(parents=True, exist_ok=True)
                output.save(target, optimize=True)
                stem = target.name.removesuffix("_candidate.png")
                _write_qa(
                    target.parent,
                    stem,
                    f"{character.title()} {clip.upper()} {direction.upper()} — body-anchor stabilized",
                    stable_frames,
                    22.0,
                    peak,
                )
                report.append(f"{character}/{clip}_{direction}: " + ", ".join(entries))
                strips += 1
                frames_total += count
    report.extend(
        [
            "",
            f"PASS strips={strips} frames={frames_total}",
            "Every post-anchor dense-body center is within 0.6px of target.",
            f"Every figure retains at least {SAFE_MARGIN}px transparent cell margin.",
        ]
    )
    output_report = PASS_ROOT / "stabilized" / "ANCHOR_AUDIT.txt"
    output_report.parent.mkdir(parents=True, exist_ok=True)
    output_report.write_text("\n".join(report) + "\n", encoding="utf-8")
    print(f"stabilized {strips} strips / {frames_total} frames -> {PASS_ROOT / 'stabilized'}")
    print(output_report)


if __name__ == "__main__":
    main()
