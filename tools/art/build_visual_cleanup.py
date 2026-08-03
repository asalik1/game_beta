"""Build the August 2026 high-resolution visual-cleanup sprites.

ImageGen masters are preserved under art_src.  This deterministic install step
crops their keyed alpha, fits them to the intended runtime canvas, and writes
only the shipped PNG overrides.
"""

from pathlib import Path

from PIL import Image, ImageDraw


ROOT = Path(__file__).resolve().parents[2]
SOURCE_DIR = ROOT / "art_src" / "visual_cleanup_2026-08-02" / "alpha"
SPRITE_DIR = ROOT / "game" / "assets" / "sprites"
QA_OUTPUT = ROOT / "art_src" / "visual_cleanup_2026-08-02" / "qa_visual_cleanup.png"

ASSETS = {
    "crystal_shrine.png": ("crystal.png", 192, 10, 7, 5),
    "sapphire.png": ("rv_mat_gem_blue.png", 128, 9, 7, 5),
    "emerald.png": ("rv_mat_gem_green.png", 128, 9, 7, 5),
    "ruby.png": ("rv_mat_gem_red.png", 128, 9, 7, 5),
    "amber.png": ("rv_mat_gem_amber.png", 128, 9, 7, 5),
    "amethyst.png": ("rv_mat_gem_violet.png", 128, 9, 7, 5),
}


def _fit(source_path: Path, cell_size: int, pad_x: int, pad_top: int, pad_bottom: int) -> Image.Image:
    source = Image.open(source_path).convert("RGBA")
    alpha_box = source.getchannel("A").getbbox()
    if alpha_box is None:
        raise RuntimeError(f"ImageGen master has no visible pixels: {source_path}")

    subject = source.crop(alpha_box)
    available_w = cell_size - pad_x * 2
    available_h = cell_size - pad_top - pad_bottom
    scale = min(available_w / subject.width, available_h / subject.height)
    size = (max(1, round(subject.width * scale)), max(1, round(subject.height * scale)))
    subject = subject.resize(size, Image.Resampling.LANCZOS)

    cell = Image.new("RGBA", (cell_size, cell_size), (0, 0, 0, 0))
    x = (cell_size - subject.width) // 2
    y = cell_size - pad_bottom - subject.height
    cell.alpha_composite(subject, (x, y))
    if cell.getchannel("A").getextrema() != (0, 255):
        raise RuntimeError(f"Built sprite must contain transparent and opaque pixels: {source_path}")
    return cell


def _checker(size: tuple[int, int], block: int = 12) -> Image.Image:
    image = Image.new("RGBA", size, "#292b32")
    draw = ImageDraw.Draw(image)
    for y in range(0, size[1], block):
        for x in range(0, size[0], block):
            if (x // block + y // block) % 2:
                draw.rectangle((x, y, x + block - 1, y + block - 1), fill="#343741")
    return image


def _write_qa(built: dict[str, Image.Image]) -> None:
    labels = [
        ("Crystal shrine", "crystal.png"),
        ("Sapphire", "rv_mat_gem_blue.png"),
        ("Emerald", "rv_mat_gem_green.png"),
        ("Ruby", "rv_mat_gem_red.png"),
        ("Amber", "rv_mat_gem_amber.png"),
        ("Amethyst", "rv_mat_gem_violet.png"),
        ("Moonstone", "rv_mat_gem_moon.png"),
    ]
    panel_w, panel_h = 230, 248
    sheet = Image.new("RGB", (panel_w * 4, panel_h * 2), "#17191f")
    draw = ImageDraw.Draw(sheet)
    for index, (label, filename) in enumerate(labels):
        x = (index % 4) * panel_w
        y = (index // 4) * panel_h
        stage = _checker((panel_w - 20, 205))
        sprite = built.get(filename)
        if sprite is None:
            sprite = Image.open(SPRITE_DIR / filename).convert("RGBA")
        limit = 178 if filename == "crystal.png" else 142
        ratio = min(limit / sprite.width, limit / sprite.height)
        preview = sprite.resize(
            (max(1, round(sprite.width * ratio)), max(1, round(sprite.height * ratio))),
            Image.Resampling.LANCZOS,
        )
        stage.alpha_composite(preview, ((stage.width - preview.width) // 2, (stage.height - preview.height) // 2))
        sheet.paste(stage.convert("RGB"), (x + 10, y + 8))
        draw.text((x + 12, y + 219), label, fill="#ece8dc")
    QA_OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(QA_OUTPUT, optimize=True)


def build() -> None:
    SPRITE_DIR.mkdir(parents=True, exist_ok=True)
    built: dict[str, Image.Image] = {}
    for source_name, (output_name, cell_size, pad_x, pad_top, pad_bottom) in ASSETS.items():
        cell = _fit(SOURCE_DIR / source_name, cell_size, pad_x, pad_top, pad_bottom)
        output = SPRITE_DIR / output_name
        cell.save(output, optimize=True)
        built[output_name] = cell
        print(f"Wrote {output.relative_to(ROOT)} ({cell_size}x{cell_size})")
    _write_qa(built)
    print(f"Wrote {QA_OUTPUT.relative_to(ROOT)}")


if __name__ == "__main__":
    build()
