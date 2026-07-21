import csv
import math
from pathlib import Path

from PIL import Image, ImageDraw


HERE = Path(__file__).resolve().parent
GENERATED = HERE / "generated"
COLS = 4
CELL = 300
IMAGE_SIZE = 260

with (HERE / "manifest.tsv").open(encoding="utf-8", newline="") as handle:
    manifest = list(csv.DictReader(handle, delimiter="\t"))

entries = [entry for entry in manifest if (GENERATED / f"portrait_{entry['sprite']}.png").exists()]
if not entries:
    raise RuntimeError("No generated portraits found")

for old in HERE.glob("generated_review_*.jpg"):
    old.unlink()

per_sheet = 16
for sheet_index in range(math.ceil(len(entries) / per_sheet)):
    subset = entries[sheet_index * per_sheet : (sheet_index + 1) * per_sheet]
    rows = math.ceil(len(subset) / COLS)
    sheet = Image.new("RGB", (COLS * CELL, rows * (CELL + 35)), (22, 25, 31))
    draw = ImageDraw.Draw(sheet)
    for index, entry in enumerate(subset):
        col, row = index % COLS, index // COLS
        x, y = col * CELL, row * (CELL + 35)
        image = Image.open(GENERATED / f"portrait_{entry['sprite']}.png").convert("RGB")
        side = min(image.width, image.height)
        left = (image.width - side) // 2
        top = (image.height - side) // 2
        image = image.crop((left, top, left + side, top + side)).resize((IMAGE_SIZE, IMAGE_SIZE), Image.Resampling.LANCZOS)
        sheet.paste(image, (x + 20, y + 8))
        color = (235, 190, 85) if entry["type"] == "boss" else (210, 225, 240)
        draw.text((x + 20, y + IMAGE_SIZE + 12), f"{entry['type'].upper()}  {entry['name']}", fill=color)
    out = HERE / f"generated_review_{sheet_index + 1}.jpg"
    sheet.save(out, quality=92)
    print(out)

