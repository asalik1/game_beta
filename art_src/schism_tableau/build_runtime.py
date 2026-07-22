"""Build the production Pilgrims' Schism interaction tableau."""

from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parent
CANVAS = (80, 64)
SUBJECT_LIMIT = (76, 60)
ALPHA_CUTOFF = 128
OUTLINE = (24, 16, 12, 255)


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


def main() -> None:
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
    main()
