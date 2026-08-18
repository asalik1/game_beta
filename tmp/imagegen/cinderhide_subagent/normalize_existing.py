from pathlib import Path

from PIL import Image


SPRITES = Path("game/assets/sprites")
OUT = Path("tmp/imagegen/cinderhide_subagent")
CELL = 627
SOLID = 8


def one_metric(image: Image.Image) -> dict:
    width, height = image.size
    points = [
        (x, y)
        for y in range(height)
        for x in range(width)
        if image.getpixel((x, y))[3] > SOLID
    ]
    xs = [x for x, _ in points]
    ys = [y for _, y in points]
    return {
        "bbox": (min(xs), min(ys), max(xs), max(ys)),
        "height": max(ys) - min(ys) + 1,
        "feet": max(ys),
    }


def metrics(image: Image.Image) -> list[dict]:
    result = []
    for frame in range(4):
        part = image.crop((frame * CELL, 0, (frame + 1) * CELL, CELL))
        result.append(one_metric(part))
    return result


def median(values: list[int]) -> float:
    values = sorted(values)
    return (values[1] + values[2]) / 2


idle = Image.open(SPRITES / "cinderhide_anim.png").convert("RGBA")
idle_stats = metrics(idle)
idle_height = median([item["height"] for item in idle_stats])
print(f"idle median={idle_height:.1f}px")

for source_name, output_name in (
    ("cinderhide_walk.png", "walk_normalized_existing.png"),
    ("cinderhide_attack.png", "attack_normalized_existing.png"),
):
    source = Image.open(SPRITES / source_name).convert("RGBA")
    source_stats = metrics(source)
    source_height = median([item["height"] for item in source_stats])
    scale_y = idle_height / source_height
    output = Image.new("RGBA", source.size, (0, 0, 0, 0))

    for frame, stat in enumerate(source_stats):
        part = source.crop((frame * CELL, 0, (frame + 1) * CELL, CELL))
        resized = part.resize((CELL, round(CELL * scale_y)), Image.Resampling.LANCZOS)
        resized_stat = one_metric(resized)

        new_left, _, new_right, _ = resized_stat["bbox"]
        new_center = (new_left + new_right) / 2
        dx = round(CELL / 2 - new_center)
        dy = stat["feet"] - resized_stat["feet"]

        layer = Image.new("RGBA", (CELL, CELL), (0, 0, 0, 0))
        layer.paste(resized, (dx, dy), resized)
        output.paste(layer, (frame * CELL, 0), layer)

    output.save(OUT / output_name, "PNG")
    result_stats = metrics(output)
    result_height = median([item["height"] for item in result_stats])
    print(f"{source_name}: scale_y={scale_y:.4f}, result median={result_height:.1f}px, frames={result_stats}")
