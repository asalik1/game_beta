"""Build an actual-size and nearest-neighbour class readability comparison."""

from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw, ImageFont
import numpy as np


ROOT = Path(__file__).resolve().parents[2]
SPRITES = ROOT / "game" / "assets" / "sprites"
OUT = (
    ROOT
    / "art_src"
    / "class_corrective_pass_2026-07-31"
    / "quality_runtime_comparison.png"
)

NAMES = ("elder", "paladin", "warrior", "warlock", "warlock_candidate", "mage", "archer", "assassin")
LABELS = {
    "elder": "MAREN",
    "paladin": "PALADIN",
    "warrior": "WARRIOR",
    "warlock": "WARLOCK",
    "warlock_candidate": "WARLOCK V2",
    "mage": "MAGE",
    "archer": "ARCHER",
    "assassin": "ASSASSIN",
}

TARGET_BODY = 88
CELL_W = 132
CELL_H = 132
LABEL_H = 24
BG = (26, 29, 35, 255)
CARD = (34, 38, 46, 255)
RULE = (74, 81, 94, 255)
TEXT = (244, 226, 156, 255)


def first_frame(path: Path) -> Image.Image:
    image = Image.open(path).convert("RGBA")
    cell = image.height
    return image.crop((0, 0, cell, cell))


def normalized(name: str) -> Image.Image:
    if name == "warlock_candidate":
        sheet = Image.open(
            ROOT
            / "art_src"
            / "class_corrective_pass_2026-07-31"
            / "warlock_rotation_quality_v01.png"
        ).convert("RGBA")
        frame = sheet.crop((0, 0, sheet.width // 5, sheet.height))
        data = np.asarray(frame, dtype=np.uint8).copy()
        green = (
            (data[..., 1] > 100)
            & (data[..., 1] > data[..., 0].astype(np.int16) + 28)
            & (data[..., 1] > data[..., 2].astype(np.int16) + 28)
        )
        data[green, 3] = 0
        data[green, :3] = 0
        frame = Image.fromarray(data, "RGBA")
    else:
        frame = first_frame(SPRITES / f"{name}.png")
    box = frame.getbbox()
    if box is None:
        raise ValueError(f"empty sprite: {name}")
    figure = frame.crop(box)
    scale = TARGET_BODY / float(figure.height)
    return figure.resize(
        (max(1, round(figure.width * scale)), TARGET_BODY),
        Image.Resampling.LANCZOS,
    )


def font() -> ImageFont.ImageFont:
    for candidate in (
        Path("C:/Windows/Fonts/arialbd.ttf"),
        Path("C:/Windows/Fonts/segoeuib.ttf"),
    ):
        if candidate.exists():
            return ImageFont.truetype(str(candidate), 13)
    return ImageFont.load_default()


def card(figure: Image.Image, label: str) -> Image.Image:
    image = Image.new("RGBA", (CELL_W, CELL_H + LABEL_H), CARD)
    draw = ImageDraw.Draw(image)
    draw.rectangle((0, 0, CELL_W - 1, CELL_H - 1), outline=RULE)
    image.alpha_composite(
        figure,
        ((CELL_W - figure.width) // 2, CELL_H - figure.height - 9),
    )
    bounds = draw.textbbox((0, 0), label, font=font())
    width = bounds[2] - bounds[0]
    draw.text(((CELL_W - width) // 2, CELL_H + 4), label, font=font(), fill=TEXT)
    return image


def build() -> None:
    OUT.parent.mkdir(parents=True, exist_ok=True)
    cards = [card(normalized(name), LABELS[name]) for name in NAMES]
    gap = 8
    actual_h = CELL_H + LABEL_H
    zoom = 2
    zoom_w = CELL_W * zoom
    zoom_h = actual_h * zoom
    width = gap + len(cards) * (zoom_w + gap)
    title_h = 34
    total_h = title_h + actual_h + gap + zoom_h + gap
    canvas = Image.new("RGBA", (width, total_h), BG)
    draw = ImageDraw.Draw(canvas)
    draw.text((gap, 8), "ACTUAL GAMEPLAY BODY SCALE (~88 px)", font=font(), fill=TEXT)
    actual_row_w = len(cards) * CELL_W + (len(cards) - 1) * gap
    x = (width - actual_row_w) // 2
    for item in cards:
        canvas.alpha_composite(item, (x, title_h))
        x += CELL_W + gap
    x = gap
    for item in cards:
        enlarged = item.resize((zoom_w, zoom_h), Image.Resampling.NEAREST)
        canvas.alpha_composite(enlarged, (x, title_h + actual_h + gap))
        x += zoom_w + gap
    canvas.save(OUT)
    print(OUT)


if __name__ == "__main__":
    build()
