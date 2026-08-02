"""Build one unwired ImageGen attack row and its QA proofs.

The generated source may use any flat chroma field.  Border-connected keying
protects intended costume colors, source gutters are validated losslessly,
and one frame-1-derived scale preserves authored recoil/crouch motion.
"""

from __future__ import annotations

import argparse
from pathlib import Path

import numpy as np
from PIL import Image

from build_ledgerbound_warlock import _hard_alpha
from build_preservation_walk_candidate import (
    _crop_frames,
    _infer_columns,
    _normalize,
    _write_cut_overlay,
    _write_qa,
)
from rebuild_preservation_archer_alpha import _connected_key


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("source", type=Path)
    parser.add_argument("output_dir", type=Path)
    parser.add_argument("--stem", required=True)
    parser.add_argument("--label", required=True)
    parser.add_argument("--frames", type=int, required=True)
    parser.add_argument("--fps", type=float, default=22.0)
    parser.add_argument("--body", type=int, default=180)
    parser.add_argument("--peak", type=int, required=True)
    args = parser.parse_args()

    args.output_dir.mkdir(parents=True, exist_ok=True)
    source = Image.open(args.source).convert("RGBA")
    keyed, key, removed = _connected_key(source)
    keyed = _hard_alpha(keyed)
    keyed.save(args.output_dir / f"{args.stem}_keyed.png")

    alpha = np.asarray(keyed.getchannel("A"), dtype=np.uint8) > 0
    detected = _infer_columns(alpha)
    if detected != args.frames:
        raise ValueError(
            f"expected {args.frames} authored figures but detected {detected}"
        )
    frames, edges, gutters = _crop_frames(keyed, detected)
    _write_cut_overlay(
        args.output_dir / f"{args.stem}_cuts.png", keyed, edges, gutters
    )
    normalized = _normalize(frames, args.body)

    strip = Image.new("RGBA", (277 * detected, 277), (0, 0, 0, 0))
    for index, frame in enumerate(normalized):
        strip.alpha_composite(frame, (index * 277, 0))
    strip.save(args.output_dir / f"{args.stem}_candidate.png", optimize=True)
    _write_qa(
        args.output_dir,
        args.stem,
        args.label,
        normalized,
        args.fps,
        args.peak,
    )

    semi_alpha = int(
        ((np.asarray(strip.getchannel("A")) > 0) & (np.asarray(strip.getchannel("A")) < 255)).sum()
    )
    if semi_alpha:
        raise ValueError(f"candidate contains {semi_alpha} semi-transparent pixels")
    if any(strip.getpixel(point)[3] != 0 for point in ((0, 0), (strip.width - 1, 0), (0, 276), (strip.width - 1, 276))):
        raise ValueError("candidate corners are not transparent")
    heights = [frame.getbbox()[3] - frame.getbbox()[1] for frame in normalized]
    print(
        f"{args.stem}: key={key}, removed={removed}, frames={detected}, "
        f"gutters={gutters}, heights={heights}, cell=277, body={args.body}, "
        f"fps={args.fps:g}"
    )


if __name__ == "__main__":
    main()
