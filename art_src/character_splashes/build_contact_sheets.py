import csv
import math
from pathlib import Path

from PIL import Image, ImageDraw


ROOT = Path(__file__).resolve().parents[2]
HERE = Path(__file__).resolve().parent
SPRITES = ROOT / "game/assets/sprites"
ENTRIES_PER_SHEET = 16
COLS = 4
CELL_W = 300
CELL_H = 250


with (HERE / "manifest.tsv").open(encoding="utf-8", newline="") as handle:
    entries = list(csv.DictReader(handle, delimiter="\t"))

if len(entries) != 81:
    raise RuntimeError(f"Expected 81 manifest entries, found {len(entries)}")

for sheet_index in range(math.ceil(len(entries) / ENTRIES_PER_SHEET)):
    subset = entries[sheet_index * ENTRIES_PER_SHEET : (sheet_index + 1) * ENTRIES_PER_SHEET]
    rows = math.ceil(len(subset) / COLS)
    sheet = Image.new("RGB", (COLS * CELL_W, rows * CELL_H), (27, 30, 36))
    draw = ImageDraw.Draw(sheet)
    for index, entry in enumerate(subset):
        col = index % COLS
        row = index // COLS
        left = col * CELL_W
        top = row * CELL_H
        sprite_path = SPRITES / f"{entry['sprite']}.png"
        image = Image.open(sprite_path).convert("RGBA")
        bbox = image.getchannel("A").getbbox()
        if bbox is None:
            raise RuntimeError(f"Empty source sprite: {sprite_path}")
        subject = image.crop(bbox)
        max_w = CELL_W - 44
        max_h = CELL_H - 70
        scale = min(max_w / subject.width, max_h / subject.height)
        size = (max(1, round(subject.width * scale)), max(1, round(subject.height * scale)))
        subject = subject.resize(size, Image.Resampling.NEAREST)
        x = left + (CELL_W - subject.width) // 2
        y = top + 42 + (max_h - subject.height) // 2
        sheet.paste(subject.convert("RGB"), (x, y), subject.getchannel("A"))
        color = (235, 196, 96) if entry["type"] == "boss" else (205, 220, 235)
        draw.text((left + 10, top + 8), f"{entry['type'].upper()}  {entry['sprite']}", fill=color)
        draw.text((left + 10, top + 25), entry["name"], fill=(235, 235, 235))
        draw.rectangle((left, top, left + CELL_W - 1, top + CELL_H - 1), outline=(65, 70, 82))
    out = HERE / f"source_roster_{sheet_index + 1}.png"
    sheet.save(out)
    print(out)

