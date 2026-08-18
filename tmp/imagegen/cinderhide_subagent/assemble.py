from pathlib import Path

from PIL import Image


ROOT = Path(__file__).parent
CELL = 627
BOXES = (
    (0, 0, CELL, CELL),
    (CELL, 0, CELL * 2, CELL),
    (0, CELL, CELL, CELL * 2),
    (CELL, CELL, CELL * 2, CELL * 2),
)


for source_name, output_name in (
    ("idle_keyed.png", "idle_strip.png"),
    ("walk_keyed.png", "walk_strip.png"),
    ("attack_keyed.png", "attack_strip.png"),
):
    source = Image.open(ROOT / source_name).convert("RGBA")
    output = Image.new("RGBA", (CELL * 4, CELL), (0, 0, 0, 0))
    for index, box in enumerate(BOXES):
        output.paste(source.crop(box), (index * CELL, 0))
    output.save(ROOT / output_name, "PNG")
