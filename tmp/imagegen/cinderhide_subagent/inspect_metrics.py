from pathlib import Path

from PIL import Image


ROOT = Path("game/assets/sprites")
for name in ("cinderhide_anim.png", "cinderhide_walk.png", "cinderhide_attack.png"):
    image = Image.open(ROOT / name).convert("RGBA")
    cell = image.height
    values = []
    for frame in range(4):
        part = image.crop((frame * cell, 0, (frame + 1) * cell, cell))
        points = [
            (x, y)
            for y in range(cell)
            for x in range(cell)
            if part.getpixel((x, y))[3] > 8
        ]
        xs = [x for x, _ in points]
        ys = [y for _, y in points]
        values.append({
            "frame": frame + 1,
            "bbox": (min(xs), min(ys), max(xs), max(ys)),
            "width": max(xs) - min(xs) + 1,
            "height": max(ys) - min(ys) + 1,
            "feet": max(ys),
        })
    heights = sorted(item["height"] for item in values)
    median = (heights[1] + heights[2]) / 2
    print(name, "median=", median, "frames=", values)
