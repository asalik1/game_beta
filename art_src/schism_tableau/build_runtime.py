"""Build the production Pilgrims' Schism interaction tableau.

2026-08-25 (fidelity audit): the SHIPPED runtime asset is now the HI-RES build
(`main_hires()`, default): master bbox-cropped and resized to a ~280px alpha
body (NPC path renders the body at 58*1.7 world px, so 280 stores ~2.5x the
render — the >=2x master rule), painterly alpha kept (no 24-colour quantize,
no 1px outline — those were for the legacy 80x64 cell, which `main_legacy()`
still reproduces)."""

import sys
from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parent
CANVAS = (80, 64)
SUBJECT_LIMIT = (76, 60)
ALPHA_CUTOFF = 128
OUTLINE = (24, 16, 12, 255)
HIRES_BODY_H = 280


def main_hires() -> None:
    source = Image.open(ROOT / "pilgrims_schism_master.png").convert("RGBA")
    alpha = source.getchannel("A").point(lambda v: 255 if v >= 24 else 0)
    bbox = alpha.getbbox()
    if bbox is None:
        raise RuntimeError("generated tableau has no visible subject")
    sub = source.crop(bbox)
    scale = HIRES_BODY_H / sub.height
    spr = sub.resize((round(sub.width * scale), round(sub.height * scale)),
                     Image.Resampling.LANCZOS)
    cleaned = spr.getchannel("A").point(lambda v: 0 if v < 24 else v)
    spr.putalpha(cleaned)
    frame = Image.new("RGBA", (spr.width + 4, spr.height + 4), (0, 0, 0, 0))
    frame.alpha_composite(spr, (2, 2))
    output = ROOT / "runtime" / "pilgrims_schism.png"
    output.parent.mkdir(parents=True, exist_ok=True)
    frame.save(output, optimize=True)


def _outline(frame: Image.Image) -> Image.Image:
    output = frame.copy()
    alpha = frame.getchannel("A")
    source = alpha.load()
    target = output.load()
    width, height = frame.size
    for y in range(height):
        for x in range(width):
            if source[x, y] != 0:
                continue
            if any(
                0 <= x + dx < width
                and 0 <= y + dy < height
                and source[x + dx, y + dy] != 0
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))
            ):
                target[x, y] = OUTLINE
    return output


def main_legacy() -> None:
    source = Image.open(ROOT / "pilgrims_schism_master.png").convert("RGBA")
    alpha = source.getchannel("A").point(lambda value: 255 if value >= 24 else 0)
    bbox = alpha.getbbox()
    if bbox is None:
        raise RuntimeError("generated tableau has no visible subject")
    source = source.crop(bbox)

    scale = min(
        SUBJECT_LIMIT[0] / source.width,
        SUBJECT_LIMIT[1] / source.height,
    )
    size = (max(1, round(source.width * scale)), max(1, round(source.height * scale)))
    sprite = source.resize(size, Image.Resampling.LANCZOS)
    alpha = sprite.getchannel("A").point(
        lambda value: 255 if value >= ALPHA_CUTOFF else 0
    )
    sprite.putalpha(alpha)

    rgb = sprite.convert("RGB").quantize(
        colors=24, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE
    ).convert("RGB")
    rgb.putalpha(alpha)

    frame = Image.new("RGBA", CANVAS, (0, 0, 0, 0))
    frame.alpha_composite(
        rgb,
        ((CANVAS[0] - size[0]) // 2, CANVAS[1] - 2 - size[1]),
    )
    frame = _outline(frame)

    output = ROOT / "runtime" / "pilgrims_schism.png"
    output.parent.mkdir(parents=True, exist_ok=True)
    frame.save(output, optimize=True)


if __name__ == "__main__":
    main_legacy() if "--legacy" in sys.argv else main_hires()
