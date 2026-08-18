from pathlib import Path

from PIL import Image


ROOT = Path(__file__).parent
for name in ("idle_normalized.png", "walk_normalized.png", "attack_normalized.png"):
    path = ROOT / name
    image = Image.open(path).convert("RGBA")
    width, height = image.size
    assert height >= 256, (name, image.size)
    assert width == height * 4, (name, image.size)
    alpha = image.getchannel("A")
    alpha_values = list(alpha.getdata())
    assert max(alpha_values) > 0, (name, "empty alpha")
    green_bleed = 0
    frame_bounds = []
    for frame in range(4):
        x0 = frame * height
        pixels = image.crop((x0, 0, x0 + height, height))
        rgba = list(pixels.getdata())
        green_bleed += sum(
            1
            for red, green, blue, opacity in rgba
            if opacity > 0 and green > 150 and green > red + 20 and green > blue + 20
        )
        opaque = [
            (x, y)
            for y in range(height)
            for x in range(height)
            if pixels.getpixel((x, y))[3] > 10
        ]
        assert opaque, (name, frame, "empty frame")
        xs = [item[0] for item in opaque]
        ys = [item[1] for item in opaque]
        frame_bounds.append((min(xs), min(ys), max(xs), max(ys)))
        for corner in ((0, 0), (height - 1, 0), (0, height - 1), (height - 1, height - 1)):
            assert pixels.getpixel(corner)[3] == 0, (name, frame, corner, pixels.getpixel(corner))
    assert green_bleed == 0, (name, "green bleed", green_bleed)
    print(name, image.size, "RGBA", "green_bleed=0", "bounds=", frame_bounds)
