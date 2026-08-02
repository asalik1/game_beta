"""Assemble individually generated walk frames without resynthesizing pixels."""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont


TOOLS = Path(__file__).resolve().parent
if str(TOOLS) not in sys.path:
    sys.path.insert(0, str(TOOLS))

from build_ledgerbound_warlock import _hard_alpha, _remove_green  # noqa: E402


def _font(size: int) -> ImageFont.ImageFont:
    for path in (Path("C:/Windows/Fonts/seguisb.ttf"), Path("C:/Windows/Fonts/arialbd.ttf")):
        if path.exists():
            return ImageFont.truetype(str(path), size)
    return ImageFont.load_default()


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("output", type=Path)
    parser.add_argument("frames", nargs="+", type=Path)
    parser.add_argument("--qa-dir", type=Path, required=True)
    parser.add_argument("--label", required=True)
    parser.add_argument("--fps", type=float, default=9.0)
    parser.add_argument("--target-body", type=int, default=390)
    args = parser.parse_args()

    keyed = [
        _hard_alpha(_remove_green(Image.open(path).convert("RGBA")))
        for path in args.frames
    ]
    boxes = [frame.getbbox() for frame in keyed]
    if any(box is None for box in boxes):
        raise ValueError("empty generated frame")
    cell, baseline = 512, 468
    normalized: list[Image.Image] = []
    for index, (frame, box) in enumerate(zip(keyed, boxes, strict=True)):
        assert box is not None
        figure = frame.crop(box)
        scale = args.target_body / float(figure.height)
        size = (max(1, round(figure.width * scale)), max(1, round(figure.height * scale)))
        figure = _hard_alpha(figure.resize(size, Image.Resampling.LANCZOS))
        if figure.width > cell - 12 or figure.height > baseline - 6:
            raise ValueError(f"frame {index + 1} exceeds staging cell: {figure.size}")
        canvas = Image.new("RGBA", (cell, cell), (0, 0, 0, 0))
        canvas.alpha_composite(figure, ((cell - figure.width) // 2, baseline - figure.height))
        normalized.append(canvas)

    strip = Image.new("RGBA", (cell * len(normalized), cell), (0, 0, 0, 0))
    for index, frame in enumerate(normalized):
        strip.alpha_composite(frame, (index * cell, 0))
    args.output.parent.mkdir(parents=True, exist_ok=True)
    strip.save(args.output)

    args.qa_dir.mkdir(parents=True, exist_ok=True)
    preview, top = 220, 42
    contact = Image.new("RGBA", (preview * len(normalized), preview + top), (25, 28, 34, 255))
    draw = ImageDraw.Draw(contact)
    draw.text((10, 8), args.label, font=_font(18), fill=(255, 224, 126, 255))
    gif_frames: list[Image.Image] = []
    for index, frame in enumerate(normalized):
        shown = frame.resize((preview, preview), Image.Resampling.LANCZOS)
        contact.alpha_composite(shown, (index * preview, top))
        draw.text((index * preview + 6, top + 5), f"f{index + 1}", font=_font(14), fill=(255, 224, 126, 255))
        page = Image.new("RGBA", (preview, preview), (25, 28, 34, 255))
        page.alpha_composite(shown)
        gif_frames.append(page.convert("P", palette=Image.Palette.ADAPTIVE))
    stem = args.output.stem
    contact.save(args.qa_dir / f"{stem}_contact.png")
    gif_frames[0].save(
        args.qa_dir / f"{stem}.gif",
        save_all=True,
        append_images=gif_frames[1:],
        duration=round(1000.0 / args.fps),
        loop=0,
        disposal=2,
    )
    print(f"assembled {len(normalized)} frames -> {args.output}")


if __name__ == "__main__":
    main()
