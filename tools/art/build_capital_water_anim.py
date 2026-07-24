"""Build the Crown Plaza fountain's horizontal animation strip.

The built-in image generator supplies a 2x2 storyboard on a removable
chroma-key background.  This builder locks every non-water pixel to the
shipped static fountain, so generated frame-to-frame geometry drift cannot
make the landmark wobble in game.

Usage:
  python tools/art/build_capital_water_anim.py \
    art_src/capital_redesign/capital_crown_fountain_anim_keyed.png \
    game/assets/sprites/capital_crown_fountain.png \
    game/assets/sprites/capital_crown_fountain_anim.png
"""

from __future__ import annotations

import argparse
from pathlib import Path

from PIL import Image, ImageChops, ImageFilter


def _water_mask(image: Image.Image) -> Image.Image:
    """Select the fountain's blue/cyan water without touching warm masonry."""
    rgba = image.convert("RGBA")
    pixels = rgba.load()
    out = Image.new("L", rgba.size, 0)
    selected = out.load()
    for y in range(rgba.height):
        for x in range(rgba.width):
            red, green, blue, alpha = pixels[x, y]
            if (
                alpha > 24
                and blue > 54
                and blue - red > 14
                and blue >= green * 0.92
                and blue >= red * 1.18
            ):
                selected[x, y] = 255
    return out


def _aligned_frame(quadrant: Image.Image, target: Image.Image) -> Image.Image:
    """Bottom-center the generated fountain onto the static asset's bounds."""
    target_bbox = target.getchannel("A").getbbox()
    source_bbox = quadrant.getchannel("A").getbbox()
    if target_bbox is None or source_bbox is None:
        raise ValueError("source and target must both contain visible pixels")
    target_w = target_bbox[2] - target_bbox[0]
    target_h = target_bbox[3] - target_bbox[1]
    cropped = quadrant.crop(source_bbox).resize(
        (target_w, target_h), Image.Resampling.NEAREST
    )
    aligned = Image.new("RGBA", target.size, (0, 0, 0, 0))
    aligned.alpha_composite(cropped, (target_bbox[0], target_bbox[1]))
    return aligned


def build(storyboard_path: Path, static_path: Path, output_path: Path) -> None:
    storyboard = Image.open(storyboard_path).convert("RGBA")
    static = Image.open(static_path).convert("RGBA")
    if storyboard.width != storyboard.height or storyboard.width % 2 != 0:
        raise ValueError("storyboard must be an even-sized square 2x2 grid")

    half = storyboard.width // 2
    boxes = [
        (0, 0, half, half),
        (half, 0, storyboard.width, half),
        (0, half, half, storyboard.height),
        (half, half, storyboard.width, storyboard.height),
    ]
    static_water = _water_mask(static)
    frames: list[Image.Image] = []
    changed_counts: list[int] = []
    for box in boxes:
        generated = _aligned_frame(storyboard.crop(box), static)
        # Cover the union of old and new water plus a two-pixel seam.  Everything
        # outside this mask is copied byte-for-byte from the static landmark.
        water = ImageChops.lighter(static_water, _water_mask(generated))
        water = water.filter(ImageFilter.MaxFilter(5))
        frame = Image.composite(generated, static, water)
        frame.putalpha(static.getchannel("A"))
        diff = ImageChops.difference(frame, static).convert("RGBA")
        changed_counts.append(
            sum(1 for px in diff.get_flattened_data() if px != (0, 0, 0, 0))
        )
        frames.append(frame)

    strip = Image.new("RGBA", (static.width * len(frames), static.height))
    for index, frame in enumerate(frames):
        strip.alpha_composite(frame, (index * static.width, 0))
    output_path.parent.mkdir(parents=True, exist_ok=True)
    strip.save(output_path, optimize=True)
    print(
        f"Wrote {output_path} ({strip.width}x{strip.height}); "
        f"changed pixels per frame: {changed_counts}"
    )


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("storyboard", type=Path)
    parser.add_argument("static", type=Path)
    parser.add_argument("output", type=Path)
    args = parser.parse_args()
    build(args.storyboard, args.static, args.output)


if __name__ == "__main__":
    main()
