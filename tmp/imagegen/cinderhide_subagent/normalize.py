from pathlib import Path

from PIL import Image


ROOT = Path(__file__).parent
CELL = 627
SCALE = 0.94
INNER = round(CELL * SCALE)
OFFSET = (CELL - INNER) // 2

for source_name, output_name in (
    ("idle_strip.png", "idle_normalized.png"),
    ("walk_strip.png", "walk_normalized.png"),
    ("attack_strip.png", "attack_normalized.png"),
):
    source = Image.open(ROOT / source_name).convert("RGBA")
    output = Image.new("RGBA", source.size, (0, 0, 0, 0))
    for frame in range(4):
        cell = source.crop((frame * CELL, 0, (frame + 1) * CELL, CELL))
        cell = cell.resize((INNER, INNER), Image.Resampling.LANCZOS)
        output.paste(cell, (frame * CELL + OFFSET, OFFSET), cell)
    output.save(ROOT / output_name, "PNG")
