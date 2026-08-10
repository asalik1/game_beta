"""Assemble the approved reference-edited Assassin Fan of Knives cycle.

Five PixelLab reference edits supply the opening/extension poses.  The closing
half deliberately reuses those authored poses in reverse order, producing a
real ping-pong recovery rather than padding the strip with duplicate endpoint
frames.  Candidate-only: runtime sprites are never modified here.
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path

from PIL import Image

from build_ledgerbound_warlock import _hard_alpha
from build_preservation_walk_candidate import _write_qa


CELL = 277
BASELINE = 255
TARGET_BODY = 180
TIMELINE = (1, 2, 3, 4, 5, 4, 3, 2)


def _normalize(image: Image.Image) -> Image.Image:
    image = _hard_alpha(image)
    box = image.getbbox()
    if box is None:
        raise ValueError("empty reference-edit frame")
    crop = image.crop(box)
    scale = TARGET_BODY / float(crop.height)
    size = (round(crop.width * scale), TARGET_BODY)
    if size[0] > CELL:
        raise ValueError(f"normalized pose is wider than {CELL}px: {size}")
    crop = crop.resize(size, Image.Resampling.NEAREST)
    result = Image.new("RGBA", (CELL, CELL), (0, 0, 0, 0))
    result.alpha_composite(crop, ((CELL - size[0]) // 2, BASELINE - size[1]))
    return result


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("source_dir", type=Path)
    parser.add_argument("output_dir", type=Path)
    parser.add_argument(
        "--idle-strip",
        type=Path,
        required=True,
        help="approved 277px South idle strip; its first cell is the opening pose",
    )
    args = parser.parse_args()

    approved = {
        number: _normalize(
            Image.open(args.source_dir / f"frame_{number:02d}.png").convert("RGBA")
        )
        for number in range(1, 6)
    }
    idle_strip = Image.open(args.idle_strip).convert("RGBA")
    if idle_strip.height != CELL or idle_strip.width < CELL:
        raise ValueError(f"expected a {CELL}px-cell idle strip: {args.idle_strip}")
    approved[1] = _hard_alpha(idle_strip.crop((0, 0, CELL, CELL)))
    frames = [approved[number].copy() for number in TIMELINE]

    args.output_dir.mkdir(parents=True, exist_ok=True)
    for index, frame in enumerate(frames, start=1):
        frame.save(args.output_dir / f"assassin_fan_of_knives_south_f{index:02d}.png")

    stem = "assassin_fan_of_knives_south_reference_edit_v01"
    strip = Image.new("RGBA", (CELL * len(frames), CELL), (0, 0, 0, 0))
    for index, frame in enumerate(frames):
        strip.alpha_composite(frame, (index * CELL, 0))
    strip.save(args.output_dir / f"{stem}_candidate.png")
    _write_qa(
        args.output_dir,
        stem,
        "Assassin Fan of Knives South - PixelLab reference edit",
        frames,
        fps=12.0,
        opposite_contact=5,
    )
    (args.output_dir / "manifest.json").write_text(
        json.dumps(
            {
                "source_dir": str(args.source_dir),
                "opening_idle_source": str(args.idle_strip),
                "timeline": list(TIMELINE),
                "timeline_note": (
                    "poses 4/3/2 are intentional reverse recovery frames; "
                    "no padded duplicate endpoint"
                ),
                "cell": CELL,
                "baseline": BASELINE,
                "target_body": TARGET_BODY,
                "candidate_only": True,
            },
            indent=2,
        ),
        encoding="utf-8",
    )
    print(f"assembled {len(frames)} frames from timeline {TIMELINE}")


if __name__ == "__main__":
    main()
