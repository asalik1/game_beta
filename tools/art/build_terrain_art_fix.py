"""Build the 2026-07-30 tiered terrain-art replacement set.

The archived masters are built-in image-generation edits on removable magenta
backgrounds. This script trims key residue, keeps animated objects registered
to one shared crop, reduces them to a restrained painterly-pixel palette, and
installs matching desktop/mobile PNGs.
"""

from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw


ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "art_src" / "terrain_art_fix_2026-07-30"
DESKTOP = ROOT / "game" / "assets" / "sprites"
MOBILE = ROOT / "mobile" / "game" / "assets" / "sprites"
QA_DIR = ROOT / "tmp" / "terrain_art_fix_qa"


@dataclass(frozen=True)
class Spec:
    size: tuple[int, int]
    animated: bool = False


SPECS: dict[str, Spec] = {
    # Tier 1
    "cottage_a": Spec((384, 300)),
    "cottage_a2": Spec((384, 320)),
    "cottage_b": Spec((384, 260)),
    "stall": Spec((320, 252)),
    "rock3": Spec((256, 320)),
    "crypt": Spec((256, 300)),
    "signpost": Spec((112, 192)),
    # Tier 2
    "keep_arch": Spec((320, 240)),
    "camp_workbench": Spec((288, 240)),
    "cook_grill": Spec((256, 224), animated=True),
    "camp_bonfire": Spec((192, 128), animated=True),
    "pillar": Spec((160, 256)),
    # Tier 3
    "banner_blue": Spec((96, 192), animated=True),
    "banner_green": Spec((96, 192), animated=True),
    "banner_red": Spec((96, 192), animated=True),
    "hideout_poster": Spec((96, 144)),
    "hideout_table": Spec((256, 224)),
    "amphora": Spec((112, 192)),
    "station_alchemy_t3": Spec((320, 256), animated=True),
    "station_anvil_t3": Spec((320, 288)),
}


def _clean_key(image: Image.Image) -> Image.Image:
    rgba = np.asarray(image.convert("RGBA")).copy()
    rgb = rgba[:, :, :3].astype(np.int16)
    red, green, blue = rgb[:, :, 0], rgb[:, :, 1], rgb[:, :, 2]
    # The official chroma helper supplies the soft edge. This second pass
    # removes broad imagegen magenta variation and any isolated key remnants.
    magenta = (
        (red > 140)
        & (blue > 140)
        & (green < 165)
        & ((((red + blue) // 2) - green) > 65)
    )
    alpha = rgba[:, :, 3]
    alpha[magenta] = 0
    alpha[:] = np.where(alpha >= 64, 255, 0).astype(np.uint8)
    rgba[:, :, 3] = alpha
    rgba[alpha == 0, :3] = 0
    return Image.fromarray(rgba, "RGBA")


def _content_box(image: Image.Image) -> tuple[int, int, int, int]:
    alpha = np.asarray(image.getchannel("A"))
    mask = alpha > 0
    row_min = max(2, round(image.width * 0.002))
    col_min = max(2, round(image.height * 0.002))
    xs = np.flatnonzero(mask.sum(axis=0) >= col_min)
    ys = np.flatnonzero(mask.sum(axis=1) >= row_min)
    if not xs.size or not ys.size:
        raise RuntimeError("No opaque subject pixels after chroma cleanup")
    return int(xs[0]), int(ys[0]), int(xs[-1] + 1), int(ys[-1] + 1)


def _fit(crop: Image.Image, size: tuple[int, int]) -> Image.Image:
    target_w, target_h = size
    margin = max(3, round(min(size) * 0.035))
    scale = min(
        (target_w - margin * 2) / crop.width,
        (target_h - margin * 2) / crop.height,
    )
    fitted = crop.resize(
        (max(1, round(crop.width * scale)), max(1, round(crop.height * scale))),
        Image.Resampling.LANCZOS,
    )
    canvas = Image.new("RGBA", size, (0, 0, 0, 0))
    x = (target_w - fitted.width) // 2
    y = target_h - margin - fitted.height
    canvas.alpha_composite(fitted, (x, y))
    return canvas


def _quantize(image: Image.Image, colors: int = 96) -> Image.Image:
    alpha = image.getchannel("A")
    rgb = Image.new("RGB", image.size, (0, 0, 0))
    rgb.paste(image.convert("RGB"), mask=alpha)
    paletted = rgb.quantize(
        colors=colors,
        method=Image.Quantize.MEDIANCUT,
        dither=Image.Dither.NONE,
    ).convert("RGBA")
    paletted.putalpha(alpha.point(lambda value: 255 if value >= 96 else 0))
    data = np.asarray(paletted).copy()
    data[data[:, :, 3] == 0, :3] = 0
    return Image.fromarray(data, "RGBA")


def _static_master(name: str, spec: Spec) -> Image.Image:
    source = _clean_key(Image.open(SOURCE / f"{name}.png"))
    crop = source.crop(_content_box(source))
    return _quantize(_fit(crop, spec.size))


def _animation_master(name: str, spec: Spec) -> tuple[Image.Image, Image.Image]:
    source = Image.open(SOURCE / f"{name}.png").convert("RGBA")
    bounds = [round(index * source.width / 4.0) for index in range(5)]
    raw_frames = [
        _clean_key(source.crop((bounds[index], 0, bounds[index + 1], source.height)))
        for index in range(4)
    ]
    max_width = max(frame.width for frame in raw_frames)
    normalized: list[Image.Image] = []
    for frame in raw_frames:
        canvas = Image.new("RGBA", (max_width, source.height), (0, 0, 0, 0))
        canvas.alpha_composite(frame, ((max_width - frame.width) // 2, 0))
        normalized.append(canvas)
    boxes = [_content_box(frame) for frame in normalized]
    union = (
        min(box[0] for box in boxes),
        min(box[1] for box in boxes),
        max(box[2] for box in boxes),
        max(box[3] for box in boxes),
    )
    fitted = [_fit(frame.crop(union), spec.size) for frame in normalized]
    strip = Image.new("RGBA", (spec.size[0] * 4, spec.size[1]), (0, 0, 0, 0))
    for index, frame in enumerate(fitted):
        strip.alpha_composite(frame, (index * spec.size[0], 0))
    strip = _quantize(strip)
    static = strip.crop((0, 0, spec.size[0], spec.size[1]))
    return static, strip


def _install(name: str, static: Image.Image, strip: Image.Image | None) -> None:
    for destination in (DESKTOP, MOBILE):
        destination.mkdir(parents=True, exist_ok=True)
        static.save(destination / f"{name}.png", optimize=True)
        if strip is not None:
            strip.save(destination / f"{name}_anim.png", optimize=True)


def _qa_contact(outputs: dict[str, tuple[Image.Image, Image.Image | None]]) -> None:
    cell_w, cell_h = 520, 250
    columns = 2
    rows = (len(outputs) + columns - 1) // columns
    sheet = Image.new("RGB", (cell_w * columns, cell_h * rows), (30, 33, 39))
    draw = ImageDraw.Draw(sheet)
    for index, (name, (static, strip)) in enumerate(outputs.items()):
        x = (index % columns) * cell_w
        y = (index // columns) * cell_h
        draw.rounded_rectangle(
            (x + 8, y + 8, x + cell_w - 8, y + cell_h - 8),
            radius=12,
            fill=(45, 49, 57),
            outline=(92, 100, 112),
            width=2,
        )
        draw.text((x + 18, y + 16), name, fill=(238, 240, 243))
        visual = strip if strip is not None else static
        max_w, max_h = cell_w - 34, cell_h - 54
        scale = min(max_w / visual.width, max_h / visual.height)
        shown = visual.resize(
            (max(1, round(visual.width * scale)), max(1, round(visual.height * scale))),
            Image.Resampling.NEAREST,
        )
        checker = Image.new("RGBA", shown.size, (72, 75, 82, 255))
        cdraw = ImageDraw.Draw(checker)
        for cy in range(0, shown.height, 12):
            for cx in range(0, shown.width, 12):
                if (cx // 12 + cy // 12) % 2 == 0:
                    cdraw.rectangle(
                        (cx, cy, cx + 11, cy + 11),
                        fill=(88, 91, 98, 255),
                    )
        checker.alpha_composite(shown)
        sheet.paste(
            checker.convert("RGB"),
            (x + (cell_w - shown.width) // 2, y + 42 + (max_h - shown.height) // 2),
        )
    QA_DIR.mkdir(parents=True, exist_ok=True)
    sheet.save(QA_DIR / "all_tiers.png", quality=92)


def main() -> None:
    outputs: dict[str, tuple[Image.Image, Image.Image | None]] = {}
    for name, spec in SPECS.items():
        if spec.animated:
            static, strip = _animation_master(name, spec)
        else:
            static, strip = _static_master(name, spec), None
        _install(name, static, strip)
        outputs[name] = (static, strip)
        print(
            f"{name}: static={static.size}"
            + (f" strip={strip.size}" if strip is not None else "")
        )
    _qa_contact(outputs)
    print(QA_DIR / "all_tiers.png")


if __name__ == "__main__":
    main()
