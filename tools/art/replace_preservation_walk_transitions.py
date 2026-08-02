"""Replace isolated transition frames in a preservation walk candidate.

The accepted frames are copied byte-for-byte from an existing normalized strip.
Each ImageGen replacement is independently chroma-keyed, normalized to the same
visible body height, centered in the established 277 px cell, and grounded on
the established baseline before QA artifacts are emitted.
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

from PIL import Image


TOOLS = Path(__file__).resolve().parent
if str(TOOLS) not in sys.path:
    sys.path.insert(0, str(TOOLS))

from build_ledgerbound_warlock import _hard_alpha, _remove_green  # noqa: E402
from build_preservation_walk_candidate import _write_qa  # noqa: E402


CELL = 277
BASELINE = 255


def _source_frame(spec: str) -> tuple[Path, int | None, bool]:
    source_text, separator, selector = spec.rpartition("@")
    if not separator:
        return Path(spec), None, False
    mirror = selector.endswith(":mirror")
    if mirror:
        selector = selector.removesuffix(":mirror")
    try:
        frame_number = int(selector)
    except ValueError:
        # Treat an @ in an ordinary filename as part of the path.
        return Path(spec), None, False
    if frame_number < 1:
        raise ValueError(f"source frame must be one-based: {spec}")
    return Path(source_text), frame_number, mirror


def _normalized_replacement(source_spec: str, body: int) -> tuple[Image.Image, Image.Image]:
    source, source_frame, mirror = _source_frame(source_spec)
    image = Image.open(source).convert("RGBA")
    if source_frame is not None:
        if image.height < 1 or image.width % image.height != 0:
            raise ValueError(f"selected source is not a square-cell strip: {source}")
        count = image.width // image.height
        if source_frame > count:
            raise ValueError(f"source frame {source_frame} exceeds {count}: {source}")
        left = (source_frame - 1) * image.height
        image = image.crop((left, 0, left + image.height, image.height))
    # Normalized candidate strips already carry authored transparency. Running
    # them back through the chroma-key helper would turn their transparent
    # black canvas opaque because that helper is intentionally designed for
    # opaque green ImageGen masters.
    if image.getchannel("A").getextrema()[0] < 255:
        keyed = _hard_alpha(image)
    else:
        keyed = _hard_alpha(_remove_green(image))
    if mirror:
        keyed = keyed.transpose(Image.Transpose.FLIP_LEFT_RIGHT)
    box = keyed.getbbox()
    if box is None:
        raise ValueError(f"empty keyed replacement: {source}")
    figure = keyed.crop(box)
    scale = body / float(figure.height)
    size = (max(1, round(figure.width * scale)), body)
    figure = _hard_alpha(figure.resize(size, Image.Resampling.LANCZOS))
    if figure.width > CELL - 8 or figure.height > BASELINE - 4:
        raise ValueError(f"replacement exceeds staging cell: {source} -> {figure.size}")
    frame = Image.new("RGBA", (CELL, CELL), (0, 0, 0, 0))
    frame.alpha_composite(figure, ((CELL - figure.width) // 2, BASELINE - figure.height))
    return keyed, frame


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("base", type=Path)
    parser.add_argument("output_dir", type=Path)
    parser.add_argument("--stem", required=True)
    parser.add_argument("--label", required=True)
    parser.add_argument("--frames", type=int, default=8)
    parser.add_argument("--body", type=int, default=180)
    parser.add_argument("--fps", type=float, default=9.0)
    parser.add_argument("--opposite-contact", type=int, default=5)
    parser.add_argument(
        "--replace",
        action="append",
        required=True,
        metavar="FRAME=PATH[@SOURCE_FRAME[:mirror]]",
        help=(
            "One-based destination frame and ImageGen source path. A normalized "
            "square-cell strip may select a one-based source frame with @N and "
            "optionally mirror it with @N:mirror."
        ),
    )
    args = parser.parse_args()

    base = Image.open(args.base).convert("RGBA")
    expected = (CELL * args.frames, CELL)
    if base.size != expected:
        raise ValueError(f"base strip is {base.size}, expected {expected}")
    frames = [base.crop((i * CELL, 0, (i + 1) * CELL, CELL)) for i in range(args.frames)]

    args.output_dir.mkdir(parents=True, exist_ok=True)
    replaced: list[int] = []
    for spec in args.replace:
        number_text, separator, source_text = spec.partition("=")
        if not separator:
            raise ValueError(f"invalid replacement spec: {spec}")
        number = int(number_text)
        if number < 1 or number > args.frames:
            raise ValueError(f"replacement frame out of range: {number}")
        keyed, frame = _normalized_replacement(source_text, args.body)
        keyed.save(args.output_dir / f"{args.stem}_f{number}_keyed.png")
        frame.save(args.output_dir / f"{args.stem}_f{number}_normalized.png")
        frames[number - 1] = frame
        replaced.append(number)

    strip = Image.new("RGBA", expected, (0, 0, 0, 0))
    for index, frame in enumerate(frames):
        strip.alpha_composite(frame, (index * CELL, 0))
    strip.save(args.output_dir / f"{args.stem}_candidate.png")
    _write_qa(
        args.output_dir,
        args.stem,
        args.label,
        frames,
        args.fps,
        args.opposite_contact,
    )
    print(
        f"{args.stem}: copied {args.frames - len(replaced)} base frames, "
        f"replaced={sorted(replaced)}, cell={CELL}, body={args.body}, fps={args.fps:g}"
    )


if __name__ == "__main__":
    main()
