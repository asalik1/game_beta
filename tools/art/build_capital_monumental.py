"""Build Crownfall's monumental city-edge architecture.

The generated chroma-key sources live in ``art_src/capital_monumental``.
This builder normalizes them onto stable production canvases and gives every
open flame in the Crown Spire Gate a restrained four-frame integrated
animation.  The City Arcade intentionally has no exposed flame: it is a
non-interactive, non-colliding skyline layer rather than another fake shop.
"""

from __future__ import annotations

import math
from pathlib import Path

from PIL import Image, ImageChops, ImageFilter


ROOT = Path(__file__).resolve().parents[2]
SRC = ROOT / "art_src" / "capital_monumental"
SPRITES = ROOT / "game" / "assets" / "sprites"

# Animated prop strips are inferred as width / height by Art.anim_info, so an
# animated structure frame must remain square even when its painted silhouette
# is wide. Transparent headroom preserves that contract without distorting art.
CROWN_SIZE = (1024, 1024)
ARCADE_SIZE = (1024, 1024)

# Production-canvas coordinates. These rectangles isolate the ten exposed
# braziers/torches while excluding amber windows, brass trim, and red banners.
CROWN_FIRE_RECTS = [
    (22, 850, 92, 926),
    (132, 930, 218, 1022),
    (252, 920, 334, 1022),
    (330, 846, 402, 924),
    (338, 918, 430, 1022),
    (594, 918, 686, 1022),
    (622, 846, 694, 924),
    (690, 920, 772, 1022),
    (806, 930, 892, 1022),
    (932, 850, 1002, 926),
]


def _fit_subject(
    source: Image.Image, size: tuple[int, int], padding: int
) -> Image.Image:
    """Bottom-center an alpha subject without changing its aspect ratio."""
    rgba = source.convert("RGBA")
    bbox = rgba.getchannel("A").getbbox()
    if bbox is None:
        raise ValueError("generated source contains no visible subject")
    crop = rgba.crop(bbox)
    room_w = size[0] - padding * 2
    room_h = size[1] - padding * 2
    scale = min(room_w / crop.width, room_h / crop.height)
    fitted_size = (
        max(1, round(crop.width * scale)),
        max(1, round(crop.height * scale)),
    )
    crop = crop.resize(fitted_size, Image.Resampling.LANCZOS)
    out = Image.new("RGBA", size, (0, 0, 0, 0))
    out.alpha_composite(
        crop,
        ((size[0] - fitted_size[0]) // 2, size[1] - padding - fitted_size[1]),
    )
    return out


def _warm_mask(
    image: Image.Image, rects: list[tuple[int, int, int, int]]
) -> Image.Image:
    """Select saturated orange fire pixels only inside authored sockets."""
    rgba = image.convert("RGBA")
    pixels = rgba.load()
    mask = Image.new("L", rgba.size, 0)
    selected = mask.load()
    for left, top, right, bottom in rects:
        for y in range(max(0, top), min(rgba.height, bottom)):
            for x in range(max(0, left), min(rgba.width, right)):
                red, green, blue, alpha = pixels[x, y]
                if (
                    alpha > 30
                    and red > 145
                    and green > 42
                    and blue < 82
                    and red > green * 1.28
                    and green > blue * 1.08
                ):
                    selected[x, y] = 255
    return mask


def _animated_fire_frame(
    static: Image.Image, fire_mask: Image.Image, phase: int
) -> Image.Image:
    """Pulse and lightly travel the baked flame while architecture stays fixed."""
    frame = static.copy()
    src = static.load()
    dst = frame.load()
    mask = fire_mask.load()
    inner = fire_mask.filter(ImageFilter.MinFilter(3)).load()
    brightness = [0.82, 1.12, 0.94, 1.06][phase]
    travel = [0, 1, -1, 1][phase]
    for y in range(static.height):
        for x in range(static.width):
            if not mask[x, y]:
                continue
            red, green, blue, alpha = src[x, y]
            wave = 0.93 + 0.09 * math.sin(y * 0.28 + phase * math.pi / 2)
            local_brightness = brightness
            if inner[x, y] == 0 and (x * 17 + y * 31 + phase * 13) % 5 == 0:
                local_brightness *= 0.52
            nr = min(255, round(red * local_brightness * wave))
            ng = min(255, round(green * local_brightness * (1.0 + phase * 0.018)))
            nb = min(255, round(blue * (0.86 + phase * 0.04)))
            dst[x, y] = (nr, ng, nb, alpha)
            target_x = x + travel
            if (
                0 <= target_x < static.width
                and (x + y + phase) % 7 == 0
                and mask[target_x, y]
            ):
                tr, tg, tb, ta = dst[target_x, y]
                dst[target_x, y] = (
                    max(tr, nr),
                    max(tg, ng),
                    max(tb, nb),
                    max(ta, alpha),
                )
    return frame


def _write_strip(frames: list[Image.Image], output: Path) -> None:
    frame_w, frame_h = frames[0].size
    strip = Image.new(
        "RGBA", (frame_w * len(frames), frame_h), (0, 0, 0, 0)
    )
    for index, frame in enumerate(frames):
        strip.alpha_composite(frame, (index * frame_w, 0))
    output.parent.mkdir(parents=True, exist_ok=True)
    strip.save(output, optimize=True)


def main() -> None:
    crown = _fit_subject(
        Image.open(SRC / "capital_crown_spire_gate_keyed.png"),
        CROWN_SIZE,
        12,
    )
    arcade = _fit_subject(
        Image.open(SRC / "capital_city_arcade_keyed.png"),
        ARCADE_SIZE,
        8,
    )

    fire_mask = _warm_mask(crown, CROWN_FIRE_RECTS)
    if fire_mask.getbbox() is None:
        raise ValueError("Crown Spire Gate fire sockets selected no pixels")
    crown_frames = [
        _animated_fire_frame(crown, fire_mask, phase) for phase in range(4)
    ]

    SPRITES.mkdir(parents=True, exist_ok=True)
    crown.save(SPRITES / "capital_crown_spire_gate.png", optimize=True)
    arcade.save(SPRITES / "capital_city_arcade.png", optimize=True)
    _write_strip(
        crown_frames, SPRITES / "capital_crown_spire_gate_anim.png"
    )

    changed = [
        sum(
            pixel != (0, 0, 0, 0)
            for pixel in ImageChops.difference(
                frame, crown
            ).get_flattened_data()
        )
        for frame in crown_frames
    ]
    print("capital_crown_spire_gate fire changed pixels:", changed)
    print("Capital monumental architecture built.")


if __name__ == "__main__":
    main()
