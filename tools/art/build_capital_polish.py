"""Build Crownfall's polished furniture and full-structure fire animations.

Generated source sheets live in ``art_src/capital_polish``.  This script:

* turns the generated 2x2 Hearthworks storyboard into one stable four-frame
  horizontal strip (only the fire pixels vary);
* normalizes the generated bench and vault chest onto transparent 512px
  production canvases; and
* animates the baked fire regions of Crownfall's existing large structures,
  allowing the old nested flame decals to be removed.

The architecture in every existing structure remains byte-stable.  Only warm
pixels inside authored fire sockets pulse and reshape at their edges.
"""

from __future__ import annotations

import math
from pathlib import Path

from PIL import Image, ImageChops, ImageFilter


ROOT = Path(__file__).resolve().parents[2]
SRC = ROOT / "art_src" / "capital_polish"
SPRITES = ROOT / "game" / "assets" / "sprites"
CANVAS = 512

# Fire sockets in source-pixel coordinates.  These deliberately exclude brass,
# red banners, windows, and other warm architectural details.
FIRE_RECTS: dict[str, list[tuple[int, int, int, int]]] = {
    "capital_emberward_gate": [(50, 375, 115, 455), (370, 375, 435, 455)],
    "capital_portal_crucible": [(60, 380, 110, 450), (400, 380, 450, 450)],
    "capital_ashfire_forge": [(275, 282, 342, 346)],
    "capital_ashen_tankard": [(184, 334, 236, 382)],
    "capital_wildfang_fangmoot": [(232, 278, 282, 328)],
    "capital_accord_longhouse": [(232, 342, 284, 392)],
    "capital_sable_hall": [(116, 366, 176, 444), (336, 366, 396, 444)],
    "capital_watchtower": [(326, 54, 400, 132)],
    "capital_proving_gate": [
        (65, 375, 118, 452),
        (396, 375, 450, 452),
        (5, 334, 50, 390),
        (468, 334, 510, 390),
    ],
}


def _fit_subject(image: Image.Image, pad: int = 18) -> Image.Image:
    """Fit an alpha subject into a square production canvas, bottom-centred."""
    rgba = image.convert("RGBA")
    bbox = rgba.getchannel("A").getbbox()
    if bbox is None:
        raise ValueError("generated source contains no visible subject")
    crop = rgba.crop(bbox)
    room = CANVAS - pad * 2
    scale = min(room / crop.width, room / crop.height)
    size = (
        max(1, round(crop.width * scale)),
        max(1, round(crop.height * scale)),
    )
    crop = crop.resize(size, Image.Resampling.LANCZOS)
    out = Image.new("RGBA", (CANVAS, CANVAS), (0, 0, 0, 0))
    out.alpha_composite(crop, ((CANVAS - size[0]) // 2, CANVAS - pad - size[1]))
    return out


def _warm_mask(
    image: Image.Image, rects: list[tuple[int, int, int, int]]
) -> Image.Image:
    """Select orange/yellow fire pixels only inside known fire sockets."""
    rgba = image.convert("RGBA")
    px = rgba.load()
    mask = Image.new("L", rgba.size, 0)
    selected = mask.load()
    for left, top, right, bottom in rects:
        for y in range(max(0, top), min(rgba.height, bottom)):
            for x in range(max(0, left), min(rgba.width, right)):
                red, green, blue, alpha = px[x, y]
                if (
                    alpha > 24
                    and red > 118
                    and green > 38
                    and blue < 100
                    and red > green * 1.12
                    and green > blue * 1.04
                ):
                    selected[x, y] = 255
    return mask


def _write_strip(frames: list[Image.Image], output: Path) -> None:
    strip = Image.new("RGBA", (CANVAS * len(frames), CANVAS), (0, 0, 0, 0))
    for index, frame in enumerate(frames):
        strip.alpha_composite(frame, (index * CANVAS, 0))
    output.parent.mkdir(parents=True, exist_ok=True)
    strip.save(output, optimize=True)


def _build_generated_hearth() -> None:
    storyboard = Image.open(
        SRC / "capital_great_hearth_anim_keyed.png"
    ).convert("RGBA")
    if storyboard.width != storyboard.height or storyboard.width % 2:
        raise ValueError("Hearthworks storyboard must be an even square 2x2 sheet")
    half = storyboard.width // 2
    quadrants = [
        storyboard.crop((0, 0, half, half)),
        storyboard.crop((half, 0, storyboard.width, half)),
        storyboard.crop((0, half, half, storyboard.height)),
        storyboard.crop((half, half, storyboard.width, storyboard.height)),
    ]
    aligned = [_fit_subject(frame, 8) for frame in quadrants]
    base = aligned[0]
    # The generated hearth fills the canvas; only its central lower firebox may
    # vary.  Lock every architectural pixel to frame zero.
    firebox = [(118, 248, 394, 465)]
    base_fire = _warm_mask(base, firebox)
    frames: list[Image.Image] = []
    for candidate in aligned:
        fire = ImageChops.lighter(base_fire, _warm_mask(candidate, firebox))
        fire = fire.filter(ImageFilter.MaxFilter(5))
        frame = Image.composite(candidate, base, fire)
        frame.putalpha(base.getchannel("A"))
        frames.append(frame)
    base.save(SPRITES / "capital_great_hearth.png", optimize=True)
    _write_strip(frames, SPRITES / "capital_great_hearth_anim.png")


def _build_generated_props() -> None:
    for name in [
        "capital_city_bench",
        "capital_vault_chest",
        "capital_city_directory",
        "capital_alembic_station",
    ]:
        keyed = Image.open(SRC / f"{name}_keyed.png").convert("RGBA")
        _fit_subject(keyed).save(SPRITES / f"{name}.png", optimize=True)


def _animated_fire_frame(
    static: Image.Image,
    fire_mask: Image.Image,
    phase: int,
) -> Image.Image:
    """Pulse and edge-warp an integrated flame without adding a second sprite."""
    frame = static.copy()
    src = static.load()
    dst = frame.load()
    mask = fire_mask.load()
    inner = fire_mask.filter(ImageFilter.MinFilter(3)).load()
    brightness = [0.84, 1.12, 0.96, 1.06][phase]
    horizontal = [0, 1, -1, 1][phase]
    for y in range(static.height):
        for x in range(static.width):
            if not mask[x, y]:
                continue
            red, green, blue, alpha = src[x, y]
            wave = 0.92 + 0.10 * math.sin(y * 0.31 + phase * math.pi / 2)
            # Edge pixels intermittently dim, changing the silhouette without
            # punching transparent holes through the hearth behind it.
            edge = inner[x, y] == 0
            if edge and ((x * 17 + y * 31 + phase * 13) % 5 == 0):
                brightness_here = brightness * 0.48
            else:
                brightness_here = brightness
            nr = min(255, round(red * brightness_here * wave))
            ng = min(255, round(green * brightness_here * (1.02 + phase * 0.015)))
            nb = min(255, round(blue * (0.88 + phase * 0.035)))
            dst[x, y] = (nr, ng, nb, alpha)
            # A restrained one-pixel travelling highlight makes the large fire
            # shape move rather than merely pulse in place.
            tx = x + horizontal
            if 0 <= tx < static.width and (x + y + phase) % 7 == 0:
                tr, tg, tb, ta = dst[tx, y]
                dst[tx, y] = (
                    max(tr, nr),
                    max(tg, ng),
                    max(tb, nb),
                    max(ta, alpha),
                )
    return frame


def _build_existing_fire_structures() -> None:
    for name, rects in FIRE_RECTS.items():
        static = Image.open(SPRITES / f"{name}.png").convert("RGBA")
        if static.size != (CANVAS, CANVAS):
            raise ValueError(f"{name} must remain a 512x512 capital structure")
        mask = _warm_mask(static, rects)
        if mask.getbbox() is None:
            raise ValueError(f"{name} fire socket selected no pixels")
        frames = [_animated_fire_frame(static, mask, phase) for phase in range(4)]
        _write_strip(frames, SPRITES / f"{name}_anim.png")
        changed = [
            sum(
                1
                for pixel in ImageChops.difference(frame, static).get_flattened_data()
                if pixel != (0, 0, 0, 0)
            )
            for frame in frames
        ]
        print(f"{name}: integrated fire changed pixels {changed}")


def main() -> None:
    _build_generated_hearth()
    _build_generated_props()
    _build_existing_fire_structures()
    print("Capital polish assets built.")


if __name__ == "__main__":
    main()
