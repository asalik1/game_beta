"""Build the unwired eight-direction Warlock V2 walk QA candidate."""

from __future__ import annotations

import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont


ROOT = Path(__file__).resolve().parents[2]
TOOLS = Path(__file__).resolve().parent
sys.path.insert(0, str(TOOLS))

import install_dirset
from build_ledgerbound_warlock import _grid, _normalize_clip


SRC = ROOT / "art_src" / "class_corrective_pass_2026-07-31"
OUT = SRC / "warlock_candidate_runtime"
QA = SRC / "qa"
DIR8 = ("s", "se", "e", "ne", "n", "nw", "w", "sw")
LABEL = {
    "s": "S / front",
    "se": "SE / front-right",
    "e": "E / right profile",
    "ne": "NE / rear-right",
    "n": "N / back",
    "nw": "NW / rear-left",
    "w": "W / left profile",
    "sw": "SW / front-left",
}


def font(size: int) -> ImageFont.ImageFont:
    for path in (
        Path("C:/Windows/Fonts/arialbd.ttf"),
        Path("C:/Windows/Fonts/segoeuib.ttf"),
    ):
        if path.exists():
            return ImageFont.truetype(str(path), size)
    return ImageFont.load_default()


def frames(path: Path) -> list[Image.Image]:
    result = _grid(path, 1, 7, body_x=True)[0]
    if len(result) != 7:
        raise ValueError(f"{path.name}: expected seven frames")
    return result


def strip_frames(path: Path) -> list[Image.Image]:
    strip = Image.open(path).convert("RGBA")
    cell = strip.height
    return [
        strip.crop((index * cell, 0, (index + 1) * cell, cell))
        for index in range(strip.width // cell)
    ]


def build_contact(rows: dict[str, list[Image.Image]], cell: int) -> None:
    QA.mkdir(parents=True, exist_ok=True)
    preview = 160
    left = 190
    top = 42
    contact = Image.new(
        "RGBA",
        (left + preview * 7, top + preview * 8),
        (27, 30, 36, 255),
    )
    draw = ImageDraw.Draw(contact)
    draw.text(
        (10, 8),
        "WARLOCK V2 WALK — OBSERVED FACING; f1/f4 = OPPOSING CONTACTS",
        font=font(18),
        fill=(255, 224, 126, 255),
    )
    for index in range(7):
        draw.text(
            (left + index * preview + 6, 20),
            f"f{index + 1}",
            font=font(14),
            fill=(255, 224, 126, 255),
        )
    for row_index, suffix in enumerate(DIR8):
        y = top + row_index * preview
        draw.rectangle(
            (0, y, left - 1, y + preview - 1),
            fill=(45, 49, 58, 255),
        )
        draw.text(
            (10, y + 64),
            LABEL[suffix],
            font=font(15),
            fill=(235, 238, 243, 255),
        )
        for frame_index, frame in enumerate(rows[suffix]):
            scaled = frame.resize((preview, preview), Image.Resampling.LANCZOS)
            contact.alpha_composite(
                scaled, (left + frame_index * preview, y)
            )
            if frame_index in (0, 3):
                color = (97, 219, 145, 255) if frame_index == 0 else (99, 176, 255, 255)
                draw.rectangle(
                    (
                        left + frame_index * preview + 2,
                        y + 2,
                        left + (frame_index + 1) * preview - 3,
                        y + preview - 3,
                    ),
                    outline=color,
                    width=3,
                )
    contact.save(QA / "warlock_v2_walk_contact.png")

    pages: list[Image.Image] = []
    grid_cell = 190
    for frame_index in range(7):
        page = Image.new("RGBA", (grid_cell * 4, grid_cell * 2), (27, 30, 36, 255))
        for direction_index, suffix in enumerate(DIR8):
            scaled = rows[suffix][frame_index].resize(
                (grid_cell, grid_cell), Image.Resampling.LANCZOS
            )
            page.alpha_composite(
                scaled,
                ((direction_index % 4) * grid_cell, (direction_index // 4) * grid_cell),
            )
        pages.append(page.convert("P", palette=Image.Palette.ADAPTIVE))
    pages[0].save(
        QA / "warlock_v2_walk.gif",
        save_all=True,
        append_images=pages[1:],
        duration=110,
        loop=0,
        disposal=2,
    )


def build() -> None:
    raw = {
        suffix: frames(SRC / f"warlock_walk_{suffix}_v01.png")
        for suffix in DIR8
    }
    normalized = _normalize_clip(raw)
    OUT.mkdir(parents=True, exist_ok=True)
    cell = install_dirset.assemble_clips(
        {"warlock_walk": normalized}, str(OUT), margin=3, symmetric=False
    )
    rows = {
        suffix: strip_frames(OUT / f"warlock_walk_{suffix}.png")
        for suffix in DIR8
    }
    build_contact(rows, cell)
    print(f"unwired Warlock V2 walk candidate: cell={cell}px -> {OUT}")


if __name__ == "__main__":
    build()
